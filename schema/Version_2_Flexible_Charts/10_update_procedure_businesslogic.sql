DROP PROCEDURE IF EXISTS Finance.ar_update_transaction;
CREATE OR REPLACE PROCEDURE Finance.ar_update_transaction(
    IN a_clientID INT,
    IN a_ReceivableID INT,
    IN a_TransactionID INT,
    IN a_CustomerID INT,
    IN a_Duedate DATE ,
    IN a_Invoicedate DATE,
    IN a_Amount DECIMAL(12,2),
    IN a_Status VARCHAR(20)
) LANGUAGE plpgsql AS $$
DECLARE
    new_transaction_id  INT;
    s_counter INT := 0;
    s_max INT:= 2;
    v_cash_chart INT;
    v_balance DECIMAL(12,2);
BEGIN
    --LOOP
        BEGIN
                
            IF a_Status NOT IN ('Pending', 'Paid', 'Overdue') OR a_Status =  '' THEN
                RAISE EXCEPTION 'Invalid Status';
            END IF;

            IF a_ReceivableID IS NULL THEN
                RAISE EXCEPTION  'Invalid Receivable ID';
            END IF;

            IF a_Invoicedate IS NULL THEN
                RAISE EXCEPTION 'Invalid  Invoice Date';
            END IF;

            IF a_Duedate IS NULL THEN
                RAISE EXCEPTION 'Invalid  Due Date';
            END IF;

            IF a_Amount < 0 OR a_Amount IS NULL THEN
                RAISE EXCEPTION 'Invalid Amount';
            END IF;
        
            IF a_TransactionID IS NULL THEN
                RAISE EXCEPTION 'Vendor ID cannot be Null';
            END IF;

	    SELECT chart_id INTO v_cash_chart
            FROM Finance.charts
            JOIN Finance.account_roles USING (chart_id)
            WHERE role_name LIKE 'cash_account_ar%'
                  AND client_id = a_clientID
                  AND is_active = TRUE
	    LIMIT 1;
 -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            PERFORM 1
            FROM Finance.customers 
            WHERE customer_id = a_CustomerID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.account_receivables
            WHERE receivable_id = a_ReceivableID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.transactions
            WHERE transaction_id = a_TransactionID
            FOR UPDATE;

            UPDATE Finance.account_receivables
            SET
                customer_id = a_CustomerID
             --   DueDate = a_Duedate,
             --   InvoiceDate = a_Invoicedate,
             --   Amount = a_Amount
            WHERE 
                receivable_id = a_ReceivableID AND transaction_id = a_TransactionID;

            UPDATE Finance.ar_ext
            SET
                due_date = a_DueDate,
                invoice_date = a_Invoicedate,
                amount = a_Amount,
		Status = a_Status
            WHERE
                receivable_id = a_ReceivableID;

            UPDATE Finance.transactions
            SET
                Description = CONCAT('Account Receivable With Amount of ', a_Amount, 'Due Date on ', a_DueDate, 'Status ',  a_Status , 'This had been Updated')
            WHERE transaction_id = a_TransactionID;

            UPDATE Finance.journals
            SET
                date = a_Invoicedate,
                amount = a_Amount
            WHERE transaction_id = a_TransactionID 
	    AND chart_id IN (SELECT chart_id FROM finance.account_roles WHERE role_name IN ('cash_account_ar','ar_account'));

            SELECT SUM(
                CASE WHEN journal THEN amount ELSE -amount END
                ) INTO v_balance
            FROM Finance.journals
            WHERE chart_id = v_cash_chart;
--            FOR UPDATE;

            IF a_Amount < v_balance THEN
                RAISE EXCEPTION 'Insufficient Funds';
            END IF;
                        
           -- EXIT;
        
        EXCEPTION
            -- WHEN serialization_failure OR deadlock_detected THEN
            --     s_counter := s_counter + 1;
            -- IF 
            --     s_counter >= s_max then
            --     RAISE EXCEPTION 'Transaction failed after % try', s_max;
            -- END IF;

            -- PERFORM pg_sleep(0.1);

            WHEN OTHERS THEN
                RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
        END;
    --END LOOP;
