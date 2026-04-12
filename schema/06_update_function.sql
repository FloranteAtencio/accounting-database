CREATE OR REPLACE PROCEDURE Finance.ar_update_transaction(
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
    LOOP
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

            SELECT ChartID INTO v_cash_chart 
            FROM Finance.charts 
            WHERE Account = 'Cash/Bank' 
            LIMIT 1;

            -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            PERFORM 1
            FROM Finance.customers 
            WHERE CustomerID = a_CustomerID
            FOR UPDATE;

--            PERFORM 1
  --          FROM Finance.accountreceivables
    --        WHERE ReceivableID = a_ReceivableID
      --      FOR UPDATE;

            PERFORM 1
            FROM Finance.transactions
            WHERE TransactionID = a_TransactionID
            FOR UPDATE;

            UPDATE Finance.accountreceivables
            SET
                CustomerID = a_CustomerID,
                DueDate = a_Duedate,
                InvoiceDate = a_Invoicedate,
                Amount = a_Amount
            WHERE 
                ReceivableID = a_ReceivableID AND TransactionID = a_TransactionID;

            UPDATE Finance.transactions
            SET
                Description = CONCAT('Account Receivable With Amount of ', a_Amount, 'Due Date on ', a_DueDate, 'Status ',  a_Status , 'This had been Updated')
            WHERE TransactionID = a_TransactionID;

            UPDATE Finance.journals
            SET
                Date = a_Invoicedate,
                Amount = a_Amount
            WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts a WHERE a.Account IN ('Cash/Bank', 'Accounts Receivable'));

            
            SELECT SUM(
                CASE WHEN Journal THEN Amount ELSE -Amount END
                ) INTO v_balance
            FROM Finance.journals
            WHERE ChartID = v_cash_chart;
--            FOR UPDATE;

            IF a_Amount < v_balance THEN
                RAISE EXCEPTION 'Insufficient Funds';
            END IF;
                        
            EXIT;
        
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
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE Finance.ap_update_transaction(
    IN a_PayableID INT,
    IN a_TransactionID INT,
    IN a_SupplierID INT,
    IN a_DueDate DATE ,
    IN a_BillDate DATE,
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
    LOOP
        BEGIN
            IF a_Status NOT IN ('Pending', 'Paid', 'Overdue') OR a_Status =  '' THEN
                RAISE EXCEPTION 'Invalid Status';
            END IF;

            IF a_SupplierID IS NULL THEN
                RAISE EXCEPTION  'Invalid Supplier ID';
            END IF;

            IF a_BillDate IS NULL THEN
                RAISE EXCEPTION 'Invalid  Due Date';
            END IF;

            IF a_DueDate IS NULL THEN
                RAISE EXCEPTION 'Invalid  Due Date';
            END IF;

            IF a_Amount < 0 OR a_Amount IS NULL THEN
                RAISE EXCEPTION 'Invalid Amount';
            END IF;

            IF a_TransactionID IS NULL THEN
                RAISE EXCEPTION 'Vendor ID cannot be Null';
            END IF;

            IF a_PayableID IS NULL THEN
                RAISE EXCEPTION 'Vendor ID cannot be Null';
            END IF;

            SELECT ChartID INTO v_cash_chart 
            FROM Finance.charts 
            WHERE Account = 'Cash/Bank' 
            LIMIT 1;

            -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            PERFORM 1
            FROM Finance.accountpayables
            WHERE PayableID = a_PayableID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.transactions
            WHERE TransactionID = a_TransactionID
            FOR UPDATE;
            
            PERFORM 1
            FROM Finance.suppliers
            WHERE SupplierID = a_SupplierID
            FOR UPDATE;
        
            
            UPDATE Finance.accountpayables
            SET
                SupplierID = a_SupplierID,
                DueDate = a_DueDate,
                BillDate = a_BillDate,
                Amount = a_Amount
            WHERE PayableID = a_PayableID AND TransactionID = a_TransactionID;

            UPDATE Finance.transactions
            SET
                Description = CONCAT('Account Receivable With Amount of ', Amount, 'Due Date on ',DueDate, 'Status ',  a_Status , 'This had been Updated')
            WHERE TransactionID = a_TransactionID;

            UPDATE Finance.journals
            SET
                Date = a_BillDate,
                Amount = a_Amount
            WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts a WHERE a.Account IN ('Cash/Bank', 'Accounts Payable'));

            SELECT SUM(
                CASE WHEN Journal THEN Amount ELSE -Amount END
                ) INTO v_balance
            FROM Finance.journals
            WHERE ChartID = v_cash_chart;
            --FOR UPDATE;

            IF a_Amount < v_balance THEN
                RAISE EXCEPTION 'Insufficient Funds';
            END IF;

            EXIT;

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
    END LOOP;    
