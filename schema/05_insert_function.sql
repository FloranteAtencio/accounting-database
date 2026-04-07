--------- Reusable procedure -------
CREATE OR REPLACE PROCEDURE Finance.insert_journal
(
    IN p_transaction_id INT,
    IN p_account VARCHAR,
    IN p_is_debit BOOLEAN,
    IN p_amount DECIMAL,
    IN p_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_chart_id INT;
BEGIN

    SELECT ChartID INTO v_chart_id
    FROM Finance.charts
    WHERE Account = p_account;

    INSERT INTO Finance.journals
    (TransactionID, ChartID, Date, Journal, Amount)
    VALUES
    (p_transaction_id, v_chart_id, p_date, p_is_debit, p_amount);
 
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

END;
$$;


CREATE OR REPLACE PROCEDURE Finance.inventory_module
(
    IN p_product_id INT,
    IN p_warehouse_id INT,
    IN p_transaction_id INT,
    IN p_action_type VARCHAR(50),
    IN p_quantity INT,
    IN p_date DATE
)
LANGUAGE plpgsql
AS $$
BEGIN

    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity';
    END IF;

    INSERT INTO Finance.inventoryaudits
    (ProductID, WarehouseID, TransactionID, ActionType, Quantity, MovementDate)
    VALUES
    (p_product_id, p_warehouse_id, p_transaction_id, p_action_type, p_quantity, p_date);
 

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

END;
$$;

CREATE OR REPLACE PROCEDURE Finance.accounting_module
(
    IN p_transaction_id INT,
    IN p_product_id INT,
    IN p_action_type VARCHAR(50),
    IN p_quantity INT,
    IN p_date DATE,
    IN p_reference_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cost DECIMAL;
    v_price DECIMAL;
BEGIN


    SELECT Productcost, Productprice
    INTO v_cost, v_price
    FROM Finance.products
    WHERE ProductID = p_product_id;

    IF LOWER(p_action_type) = 'purchase' THEN

        -- Accounts Payable
        INSERT INTO Finance.accountpayables
        (SupplierID, TransactionID, Amount, DueDate, BillDate, Status)
        VALUES
        (p_reference_id, p_transaction_id, p_quantity * v_cost, p_date + INTERVAL '30 days', p_date, 'Pending');

        -- Journal
        CALL Finance.insert_journal(p_transaction_id, 'Inventory', TRUE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal(p_transaction_id, 'Accounts Payable', FALSE, p_quantity * v_cost, p_date);

    ELSIF LOWER(p_action_type) = 'sale' THEN

        -- Accounts Receivable
        INSERT INTO Finance.accountreceivables
        (CustomerID, TransactionID, Amount, DueDate, InvoiceDate, Status)
        VALUES
        (p_reference_id, p_transaction_id, p_quantity * v_price, p_date + INTERVAL '30 days', p_date, 'Pending');

        -- Journal
        CALL Finance.insert_journal(p_transaction_id, 'Accounts Receivable', TRUE, p_quantity * v_price, p_date);
        CALL Finance.insert_journal(p_transaction_id, 'Revenue', FALSE, p_quantity * v_price, p_date);

    ELSE
        RAISE EXCEPTION 'Unsupported action type';
    END IF;
  

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
END;
$$;


CREATE OR REPLACE PROCEDURE Finance.return_module
(
    IN p_transaction_id INT,
    IN p_product_id INT,
    IN p_action_type VARCHAR(50),
    IN p_quantity INT,
    IN p_date DATE,
    IN p_reference_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cost DECIMAL;
    v_price DECIMAL;
BEGIN

    SELECT Productcost, Productprice
    INTO v_cost, v_price
    FROM Finance.products
    WHERE ProductID = p_product_id;

    IF LOWER(p_action_type) = 'sale return' THEN
            -- Journal entry for inventory movement
            INSERT INTO Finance.salereturns(ReceivableID,  ReturnAmount, InvoiceDate, ReturnDate)
            VALUES (p_reference_id, p_quantity * v_price ,(SELECT InvoiceDate from Finance.accountreceivables where ReceivableID = p_reference_id) , p_date);
            
        Update Finance.accountreceivables
        SET
        Status = 'Returned'
        WHERE 
           ReceivableID = p_reference_id;
        CALL Finance.insert_journal(p_transaction_id, 'Sales Returns and Allowances', TRUE, p_quantity * v_price, p_date);
        CALL Finance.insert_journal(p_transaction_id, 'Accounts Receivable', FALSE, p_quantity * v_price, p_date);
        CALL Finance.insert_journal(p_transaction_id, 'Inventory', TRUE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal(p_transaction_id, 'Cost of Goods Sold', FALSE, p_quantity * v_cost, p_date);

    ELSIF p_action_type = 'Purchase Return' THEN
        -- Journal entry for inventory movement
        INSERT INTO Finance.purchasereturns(PayableID,  ReturnAmount, BillDate, ReturnDate)
        VALUES (p_reference_id, p_quantity * v_price, (SELECT BillDate from Finance.accountpayables where PayableID = p_reference_id), p_date);
            
        Update Finance.accountpayables
        SET
        Status = 'Returned'
        WHERE 
        PayableID = p_reference_id;
            
        CALL Finance.insert_journal(p_transaction_id, 'Accounts Payable', TRUE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal(p_transaction_id, 'Inventory', FALSE, p_quantity * v_cost, p_date);
            
    ELSE
        RAISE EXCEPTION 'Unsupported action type';
    END IF;
    
  

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

END;
$$;

CREATE OR REPLACE PROCEDURE Finance.transfer_module
(
    IN p_transaction_id INT,
    IN p_product_id INT,
    IN p_action_type VARCHAR(50),
    IN p_quantity INT,
    IN p_date DATE,
    IN p_reference_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cost DECIMAL;
    v_price DECIMAL;
BEGIN

    SELECT Productcost, Productprice
    INTO v_cost, v_price
    FROM Finance.products
    WHERE ProductID = p_product_id;

    IF p_action_type = 'Transfer' THEN
        CALL Finance.insert_journal(p_transaction_id, 'Inventory', TRUE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal(p_transaction_id, 'Inventory', FALSE, p_quantity * v_cost, p_date);
        
        ELSE
            RAISE EXCEPTION 'Invalid Action Type';
        END IF;
  

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

END;
$$;


CREATE OR REPLACE PROCEDURE Finance.ap_Transaction(
    IN p_SupplierID INT,
    IN p_DueDate DATE ,
    IN p_BillDate DATE,
    IN p_Amount DECIMAL(12,2),
    IN p_Status VARCHAR(20),
    --IN p_idempotency_key VARCHAR
) LANGUAGE plpgsql AS $$
DECLARE
    new_transaction_id  INT;
    s_count INT:=0;
    s_max INT:=3;
    v_cash_chart INT;
    v_balance DECIMAL(12,2);
BEGIN
    LOOP
        BEGIN

            IF p_Status NOT IN ('Pending', 'Paid', 'Overdue') OR p_Status =  '' THEN
                RAISE EXCEPTION 'Invalid Status';
            END IF;

            IF p_SupplierID IS NULL THEN
                RAISE EXCEPTION  'Invalid Supplier ID';
            END IF;

            IF p_DueDate IS NULL THEN
                RAISE EXCEPTION 'Invalid  Due Date';
            END IF;

            IF p_Amount < 0 OR p_Amount IS NULL THEN
                RAISE EXCEPTION 'Invalid Amount';
            END IF;

            SELECT ChartID INTO v_cash_chart
            FROM Finance.charts
            WHERE Account = 'Cash/Bank';

            SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;
            
            PERFORM 1
            FROM Finance.suppliers
            WHERE SupplierID = p_SupplierID
            FOR UPDATE;
            
            SELECT SUM(
                CASE WHEN Journal THEN Amount ELSE -Amount END
            ) INTO v_balance
            FROM Finance.journals
            WHERE ChartID = v_cash_chart
            FOR UPDATE;    
        
            IF p_Amount < v_balance THEN
                RAISE EXCEPTION 'Insufficient Funds';
            END IF;

            INSERT INTO Finance.transactions (Description, idempotencyKey)
            VALUES (CONCAT('Account Payable With Amount of ', p_Amount, 'Due Date on ',p_DueDate, 'Status ',  p_Status ))
            RETURNING TransactionID INTO new_transaction_id;
            ON CONFLICT(idempotencyKey) DO NOTHING

            IF new_transaction_id IS NULL THEN
                SELECT TransactionID INTO new_transaction_id
                FROM Finance.transactions
                WHERE idempotencyKey = p_idempotency_key;
                
                RETURN;
            END IF;
            
            INSERT INTO Finance.accountpayables (SupplierID, TransactionID, Amount, DueDate,BillDate,Status)
            VALUES (p_SupplierID,new_transaction_id,p_Amount,p_DueDate,p_BillDate,'Paid');
            
            CALL Finance.insert_journal(new_transaction_id, 'Cash/Bank', FALSE, Amount, BillDate);
            CALL Finance.insert_journal(new_transaction_id, 'Accounts Payable', TRUE, p_Amount, p_BillDate);
        EXIT;

        EXCEPTION
            WHEN serialization_failure or deadlock_detected THEN
                s_count := s_count + 1;
                IF s_count >= s_max then
                    RAISE EXCEPTION 'Transaction failed after % attempts', s_count;
                END IF;

                PERFORM pg_sleep(0.1);
    
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
        END;
    END LOOP; 
END;
$$;

CREATE OR REPLACE PROCEDURE Finance.ar_transaction(
    IN p_CustomersID INT,
    IN p_DueDate DATE ,
    IN p_InvoiceDate DATE,
    IN p_Amount DECIMAL(12,2),
    IN p_Status VARCHAR(20),
    --IN p_idempotency_key VARCHAR
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
        
        IF p_Status NOT IN ('Pending', 'Paid', 'Overdue') OR p_Status =  '' THEN
            RAISE EXCEPTION 'Invalid Status';
        END IF;

       
        IF p_InvoiceDate IS NULL THEN
            RAISE EXCEPTION 'Invalid  Due Date';
        END IF;


        IF p_DueDate IS NULL THEN
            RAISE EXCEPTION 'Invalid  Due Date';
        END IF;

        IF p_Amount < 0 OR p_Amount IS NULL THEN
            RAISE EXCEPTION 'Invalid Amount';
        END IF;

        SELECT ChartID INTO v_cash_chart
        FROM Finance.charts
        WHERE Account = 'Cash/Bank';
        
        SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        
        PERFORM 1
        FROM Finance.customers 
        WHERE CustomerID = p_CustomerID
        FOR UPDATE;

        SELECT SUM(
                CASE WHEN Journal THEN Amount ELSE -Amount END
            ) INTO v_balance
        FROM Finance.journals
        WHERE ChartID = v_cash_chart
        FOR UPDATE;

            IF p_Amount < v_balance THEN
                RAISE EXCEPTION 'Insufficient Funds';
            END IF;

        INSERT INTO Finance.transactions (Description, idempotencyKey)
        VALUES (CONCAT('Account Receivable With Amount of ', p_Amount, 'Due Date on ',p_DueDate, 'Status ',  p_Status ))
        RETURNING TransactionID INTO new_transaction_id;
        ON CONFLICT(idempotencyKey) DO NOTHING


        IF new_transaction_id IS NULL THEN
            SELECT TransactionID INTO new_transaction_id
            FROM Finance.transactions
            WHERE idempotencyKey = p_idempotency_key;
            
            RETURN;
        END IF;

        INSERT INTO Finance.accountreceivables (CustomersID, TransactionID, Amount, DueDate,InvoiceDate,Status)
        VALUES (p_CustomersID,new_transaction_id,p_Amount,p_DueDate,p_InvoiceDate,'Paid');
        CALL Finance.insert_journal(new_transaction_id, 'Cash/Bank', FALSE, Amount, InvoiceDate);
        CALL Finance.insert_journal(new_transaction_id, 'Accounts Receivable', TRUE, p_Amount, p_InvoiceDate);

        EXIT;

    EXCEPTION
        WHEN serialization_failure OR deadlock_detected THEN
            s_counter := s_counter + 1;
        IF 
            s_counter >= s_max then
                RAISE EXCEPTION 'Transaction failed after % try', s_max;
        END IF;

        PERFORM pg_sleep(0.1);

        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
        END;
    END LOOP;
END;
$$;


CREATE OR REPLACE PROCEDURE Finance.process_inventory_transaction
(
    IN p_product_id INT,
    IN p_warehouse_id INT,
    IN p_action_type VARCHAR(50),
    IN p_quantity INT,
    IN p_date DATE,
    IN p_reference_id INT,
    IN p_idempotency_key VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_transaction_id INT;
    v_retry_count INT := 0;
    v_max_retries INT := 3;
    v_product_name VARCHAR(255);
BEGIN
    -- 🔁 Retry loop for serialization / deadlocks
    LOOP
        BEGIN

            IF p_quantity <= 0 OR p_quantity IS NULL THEN
                RAISE EXCEPTION 'Quantity must be greater than 0';
            END IF;
            
            SELECT ProductName INTO v_product_name
            FROM Finance.products
            WHERE ProductID = p_product_id;

            -- 🧠 Isolation level (strong consistency)
            SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            -- 🔒 Lock product FIRST (consistent order = deadlock prevention)
            PERFORM 1
            FROM Finance.products
            WHERE ProductID = p_product_id
            FOR UPDATE;

            -- 🔒 Lock warehouse SECOND
            PERFORM 1
            FROM Finance.warehouses
            WHERE WarehouseID = p_warehouse_id
            FOR UPDATE;

            INSERT INTO Finance.transactions (Description, idempotencyKey)
            VALUES (CONCAT('Inventory Transaction With Action Type of ', p_action_type , ' Date on ',p_Date, ' Product name ', v_product_name)
                    ,p_idempotency_key)
            ON CONFLICT(idempotencyKey) DO NOTHING
            RETURNING TransactionID INTO new_transaction_id;

            IF new_transaction_id IS NULL THEN
                SELECT TransactionID INTO new_transaction_id
                FROM Finance.transactions
                WHERE idempotencyKey = p_idempotency_key;
                
                RETURN;
            END IF;
            -- 📦 Inventory
            CALL Finance.inventory_module(
                p_product_id,
                p_warehouse_id,
                new_transaction_id,
                p_action_type,
                p_quantity,
                p_date
            );

            -- 💰 Accounting / Returns / Transfer
            IF p_action_type IN ('Sale', 'Purchase') THEN
                CALL Finance.accounting_module(
                    new_transaction_id, p_product_id, p_action_type,
                    p_quantity, p_date, p_reference_id
                );

            ELSIF p_action_type IN ('Sale Return','Purchase Return') THEN
                CALL Finance.return_module(
                    new_transaction_id, p_product_id, p_action_type,
                    p_quantity, p_date, p_reference_id
                );

            ELSIF p_action_type = 'Transfer' THEN
                CALL Finance.transfer_module(
                    new_transaction_id, p_product_id, p_action_type,
                    p_quantity, p_date, p_reference_id
                );
            ELSE
                RAISE EXCEPTION 'Unsupported action type';
            END IF;

            -- ✅ SUCCESS → exit retry loop
            EXIT;

        EXCEPTION
            WHEN serialization_failure OR deadlock_detected THEN
                v_retry_count := v_retry_count + 1;

                IF v_retry_count >= v_max_retries THEN
                    RAISE EXCEPTION 'Transaction failed after % retries', v_retry_count;
                END IF;

                -- ⏳ Small delay before retry (helps contention)
                PERFORM pg_sleep(0.1);

            WHEN OTHERS THEN
                -- ❌ Real error → stop immediately
                RAISE;
        END;
    END LOOP;
END;
$$;


-------- 4️⃣       Business logics          ------------
---------  Insert Stored Procedure       ----------


-- ----- Simplle CRUD can be ignore -------
-- CREATE OR REPLACE PROCEDURE Finance.products_transaction
-- (
--     IN Productname VARCHAR(100),
--     IN Description VARCHAR(200),
--     IN Productunit VARCHAR(20),
--     IN Productcost DECIMAL(12,2),
--     IN Productprice DECIMAL (12,2)
-- ) LANGUAGE plpgsql AS $$
-- BEGIN

--     IF Productcost < 0 THEN
--         RAISE EXCEPTION 'Product cost cannot be negative';
--     END IF;
    
--     IF Productprice < 0 THEN
--         RAISE  EXCEPTION 'Product price cannot be negative';
--     END IF;

--     INSERT INTO Products (ProductName, Description, ProductUnit, ProductCost, ProductPrice)
--     VALUES (Productname, Description, Productunit, Productcost, Productprice);


--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

-- END;
-- $$;
-- ----- Simplle CRUD can be ignore -------
-- CREATE OR REPLACE PROCEDURE Finance.warehouse_transaction(
--     IN WarehouseName VARCHAR(100),
--     IN Location VARCHAR(100)
-- ) LANGUAGE plpgsql AS $$
-- BEGIN

--     -- Validation checks
--     IF WarehouseName IS NULL OR WarehouseName = '' THEN
--         RAISE EXCEPTION 'Warehouse name cannot be empty';
--     END IF;

--     IF Location IS NULL OR Location = '' THEN
--         RAISE EXCEPTION 'Location cannot be empty';
--     END IF;

--     INSERT INTO Warehouses (WarehouseName, Location)
--     VALUES (WarehouseName, Location);

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

-- END;
-- $$;
-- ----- Simplle CRUD can be ignore -------
-- CREATE OR REPLACE PROCEDURE Finance.charts_transaction(
--     IN Account VARCHAR(30),
--     IN Type VARCHAR(30)
-- ) LANGUAGE plpgsql AS $$
-- BEGIN

--     -- Validation checks
--     IF Account IS NULL or Account = '' THEN
--         RAISE EXCEPTION 'Account name cannot be empty';
--     END IF;

--     IF Type NOT IN ('Asset', 'Liability', 'Equity', 'Revenue', 'Expense') THEN
--         RAISE EXCEPTION 'Invalid account type';
--     END IF;

--     INSERT INTO Charts (Account, Type)
--     VALUES (Account, Type);
 

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

-- END;
-- $$;
-- ----- Simplle CRUD can be ignore -------
-- CREATE OR REPLACE PROCEDURE Finance.customer_transaction(
--     IN CustomerName VARCHAR(100),
--     IN ContactInfo VARCHAR(15),
--     IN Email VARCHAR(50),
--     IN Address VARCHAR(100)
-- )
-- LANGUAGE plpgsql AS $$
-- BEGIN

--     -- Validation checks
--     IF CustomerName IS NULL OR CustomerName = '' THEN 
--         RAISE EXCEPTION 'Customer name cannot be empty';
--     END IF;

--     IF ContactInfo IS NULL OR ContactInfo = '' THEN
--         RAISE EXCEPTION 'Contact information cannot be empty';
--     END IF;

--     IF Email IS NULL OR Email = '' OR NOT Email LIKE '%@%' THEN
--         RAISE EXCEPTION 'Invalid email address';
--     END IF;

--     IF Address IS NULL OR Address = '' THEN 
--         RAISE EXCEPTION 'Address cannot be empty';
--     END IF;

--     INSERT INTO Customers (CustomerName, ContactInfo, Email, Address)
--     VALUES (CustomerName, ContactInfo, Email, Address);
  

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

-- END;
-- $$;
-- ----- Simplle CRUD can be ignore -------
-- CREATE OR REPLACE PROCEDURE Finance.supplier_transaction(
--     IN SupplierName VARCHAR(100),
--     IN ContactInfo VARCHAR(15),
--     IN Email VARCHAR(50),
--     IN Address VARCHAR(100)
-- )

-- LANGUAGE plpgsql AS $$
-- BEGIN

--     -- Validation checks
--     IF SupplierName IS NULL OR VendorName = '' THEN 
--         RAISE EXCEPTION 'Vendor name cannot be empty';
--     END IF;

--     IF ContactInfo IS NULL OR ContactInfo = '' THEN
--         RAISE EXCEPTION 'Contact information cannot be empty';
--     END IF;

--     IF Email IS NULL OR Email = '' OR NOT Email LIKE '%@%' THEN
--         RAISE EXCEPTION 'Invalid email address';
--     END IF;

--     IF Address IS NULL OR Address = '' THEN 
--         RAISE EXCEPTION 'Address cannot be empty';
--     END IF;

--     INSERT INTO Suppliers (SupplierName, ContactInfo, Email, Address)
--     VALUES (SupplierName, ContactInfo, Email, Address);
  

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

-- END;
-- $$;