END;
$$;

DROP PROCEDURE IF EXISTS Finance.ap_update_transaction;
CREATE OR REPLACE PROCEDURE Finance.ap_update_transaction(
    IN a_clientID INT,
    IN a_PayableID INT,
    IN a_TransactionID INT,
    IN a_SupplierID INT,
    IN a_Duedate DATE ,
    IN a_billdate DATE,
    IN a_Amount DECIMAL(12,2),
    IN a_Status VARCHAR(20)
) LANGUAGE plpgsql AS $$
DECLARE
    new_transaction_id  INT;
    s_counter INT := 0;
    s_max INT:= 2;
    v_cash_chart INT;
    v_balance DECIMAL(12,2);
BEGIN
    --LOOP
        BEGIN
                
            IF a_Status NOT IN ('Pending', 'Paid', 'Overdue') OR a_Status =  '' THEN
                RAISE EXCEPTION 'Invalid Status';
            END IF;

            IF a_PayableID IS NULL THEN
                RAISE EXCEPTION  'Invalid Receivable ID';
            END IF;

            IF a_billdate IS NULL THEN
                RAISE EXCEPTION 'Invalid  Invoice Date';
            END IF;

            IF a_Duedate IS NULL THEN
                RAISE EXCEPTION 'Invalid  Due Date';
            END IF;

            IF a_Amount < 0 OR a_Amount IS NULL THEN
                RAISE EXCEPTION 'Invalid Amount';
            END IF;
        
            IF a_TransactionID IS NULL THEN
                RAISE EXCEPTION 'Vendor ID cannot be Null';
            END IF;

	    SELECT chart_id INTO v_cash_chart
            FROM Finance.charts
            JOIN Finance.account_roles USING (chart_id)
            WHERE role_name LIKE 'cash_account_ar%'
                  AND client_id = a_clientID
                  AND is_active = TRUE
            LIMIT 1;

            -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            PERFORM 1
            FROM Finance.suppliers
            WHERE supplier_id = a_SupplierID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.account_payables
            WHERE payable_id = a_PayableID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.transactions
            WHERE transaction_id = a_TransactionID
            FOR UPDATE;

            UPDATE Finance.account_payables
            SET
                payable_id = a_PayableID
             --   DueDate = a_Duedate,
             --   InvoiceDate = a_Invoicedate,
             --   Amount = a_Amount
            WHERE 
                payable_id = a_PayableID AND transaction_id = a_TransactionID;

            UPDATE Finance.ap_ext
            SET
                due_date = a_DueDate,
                invoice_date = a_billdate,
                amount = a_Amount,
		Status = a_Status
            WHERE
                payable_id = a_PayableID;

            UPDATE Finance.transactions
            SET
                Description = CONCAT('Account Receivable With Amount of ', a_Amount, 'Due Date on ', a_DueDate, 'Status ',  a_Status , 'This had been Updated')
            WHERE transaction_id = a_TransactionID;

            UPDATE Finance.journals
            SET
                date = a_billdate,
                amount = a_Amount
            WHERE transaction_id = a_TransactionID 
	    AND chart_id IN (SELECT chart_id FROM Finance.account_roles a WHERE a.role_name IN ('cash_account_ap', 'ap_account'));

            SELECT SUM(
                CASE WHEN journal THEN amount ELSE -amount END
                ) INTO v_balance
            FROM Finance.journals
            WHERE chart_id = v_cash_chart;
--            FOR UPDATE;

            IF a_Amount < v_balance THEN
                RAISE EXCEPTION 'Insufficient Funds';
            END IF;
                        
            --EXIT;
        
        EXCEPTION
            -- WHEN serialization_failure OR deadlock_detected THEN
            --     s_counter := s_counter + 1;
            -- IF 
            --     s_counter >= s_max then
            --     RAISE EXCEPTION 'Transaction failed after % try', s_max;
            -- END IF;

            -- PERFORM pg_sleep(0.1);

            WHEN OTHERS THEN
                RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
        END;
    --END LOOP;
END;
$$;