END;
$$;

CREATE OR REPLACE PROCEDURE Finance.inventory_audit_update_Transaction
(
    IN a_ManagementID INT,
    IN a_ProductID INT,
    IN a_WarehouseID INT,
    IN a_TransactionID INT,
    IN a_ActionType VARCHAR(50),
    IN a_Quantity INT,
    IN a_MovementDate DATE
)
LANGUAGE plpgsql AS $$
DECLARE 
    -- new_transaction_id INT;    
    s_count INT := 0;
    s_max INT := 3;
BEGIN
 -- Input validation
    LOOP
        BEGIN

            IF a_ProductID IS NULL OR a_WarehouseID IS NULL OR a_TransactionID IS NULL THEN
                RAISE EXCEPTION 'Invalid product or warehouse ID';
            END IF;
            
            IF a_ProductID <= 0 OR a_WarehouseID <= 0 THEN
                RAISE EXCEPTION 'Invalid product or warehouse ID';
            END IF;

            IF a_Quantity <= 0 THEN
                RAISE EXCEPTION 'Quantity must be positive';
            END IF;



            -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            PERFORM 1
            FROM Finance.products
            WHERE ProductID = a_ProductID
            FOR UPDATE;

            PERFORM 1
            FROM Finance.warehouses
            WHERE WarehouseID = a_WarehouseID
            FOR UPDATE;


            -- Insert into Transactions and capture ID
            UPDATE Finance.inventoryaudits
            SET 
                ProductID = a_ProductID,
                WarehouseID = a_WarehouseID,
                Quantity = a_Quantity,
                MovementDate = a_MovementDate
            WHERE
                ManagementID = a_ManagementID AND TransactionID = a_TransactionID;

            UPDATE Finance.transactions
            SET
                Description = CONCAT(a_ActionType, ' of ProductID: ', a_ProductID, ' in WarehouseID: ', a_WarehouseID, ' quantity of:', a_Quantity, 'This had been Updated')
            WHERE TransactionID = a_TransactionID;

            IF a_ActionType = 'Purchase' THEN
                -- Update Accounts Payable
                UPDATE Finance.accountpayables
                SET Amount = a_Quantity * (SELECT Productcost FROM Finance.products a WHERE a.ProductID = ProductID),
                    DueDate = a_MovementDate + INTERVAL '30 days',
                    BillDate = a_MovementDate,
                    Status = 'Pending'
                WHERE TransactionID = a_TransactionID;

                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET 
                    Amount = a_Quantity * (SELECT Productcost FROM Finance.products b WHERE b.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts a WHERE a.Account IN ('Inventory', 'Accounts Payable'));

            ELSIF a_ActionType = 'Sale' THEN
                    -- Update Accounts Receivable
                UPDATE Finance.accountreceivables
                SET Amount = a_Quantity * (SELECT Productprice FROM Finance.products a WHERE a.ProductID = ProductID),
                    DueDate = a_MovementDate + INTERVAL '30 days',
                    InvoiceDate = a_MovementDate,
                    Status = 'Pending'
                WHERE TransactionID = a_TransactionID;

                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET Amount = a_Quantity * (SELECT Productprice FROM Finance.products z WHERE z.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts a WHERE a.Account IN ('Account Receivable', 'Revenue'));

                UPDATE Finance.journals
                SET Amount = Quantity * (SELECT Productcost FROM Finance.products c WHERE c.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts b WHERE b.Account IN ('Cost of Goods Sold', 'Inventory'));
        
            ELSIF a_ActionType = 'Sales Return' THEN
                UPDATE Finance.salereturns
                SET 
                    ReturnAmount = a_Quantity * (SELECT Productprice FROM Finance.products b WHERE b.ProductID = a_ProductID),
                    ReturnDate = a_MovementDate
                WHERE ReceivableID = (SELECT ReceivableID FROM Finance.accountreceivables a WHERE a.TransactionID = a_TransactionID);

                -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET
                    Amount = a_Quantity * (SELECT Productprice FROM Finance.products x WHERE x.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts z WHERE z.Account IN ('Sales Returns and Allowances', 'Accounts Receivable')); 
                    
                UPDATE Finance.journals
                SET Amount = a_Quantity * (SELECT Productcost FROM Finance.products t WHERE t.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts u WHERE u.Account IN ('Inventory', 'Cost of Goods Sold'));

            ELSIF a_ActionType = 'Purchase Return' THEN
                UPDATE Finance.purchasereturns
                SET ReturnAmount = a_Quantity * (SELECT Productprice FROM Finance.products b WHERE b.ProductID = a_ProductID),
                    ReturnDate = a_MovementDate
                WHERE PayableID = (SELECT PayableID FROM Finance.accountpayables a WHERE a.TransactionID = a_TransactionID);

                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET 
                    Amount = a_Quantity * (SELECT Productprice FROM Finance.products v WHERE v.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts w WHERE w.Account IN ('Accounts Payable', 'Purchase Returns and Allowances'));
            
                UPDATE Finance.journals
                SET 
                    Amount = a_Quantity * (SELECT Productcost FROM Finance.products t WHERE t.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts u WHERE u.Account IN ('Inventory', 'Cost of Goods Sold'));

            ELSIF a_ActionType = 'Transfer' THEN
                    -- Update Journal entry for inventory movement
                UPDATE Finance.journals
                SET 
                    Amount = a_Quantity * (SELECT Productcost FROM Finance.products b WHERE b.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts a WHERE a.Account = 'Inventory'); 

                UPDATE Finance.journals
                SET 
                    Amount = a_Quantity * (SELECT Productcost FROM Finance.products d WHERE d.ProductID = a_ProductID)
                WHERE TransactionID = a_TransactionID AND ChartID IN (SELECT ChartID FROM Finance.charts c WHERE c.Account = 'Inventory');
        
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
    END LOOP;            
