DROP PROCEDURE Finance.ar_update_transaction;
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

	    SELECT chartId INTO v_cash_chart
            FROM Finance.charts
            JOIN Finance.accountRoles USING (chartId)
            WHERE roleName LIKE 'cash_account_ar%'
                  AND clientId = a_clientID
                  AND is_active = TRUE
	    LIMIT 1;
 -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            PERFORM 1
            FROM Finance.customers 
            WHERE customerId = a_CustomerID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.accountreceivables
            WHERE receivableId = a_ReceivableID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.transactions
            WHERE transactionId = a_TransactionID
            FOR UPDATE;

            UPDATE Finance.accountreceivables
            SET
                customerId = a_CustomerID
             --   DueDate = a_Duedate,
             --   InvoiceDate = a_Invoicedate,
             --   Amount = a_Amount
            WHERE 
                receivableId = a_ReceivableID AND transactionId = a_TransactionID;

            UPDATE Finance.ar_ext
            SET
                dueDate = a_DueDate,
                invoiceDate = a_Invoicedate,
                amount = a_Amount,
		Status = a_Status
            WHERE
                receivableId = a_ReceivableID;

            UPDATE Finance.transactions
            SET
                Description = CONCAT('Account Receivable With Amount of ', a_Amount, 'Due Date on ', a_DueDate, 'Status ',  a_Status , 'This had been Updated')
            WHERE transactionId = a_TransactionID;

            UPDATE Finance.journals
            SET
                date = a_Invoicedate,
                amount = a_Amount
            WHERE transactionId = a_TransactionID 
	    AND chartId IN (SELECT chartId FROM finance.accountroles WHERE roleName IN ('cash_account_ar','ar_account'));

            SELECT SUM(
                CASE WHEN journal THEN amount ELSE -amount END
                ) INTO v_balance
            FROM Finance.journals
            WHERE chartId = v_cash_chart;
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

DROP PROCEDURE Finance.ap_update_transaction;
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

	    SELECT ChartID INTO v_cash_chart
            FROM Finance.charts
            JOIN Finance.accountRoles USING (chartId)
            WHERE roleName LIKE 'cash_account_ar%'
                  AND clientId = a_clientID
                  AND is_active = TRUE
            LIMIT 1;

            -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            PERFORM 1
            FROM Finance.suppliers
            WHERE supplierId = a_SupplierID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.accountpayables
            WHERE payableId = a_PayableID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.transactions
            WHERE transactionId = a_TransactionID
            FOR UPDATE;

            UPDATE Finance.accountpayables
            SET
                payableId = a_PayableID
             --   DueDate = a_Duedate,
             --   InvoiceDate = a_Invoicedate,
             --   Amount = a_Amount
            WHERE 
                payableId = a_PayableID AND transactionId = a_TransactionID;

            UPDATE Finance.ap_ext
            SET
                dueDate = a_DueDate,
                invoicedate = a_billdate,
                amount = a_Amount,
		Status = a_Status
            WHERE
                payableID = a_PayableID;

            UPDATE Finance.transactions
            SET
                Description = CONCAT('Account Receivable With Amount of ', a_Amount, 'Due Date on ', a_DueDate, 'Status ',  a_Status , 'This had been Updated')
            WHERE transactionId = a_TransactionID;

            UPDATE Finance.journals
            SET
                date = a_billdate,
                amount = a_Amount
            WHERE transactionId = a_TransactionID 
	    AND chartId IN (SELECT chartId FROM Finance.accountroles a WHERE a.roleName IN ('cash_account_ap', 'ap_account'));

            SELECT SUM(
                CASE WHEN journal THEN amount ELSE -amount END
                ) INTO v_balance
            FROM Finance.journals
            WHERE chartId = v_cash_chart;
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