DROP PROCEDURE IF EXISTS Finance.inventory_audit_update_transaction;
CREATE OR REPLACE PROCEDURE Finance.inventory_audit_update_Transaction
(
   -- IN a_clientid INT,
    IN a_ManagementID INT,
    IN a_ProductID INT,
    IN a_WarehouseID INT,
    IN a_TransactionID INT,
    IN a_ActionType VARCHAR(50),
    IN a_MovementDate DATE,
    IN a_status VARCHAR(50),
    IN tities INT

)
LANGUAGE plpgsql AS $$
DECLARE 
    -- new_transaction_id INT;    
    s_count INT := 0;
    s_max INT := 3;
BEGIN
 -- Input validation
--    LOOP
        BEGIN

            IF a_ProductID IS NULL OR a_WarehouseID IS NULL OR a_TransactionID IS NULL THEN
                RAISE EXCEPTION 'Invalid product or warehouse ID';
            END IF;
            
            IF a_ProductID <= 0 OR a_WarehouseID <= 0 THEN
                RAISE EXCEPTION 'Invalid product or warehouse ID';
            END IF;

            IF tities <= 0 THEN
                RAISE EXCEPTION 'Quantity must be positive';
            END IF;

            -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            PERFORM 1
            FROM Finance.products
            WHERE product_id = a_ProductID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.warehouses
            WHERE warehouse_id = a_WarehouseID
            FOR UPDATE;

            -- Insert into Transactions and capture ID
            UPDATE Finance.inventory_audits
            SET 
                product_id= a_ProductID,
                warehouse_id= a_WarehouseID,
                movement_date= a_MovementDate,
		        quantity= tities

            WHERE
                management_id = a_ManagementID AND transaction_id = a_TransactionID;

            UPDATE Finance.transactions
            SET
                Description = CONCAT(a_ActionType, ' of ProductID: ', a_ProductID, ' in WarehouseID: ', a_WarehouseID, ' quantity of:', tities, 'This had been Updated')
            WHERE Transaction_id = a_TransactionID;

            IF a_ActionType = 'Purchase' THEN
                -- Update Accounts Payable
                UPDATE Finance.ap_ext
                SET amount = tities * (SELECT Product_cost FROM Finance.products a WHERE a.Product_id = a_ProductID),
                    due_date = a_MovementDate + INTERVAL '30 days',
                    invoice_date = a_MovementDate,
                    status = a_status
                WHERE payable_id = (SELECT payable_id FROM Finance.account_payables WHERE Transaction_id = a_TransactionID);

                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET 
                    amount = tities * (SELECT Product_cost FROM Finance.products b WHERE b.Product_id = a_ProductID)
                WHERE transaction_id = a_TransactionID 
		AND chart_id IN (SELECT chart_id FROM Finance.account_roles a WHERE a.role_name IN ('inventory_account', 'ap_account'));

            ELSIF a_ActionType = 'Sale' THEN
                    -- Update Accounts Receivable
                UPDATE Finance.ar_ext
                SET amount = tities * (SELECT Product_price FROM Finance.products a WHERE a.Product_id = a_ProductID),
                    due_date = a_MovementDate + INTERVAL '30 days',
                    invoice_date = a_MovementDate,
                    status = a_status
                WHERE receivable_id = (SELECT receivable_id FROM Finance.account_receivables WHERE transaction_id = a_TransactionID);

                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET Amount = tities * (SELECT Product_price FROM Finance.products z WHERE z.Product_id = a_ProductID)
                WHERE transaction_id = a_TransactionID 
		AND chart_id IN (SELECT Chart_id FROM Finance.account_roles a WHERE a.role_name IN ('ar_account', 'revenue_account'));

                UPDATE Finance.journals
                SET amount = tities * (SELECT Product_cost FROM Finance.products c WHERE c.Product_id = a_ProductID)
                WHERE transaction_id = a_TransactionID 
		AND chart_id IN (SELECT Chart_id FROM Finance.charts b WHERE b.Account IN ('Cost of Goods Sold', 'Inventory'));
        
            ELSIF a_ActionType = 'Sale Return' THEN
                UPDATE Finance.sale_returns
                SET 
                    return_amount = tities * (SELECT product_price FROM Finance.products b WHERE b.product_id = a_ProductID),
                    return_date = a_MovementDate
                WHERE receivable_id = (SELECT receivable_id FROM Finance.account_receivables a WHERE a.transaction_id = a_TransactionID);

                -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET
                    Amount = tities * (SELECT Product_price FROM Finance.products x WHERE x.Product_id = a_ProductID)
                WHERE Transaction_id = a_TransactionID 
		AND Chart_id IN (SELECT Chart_id FROM Finance.account_roles a WHERE a.role_name IN ('SR&Allowances', 'ar_account'));--SELECT ChartID FROM Finance.charts z WHERE z.Account IN ('Sales Returns and Allowances', 'Accounts Receivable')); 
                    
                UPDATE Finance.journals
                SET Amount = tities * (SELECT Product_cost FROM Finance.products t WHERE t.Product_id = a_ProductID)
                WHERE Transaction_id = a_TransactionID 
		AND Chart_id IN (SELECT Chart_id FROM Finance.account_roles a WHERE a.role_name IN ('inventory_account', 'COGS'));--SELECT ChartID FROM Finance.charts u WHERE u.Account IN ('Inventory', 'Cost of Goods Sold'));

            ELSIF a_ActionType = 'Purchase Return' THEN
                UPDATE Finance.purchase__returns
                SET Return_amount = tities * (SELECT Product_price FROM Finance.products b WHERE b.Product_id = a_ProductID),
                    Return_date = a_MovementDate
                WHERE Payable_id = (SELECT Payable_id FROM Finance.account_payables a WHERE a.Transaction_id = a_TransactionID);

                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET 
                    Amount = tities * (SELECT Product_price FROM Finance.products v WHERE v.Product_id = a_ProductID)
                WHERE Transaction_id = a_TransactionID 
		AND Chart_id IN (SELECT Chart_id FROM Finance.account_roles a WHERE a.role_name IN ('ap_account', 'PR&Allowances','inventory_account'));--SELECT ChartID FROM Finance.charts w WHERE w.Account IN ('Accounts Payable', 'Purchase Returns and Allowances'));
	      --  UPDATE Finance.journals
              --  SET 
              --      Amount = tity * (SELECT Productcost FROM Finance.products t WHERE t.ProductID = a_ProductID)
              --  WHERE TransactionID = a_TransactionID 
	      -- AND ChartID IN (SELECT ChartID FROM Finance.accountroles a WHERE a.rolename IN ('inventory_account', 'COGS'));--SELECT ChartID FROM Finance.charts u WHERE u.Account IN ('Inventory', 'Cost of Goods Sold'));

            ELSIF a_ActionType = 'Transfer' THEN
                    -- Update Journal entry for inventory movement
                --UPDATE Finance.journals
                --SET 
                    --Amount = tity * (SELECT Productcost FROM Finance.products b WHERE b.ProductID = a_ProductID)
                --WHERE TransactionID = a_TransactionID 
		--AND ChartID IN (SELECT ChartID FROM Finance.charts a WHERE a.Account = 'Inventory'); 

                UPDATE Finance.journals
                SET 
                  Amount = tities * (SELECT Product_cost FROM Finance.products d WHERE d.Product_id = a_ProductID)
                WHERE Transaction_id = a_TransactionID 
		AND Chart_id IN (SELECT Chart_id FROM Finance.account_roles a WHERE a.role_name IN ('inventory_account','inventory_account'));--SELECT ChartID FROM Finance.charts c WHERE c.Account = 'Inventory'); 
                
		ELSE
                    RAISE EXCEPTION 'Unsupported action type';
                END IF;

            -- EXIT;

            EXCEPTION 
                -- WHEN serialization_failure OR deadlock_detected THEN
                --     s_count := s_count + 1;

                --     IF s_count >= s_max THEN
                --         RAISE EXCEPTION 'Transaction Failed attempted % ', s_count;
                --     END IF;
                --     PERFORM pg_sleep(0.1);

                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

        END;
  --  END LOOP;            
END;
$$;