END;
$$;



-- -------------------- 5️⃣ Update Stored Procedure ----------------
-- ----- Simplle CRUD can be ignore -------
-- CREATE OR REPLACE PROCEDURE Finance.product_update_transaction
-- (
--     IN a_ProductID INT,
--     IN a_ProductName VARCHAR(100),
--     IN a_Description VARCHAR(200),
--     IN a_Productunit VARCHAR(20),
--     IN a_Productcost DECIMAL(12,2),
--     IN a_Productprice DECIMAL (12,2)
-- ) LANGUAGE plpgsql AS $$
-- BEGIN


--     IF a_Productcost < 0 THEN
--         RAISE EXCEPTION 'Product cost cannot be negative';
--     END IF;
    
--     IF a_Productprice < 0 THEN
--         RAISE  EXCEPTION 'Product price cannot be negative';
--     END IF;

--     IF a_ProductID IS NULL THEN
--         RAISE EXCEPTION 'Product ID cannot be Null';
--     END IF;    

--     IF a_ProductName IS NULL THEN
--         RAISE EXCEPTION 'Product Name cannot be Null';
--     END IF;

--     IF a_Description IS NULL THEN
--         RAISE EXCEPTION 'Description cannot be Null';
--     END IF;

    

--     UPDATE Finance.products
--         SET 
--         ProductName = a_ProductName, 
--         Description = a_Description, 
--         ProductUnit = a_ProductUnit,
--         ProductCost = a_Productcost,
--         ProductPrice = a_Productprice
--     WHERE
--         ProductID = a_ProductID;
  

    
-- END;
-- $$;

-- ----- Simplle CRUD can be ignore -------
-- CREATE OR REPLACE PROCEDURE Finance.warehouse_update_transaction(
--     IN a_WarehouseID INT,
--     IN a_WarehouseName VARCHAR(100),
--     IN a_Location VARCHAR(100)
-- ) LANGUAGE plpgsql AS $$
-- BEGIN
--     -- Validation checks
--     IF a_WarehouseName IS NULL OR a_WarehouseName = '' THEN
--         RAISE EXCEPTION 'Warehouse name cannot be empty';
--     END IF;

--     IF a_Location IS NULL OR a_Location = '' THEN
--         RAISE EXCEPTION 'Location cannot be empty';
--     END IF;