DROP PROCEDURE Finance.inventory_audit_update_transaction;
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
            WHERE productId = a_ProductID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.warehouses
            WHERE warehouseId = a_WarehouseID
            FOR UPDATE;

            -- Insert into Transactions and capture ID
            UPDATE Finance.inventoryaudits
            SET 
                productID= a_ProductID,
                warehouseID= a_WarehouseID,
                movementDate= a_MovementDate,
		        quantity= tities

            WHERE
                managementId = a_ManagementID AND transactionId = a_TransactionID;

            UPDATE Finance.transactions
            SET
                Description = CONCAT(a_ActionType, ' of ProductID: ', a_ProductID, ' in WarehouseID: ', a_WarehouseID, ' quantity of:', tities, 'This had been Updated')
            WHERE TransactionID = a_TransactionID;

            IF a_ActionType = 'Purchase' THEN
                -- Update Accounts Payable
                UPDATE Finance.ap_ext
                SET amount = tities * (SELECT Productcost FROM Finance.products a WHERE a.ProductID = a_ProductID),
                    dueDate = a_MovementDate + INTERVAL '30 days',
                    invoicedate = a_MovementDate,
                    status = a_status
                WHERE payableId = (SELECT PayableID FROM Finance.accountpayables WHERE TransactionID = a_TransactionID);

                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET 
                    amount = tities * (SELECT Productcost FROM Finance.products b WHERE b.ProductID = a_ProductID)
                WHERE transactionId = a_TransactionID 
		AND chartId IN (SELECT chartId FROM Finance.accountroles a WHERE a.roleName IN ('inventory_account', 'ap_account'));

            ELSIF a_ActionType = 'Sale' THEN
                    -- Update Accounts Receivable
                UPDATE Finance.ar_ext
                SET amount = tities * (SELECT Productprice FROM Finance.products a WHERE a.ProductID = a_ProductID),
                    dueDate = a_MovementDate + INTERVAL '30 days',
                    invoiceDate = a_MovementDate,
                    status = a_status
                WHERE receivableId = (SELECT receivableId FROM Finance.accountreceivables WHERE transactionId = a_TransactionID);

                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET Amount = tities * (SELECT Productprice FROM Finance.products z WHERE z.ProductID = a_ProductID)
                WHERE transactionId = a_TransactionID 
		AND chartId IN (SELECT ChartID FROM Finance.accountroles a WHERE a.rolename IN ('ar_account', 'revenue_account'));--SELECT ChartID FROM Finance.charts a WHERE a.Account IN ('Account Receivable', 'Revenue'));

                UPDATE Finance.journals
                SET amount = tities * (SELECT Productcost FROM Finance.products c WHERE c.ProductID = a_ProductID)
                WHERE transactionId = a_TransactionID 
		AND chartId IN (SELECT ChartID FROM Finance.charts b WHERE b.Account IN ('Cost of Goods Sold', 'Inventory'));
        
            ELSIF a_ActionType = 'Sale Return' THEN
                UPDATE Finance.salereturns
                SET 
                    ReturnAmount = tities * (SELECT Productprice FROM Finance.products b WHERE b.ProductID = a_ProductID),
                    ReturnDate = a_MovementDate
                WHERE ReceivableID = (SELECT ReceivableID FROM Finance.accountreceivables a WHERE a.TransactionID = a_TransactionID);

                -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET
                    Amount = tities * (SELECT Productprice FROM Finance.products x WHERE x.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID 
		AND ChartID IN (SELECT ChartID FROM Finance.accountroles a WHERE a.rolename IN ('SR&Allowances', 'ar_account'));--SELECT ChartID FROM Finance.charts z WHERE z.Account IN ('Sales Returns and Allowances', 'Accounts Receivable')); 
                    
                UPDATE Finance.journals
                SET Amount = tities * (SELECT Productcost FROM Finance.products t WHERE t.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID 
		AND ChartID IN (SELECT ChartID FROM Finance.accountroles a WHERE a.rolename IN ('inventory_account', 'COGS'));--SELECT ChartID FROM Finance.charts u WHERE u.Account IN ('Inventory', 'Cost of Goods Sold'));

            ELSIF a_ActionType = 'Purchase Return' THEN
                UPDATE Finance.purchasereturns
                SET ReturnAmount = tities * (SELECT Productprice FROM Finance.products b WHERE b.ProductID = a_ProductID),
                    ReturnDate = a_MovementDate
                WHERE PayableID = (SELECT PayableID FROM Finance.accountpayables a WHERE a.TransactionID = a_TransactionID);

                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET 
                    Amount = tities * (SELECT Productprice FROM Finance.products v WHERE v.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID 
		AND ChartID IN (SELECT ChartID FROM Finance.accountroles a WHERE a.rolename IN ('ap_account', 'PR&Allowances','inventory_account'));--SELECT ChartID FROM Finance.charts w WHERE w.Account IN ('Accounts Payable', 'Purchase Returns and Allowances'));
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
                  Amount = tities * (SELECT Productcost FROM Finance.products d WHERE d.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID 
		AND ChartID IN (SELECT ChartID FROM Finance.accountroles a WHERE a.rolename IN ('inventory_account','inventory_account'));--SELECT ChartID FROM Finance.charts c WHERE c.Account = 'Inventory'); 
                
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