--     UPDATE Finance.warehouses
--     SET 
--         WarehouseName = a_WarehouseName,
--         Location = a_Location
--     WHERE
--         WarehouseID = a_WarehouseID;

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Transaction failed: %', SQLERRM;


    
-- END;
-- $$;

-- ----- Simplle CRUD can be ignore -------

-- CREATE OR REPLACE PROCEDURE Finance.charts_update_transaction(
--     IN a_ChartID INT,
--     IN a_Account VARCHAR(30),
--     IN a_Type VARCHAR(30)
-- ) LANGUAGE plpgsql AS $$
-- BEGIN
--     -- Validation checks
--     IF a_Account IS NULL or a_Account = '' THEN
--         RAISE EXCEPTION 'Account name cannot be empty';
--     END IF;

--     IF a_Type NOT IN ('Asset', 'Liability', 'Equity', 'Revenue', 'Expense') THEN
--         RAISE EXCEPTION 'Invalid account type';
--     END IF;

--     UPDATE Finance.charts
--     SET     
--         Account = a_Account,
--         Type = a_Type
--     WHERE
--         ChartID = a_ChartID;


--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

    
-- END;
-- $$;

-- ----- Simplle CRUD can be ignore -------

-- CREATE OR REPLACE PROCEDURE Finance.customer_update_transaction(
--     IN a_CustomerID INT,
--     IN a_CustomerName VARCHAR(100),
--     IN a_ContactInfo VARCHAR(15),
--     IN a_Email VARCHAR(50),
--     IN a_Address VARCHAR(100)
-- )
-- LANGUAGE plpgsql AS $$
-- BEGIN
--     -- Validation checks
--     IF a_CustomerName IS NULL OR a_CustomerName = '' THEN 
--         RAISE EXCEPTION 'Customer name cannot be empty';
--     END IF;

--     IF a_ContactInfo IS NULL OR a_ContactInfo = '' THEN
--         RAISE EXCEPTION 'Contact information cannot be empty';
--     END IF;

--     IF a_Email IS NULL OR a_Email = '' OR NOT a_Email LIKE '%@%' THEN
--         RAISE EXCEPTION 'Invalid email address';
--     END IF;

--     IF a_Address IS NULL OR a_Address = '' THEN 
--         RAISE EXCEPTION 'Address cannot be empty';
--     END IF;

--     IF a_CustomerID IS NULL THEN
--         RAISE EXCEPTION 'Customer ID cannot be NULL';
--     END IF;

--     UPDATE Finance.customers
--     SET CustomerName = a_CustomerName,
--         ContactInfo = a_ContactInfo,
--         Email = a_Email,
--         Address = a_Address
--     WHERE CustomerID = a_CustomerID;
    
--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

-- END;
-- $$;

-- ----- Simplle CRUD can be ignore -------

-- CREATE OR REPLACE PROCEDURE Finance.Vendor_update_transaction(
--     IN a_VendorID INT,
--     IN a_VendorName VARCHAR(100),
--     IN a_ContactInfo VARCHAR(15),
--     IN a_Email VARCHAR(50),
--     IN a_Address VARCHAR(100)
-- )

-- LANGUAGE plpgsql AS $$
-- BEGIN
--     -- Validation checks
--     IF a_VendorName IS NULL OR a_VendorName = '' THEN 
--         RAISE EXCEPTION 'Vendor name cannot be empty';
--     END IF;

--     IF a_ContactInfo IS NULL OR a_ContactInfo = '' THEN
--         RAISE EXCEPTION 'Contact information cannot be empty';
--     END IF;

--     IF a_Email IS NULL OR a_Email = '' OR NOT a_Email LIKE '%@%' THEN
--         RAISE EXCEPTION 'Invalid email address';
--     END IF;

--     IF a_Address IS NULL OR a_Address = '' THEN 
--         RAISE EXCEPTION 'Address cannot be empty';
--     END IF;

--     IF a_VendorID IS NULL THEN
--         RAISE EXCEPTION 'Vendor ID cannot be Null';
--     END IF;

--     UPDATE Finance.VendorsTransaction
--     SET
--         VendorName = a_VendorName,
--         ContactInfo = a_ContactInfo,
--         Email = a_Email,
--         Address = a_Address
--     WHERE
--         VendorID = a_VendorID;

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

    
-- END;
-- $$;


