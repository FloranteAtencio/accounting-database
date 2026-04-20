-- ============================================
-- PROCEDURE: Insert Journal Entry
-- ============================================
CREATE OR REPLACE PROCEDURE Finance.insert_journal(
    IN p_clientId INT,
    IN p_transaction_id INT,
    IN p_account_role VARCHAR,
    IN p_is_debit BOOLEAN,
    IN p_amount DECIMAL,
    IN p_date DATE
)
LANGUAGE plpgsql AS $$
DECLARE
    v_chart_id INT;
BEGIN
    -- Find account by role (can be multiple matches, takes first)
    SELECT c.chartId INTO v_chart_id
    FROM Finance.charts c
    INNER JOIN Finance.accountroles ar ON c.chartId = ar.chartId
    WHERE c.clientId = p_clientId 
      AND ar.roleName = p_account_role
      AND c.is_active = TRUE
    LIMIT 1;

    IF v_chart_id IS NULL THEN
        RAISE EXCEPTION 'Account role % not found for client %', p_account_role, p_clientId;
    END IF;

    INSERT INTO Finance.journals (transactionId, chartId, date, journal, amount)
    VALUES (p_transaction_id, v_chart_id, p_date, p_is_debit, p_amount);

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Journal entry failed: %', SQLERRM;
END;
$$;

-- ============================================
-- PROCEDURE: AR Transaction
-- ============================================
CREATE OR REPLACE PROCEDURE Finance.ar_transaction(
    IN p_clientId INT,
    IN p_CustomersID INT,
    IN p_DueDate DATE,
    IN p_InvoiceDate DATE,
    IN p_Amount DECIMAL(12,2),
    IN p_Status VARCHAR(20),
    IN p_idempotency_key VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    new_transaction_id INT;
    new_returning_id INT;
    v_cash_chart INT;
    v_ar_chart INT;
    v_balance DECIMAL(12,2);
    v_retry_count INT := 0;
    v_max_retries INT := 3;
BEGIN
    LOOP
        BEGIN
        
            --SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            -- Find AR cash account (client-specific)
            SELECT c.chartId INTO v_cash_chart
            FROM Finance.charts c
            INNER JOIN Finance.accountroles ar ON c.chartId = ar.chartId
            WHERE c.clientId = p_clientId 
            AND ar.roleName = 'cash_account_ar'
            AND c.is_active = TRUE
            LIMIT 1;

            -- Find AR account
            SELECT c.chartId INTO v_ar_chart
            FROM Finance.charts c
            INNER JOIN Finance.accountroles ar ON c.chartId = ar.chartId
            WHERE c.clientId = p_clientId 
            AND ar.roleName = 'ar_account'
            AND c.is_active = TRUE
            LIMIT 1;

            IF v_cash_chart IS NULL OR v_ar_chart IS NULL THEN
                RAISE EXCEPTION 'Required accounts (cash_account_ar/ar_account) not found for client %', p_clientId;
            END IF;

            PERFORM 1
            FROM Finance.clients
            WHERE clientId = p_clientId
            FOR UPDATE;

            PERFORM 1
            FROM Finance.customers
            WHERE customerId = p_CustomersID
            FOR UPDATE;

            -- Balance check
            SELECT SUM(
                CASE WHEN journal THEN amount ELSE -amount END
            ) INTO v_balance
            FROM Finance.journals
            WHERE chartId = v_cash_chart;

            IF p_Amount < COALESCE(v_balance, 0) THEN
                RAISE EXCEPTION 'Insufficient Funds. Available: %, Required: %', COALESCE(v_balance, 0), p_Amount;
            END IF;

            -- Insert transaction
            INSERT INTO Finance.transactions (description, idempotencyKey, clientId)
            VALUES (
                CONCAT('Account Receivable With Amount of ', p_Amount, 
                    ' Due Date on ', p_DueDate, 
                    ' Status ', p_Status),
                p_idempotency_key, p_clientId
            )
            ON CONFLICT (idempotencyKey) DO NOTHING
            RETURNING TransactionID INTO new_transaction_id;

            IF new_transaction_id IS NULL THEN
                SELECT transactionId INTO new_transaction_id
                FROM Finance.transactions
                WHERE idempotencyKey = p_idempotency_key;
                RETURN;
            END IF;

            -- Insert AR record
            INSERT INTO Finance.accountreceivables (customerId, transactionId)
            VALUES (p_CustomersID, new_transaction_id)
            RETURNING receivableId INTO new_returning_id;

            -- Insert AR extension
            INSERT INTO Finance.ar_ext (amount, dueDate, invoiceDate, status, receivableId)
            VALUES (p_Amount, p_DueDate, p_InvoiceDate, p_Status, new_returning_id);

            -- Journal entries
            CALL Finance.insert_journal(p_clientId, new_transaction_id, 'cash_account_ar', FALSE, p_Amount, p_InvoiceDate);
            CALL Finance.insert_journal(p_clientId, new_transaction_id, 'ar_account', TRUE, p_Amount, p_InvoiceDate);

            EXIT;
            
            EXCEPTION
                    WHEN serialization_failure OR deadlock_detected THEN
                        v_retry_count := v_retry_count + 1;

                        IF v_retry_count >= v_max_retries THEN
                            RAISE EXCEPTION 'Transaction failed after % retries', v_retry_count;
                        END IF;

                      --  ⏳ Small delay before retry (helps contention)
                        PERFORM pg_sleep(0.1);

                    WHEN OTHERS THEN
                        -- ❌ Real error → stop immediately
                        RAISE EXCEPTION 'Inventory Procuess Module Transaction failed %', SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ============================================
-- PROCEDURE: AP Transaction
-- ============================================
CREATE OR REPLACE PROCEDURE Finance.ap_transaction(
    IN p_clientId INT,
    IN p_VendorID INT,
    IN p_DueDate DATE,
    IN p_InvoiceDate DATE,
    IN p_Amount DECIMAL(12,2),
    IN p_Status VARCHAR(20),
    IN p_idempotency_key VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    new_transaction_id INT;
    new_returning_id INT;
    v_cash_chart INT;
    v_ap_chart INT;
    --new_transaction_id INT;
    v_retry_count INT := 0;
    v_max_retries INT := 3;
    --v_product_name VARCHAR(255);
BEGIN
    LOOP
        BEGIN
            
            --SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            -- Find AP cash account (client-specific)
            SELECT c.chartId INTO v_cash_chart
            FROM Finance.charts c
            INNER JOIN Finance.accountroles ar ON c.chartId = ar.chartId
            WHERE c.clientId = p_clientId 
            AND ar.rolename = 'cash_account_ap'
            AND c.is_active = TRUE
            LIMIT 1;

            -- Find AP account
            SELECT c.chartId INTO v_ap_chart
            FROM Finance.charts c
            INNER JOIN Finance.accountroles ar ON c.chartId = ar.chartId
            WHERE c.clientId = p_clientId 
            AND ar.roleName = 'ap_account'
            AND c.is_active = TRUE
            LIMIT 1;

            IF v_cash_chart IS NULL OR v_ap_chart IS NULL THEN
                RAISE EXCEPTION 'Required accounts (cash_account_ap/ap_account) not found for client %', p_clientId;
            END IF;

            PERFORM 1
            FROM Finance.clients
            WHERE clientId = p_clientId
            FOR UPDATE;

            PERFORM 1
            FROM Finance.suppliers
            WHERE supplierID = p_VendorID
            FOR UPDATE;

            -- Insert transaction
            INSERT INTO Finance.transactions (description, idempotencyKey, clientId)
            VALUES (
                CONCAT('Account Payable With Amount of ', p_Amount, 
                    ' Due Date on ', p_DueDate, 
                    ' Status ', p_Status),
                p_idempotency_key, p_clientId
            )
            ON CONFLICT (idempotencyKey) DO NOTHING
            RETURNING TransactionID INTO new_transaction_id;

            IF new_transaction_id IS NULL THEN
                SELECT transactionId INTO new_transaction_id
                FROM Finance.transactions
                WHERE idempotencyKey = p_idempotency_key;
                RETURN;
            END IF;

            -- Insert AP record
            INSERT INTO Finance.accountpayables (supplierId, transactionId)
            VALUES (p_VendorID, new_transaction_id)
            RETURNING PayableID INTO new_returning_id;

            -- Insert AP extension
            INSERT INTO Finance.ap_ext (amount, dueDate, invoiceDate, status, payableId)
            VALUES (p_Amount, p_DueDate, p_InvoiceDate, p_Status, new_returning_id);

            -- Journal entries
            CALL Finance.insert_journal(p_clientId, new_transaction_id, 'cash_account_ap', TRUE, p_Amount, p_InvoiceDate);
            CALL Finance.insert_journal(p_clientId, new_transaction_id, 'ap_account', FALSE, p_Amount, p_InvoiceDate);

            EXIT;
        
            EXCEPTION
                WHEN serialization_failure OR deadlock_detected THEN
                    v_retry_count := v_retry_count + 1;

                    IF v_retry_count >= v_max_retries THEN
                        RAISE EXCEPTION 'Transaction failed after % retries', v_retry_count;
                    END IF;

                 --   ⏳ Small delay before retry (helps contention)
                    PERFORM pg_sleep(0.1);

                WHEN OTHERS THEN
                    -- ❌ Real error → stop immediately
                    RAISE EXCEPTION 'Inventory Procuess Module Transaction failed %', SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ============================================
-- PROCEDURE: Expense Transaction
-- ============================================
CREATE OR REPLACE PROCEDURE Finance.expense_transaction(
    IN p_clientId INT,
    IN p_Amount DECIMAL(12,2),
    IN p_ExpenseDate DATE,
    IN p_Description VARCHAR(255),
    IN p_idempotency_key VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    new_transaction_id INT;
    v_cash_chart INT;
    v_expense_chart INT;
BEGIN
    BEGIN
        -- Find cash account
        SELECT c.chartId INTO v_cash_chart
        FROM Finance.charts c
        INNER JOIN Finance.accountroles ar ON c.chartId = ar.chartId
        WHERE c.clientId = p_clientId 
          AND ar.roleName = 'cash_account_ar'
          AND c.is_active = TRUE
        LIMIT 1;

        -- Find expense account
        SELECT c.chartId INTO v_expense_chart
        FROM Finance.charts c
        INNER JOIN Finance.accountroles ar ON c.chartId = ar.chartId
        WHERE c.clientId = p_clientId 
          AND ar.roleName = 'expense_account'
          AND c.is_active = TRUE
        LIMIT 1;

        IF v_cash_chart IS NULL OR v_expense_chart IS NULL THEN
            RAISE EXCEPTION 'Required accounts (cash/expense) not found for client %', p_clientId;
        END IF;

        PERFORM 1  
        FROM Finance.clients
        WHERE clientId = p_clientId
        FOR UPDATE;

        -- Insert transaction
        INSERT INTO Finance.transactions (description, idempotencyKey, clientId)
        VALUES (p_Description, p_idempotency_key,p_clientId)
        ON CONFLICT (idempotencyKey) DO NOTHING
        RETURNING TransactionID INTO new_transaction_id;

        IF new_transaction_id IS NULL THEN
            SELECT transactionId INTO new_transaction_id
            FROM Finance.transactions
            WHERE idempotencyKey = p_idempotency_key;
            RETURN;
        END IF;

        -- Journal entries
        CALL Finance.insert_journal(p_clientId, new_transaction_id, 'cash_account_ar', TRUE, p_Amount, p_ExpenseDate);
        CALL Finance.insert_journal(p_clientId, new_transaction_id, 'expense_account', FALSE, p_Amount, p_ExpenseDate);

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Expense Transaction failed: %', SQLERRM;
    END;
END;
$$;

-- ============================================
-- PROCEDURE: Revenue Transaction
-- ============================================
CREATE OR REPLACE PROCEDURE Finance.revenue_transaction(
    IN p_clientId INT,
    IN p_Amount DECIMAL(12,2),
    IN p_RevenueDate DATE,
    IN p_Description VARCHAR(255),
    IN p_idempotency_key VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    new_transaction_id INT;
    v_cash_chart INT;
    v_revenue_chart INT;
BEGIN
    BEGIN
        -- Find cash account
        SELECT c.chartId INTO v_cash_chart
        FROM Finance.charts c
        INNER JOIN Finance.accountroles ar ON c.chartId = ar.chartId
        WHERE c.clientId = p_clientId 
          AND ar.roleName = 'cash_account_ar'
          AND c.is_active = TRUE
        LIMIT 1;

        -- Find revenue account
        SELECT c.chartId INTO v_revenue_chart
        FROM Finance.charts c
        INNER JOIN Finance.accountroles ar ON c.chartId = ar.chartId
        WHERE c.clientId = p_clientId 
          AND ar.roleName = 'revenue_account'
          AND c.is_active = TRUE
        LIMIT 1;

        IF v_cash_chart IS NULL OR v_revenue_chart IS NULL THEN
            RAISE EXCEPTION 'Required accounts (cash/revenue) not found for client %', p_clientId;
        END IF;

        PERFORM 1
        FROM Finance.clients
        WHERE clientId = p_clientId
        FOR UPDATE;

        -- Insert transaction
        INSERT INTO Finance.transactions (description, idempotencyKey, clientId)
        VALUES (p_Description, p_idempotency_key, p_clientId)
        ON CONFLICT (idempotencyKey) DO NOTHING
        RETURNING TransactionID INTO new_transaction_id;

        IF new_transaction_id IS NULL THEN
            SELECT TransactionID INTO new_transaction_id
            FROM Finance.transactions
            WHERE idempotencyKey = p_idempotency_key;
            RETURN;
        END IF;

        -- Journal entries
        CALL Finance.insert_journal(p_clientId, new_transaction_id, 'cash_account_ar', FALSE, p_Amount, p_RevenueDate);
        CALL Finance.insert_journal(p_clientId, new_transaction_id, 'revenue_account', TRUE, p_Amount, p_RevenueDate);

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Revenue Transaction failed: %', SQLERRM;
    END;
END;
$$;

-- ====================================================
-- COA TEMPLATE
-- ===================================================
CREATE OR REPLACE PROCEDURE Finance.apply_coa_template(
    IN p_clientId INT,
    IN p_template_id INT
)
LANGUAGE plpgsql AS $$
BEGIN

    PERFORM 1
    FROM Finance.clients
    WHERE clientId = p_clientId
    FOR UPDATE;

    -- Copy template accounts into client's COA
    INSERT INTO Finance.charts (clientId, account, accountCode, type, is_active)
    SELECT 
        p_clientId,
        accountName,
        accountCode,
        accountType,
        TRUE
    FROM Finance.coatemplateaccounts
    WHERE templateid = p_template_id
    ON CONFLICT (clientId, accountCode) DO NOTHING;  -- Skip duplicates

    RAISE NOTICE 'Template % applied to client %', p_template_id, p_clientId;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'COA Transaction Failed to apply template: %', SQLERRM;
END;
$$;

-- ====================================================
-- INVENTORY MODULE
-- ===================================================
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
    (productId, warehouseId, transactionId, ActionType, quantity, movementDate)
    VALUES
    (p_product_id, p_warehouse_id, p_transaction_id, p_action_type, p_quantity, p_date);
 

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Inventory Module Transaction failed: %', SQLERRM;

END;
$$;

-- ====================================================
-- ACCOUNTING MODULE
-- ===================================================
CREATE OR REPLACE PROCEDURE Finance.accounting_module
(
    IN p_clientId INT,
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
    new_returning_id INT;
BEGIN


    SELECT productCost, productPrice
    INTO v_cost, v_price
    FROM Finance.products
    WHERE productId = p_product_id;

    IF LOWER(p_action_type) = 'purchase' THEN

        -- Accounts Payable
        INSERT INTO Finance.accountpayables 
		(supplierId, transactionId)
        VALUES
		(p_reference_id, p_transaction_id)
	RETURNING PayableID INTO new_returning_id;

	INSERT INTO Finance.ap_ext
		(amount, dueDate, invoiceDate, status, payableId)
        VALUES
		(p_quantity * v_cost, p_date + INTERVAL '30 days', p_date, 'Pending',new_returning_id);
	-- Journal
        CALL Finance.insert_journal
		(p_clientId, p_transaction_id, 'inventory_account', TRUE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal
		(p_clientId, p_transaction_id, 'ap_account', FALSE, p_quantity * v_cost, p_date);

    ELSIF LOWER(p_action_type) = 'sale' THEN

        -- Accounts Receivable
        INSERT INTO Finance.accountreceivables
        	(customerId, transactionId)
        VALUES
        	(p_reference_id, p_transaction_id)
	RETURNING ReceivableID INTO new_returning_id;
        -- Journal
	INSERT INTO Finance.ar_ext
		(amount, dueDate, invoiceDate, status, receivableId)
        VALUES
		(p_quantity * v_cost, p_date + INTERVAL '30 days', p_date, 'Pending',new_returning_id);

        CALL Finance.insert_journal
		(p_clientId, p_transaction_id, 'ar_account', TRUE, p_quantity * v_price, p_date);
        CALL Finance.insert_journal
		(p_clientId, p_transaction_id, 'revenue_account', FALSE, p_quantity * v_price, p_date);

    ELSE
        RAISE EXCEPTION 'Unsupported action type';
    END IF;
  

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Accounting Module Transaction failed: %', SQLERRM;
END;
$$;

-- ====================================================
-- RETURN MODULE
-- ===================================================
CREATE OR REPLACE PROCEDURE Finance.return_module
(
    IN p_clientId INT,
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

    SELECT productCost, productPrice
    INTO v_cost, v_price
    FROM Finance.products
    WHERE productId = p_product_id;

    IF LOWER(p_action_type) = 'sale return' THEN
            -- Journal entry for inventory movement
            INSERT INTO Finance.salereturns
		(receivableId,  returnAmount, returnDate)
            VALUES 
		(p_reference_id, p_quantity * v_price, p_date);
            
        Update Finance.ar_ext
        SET
        Status = 'Returned'
        WHERE 
           ReceivableID = p_reference_id;

        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'SR&Allowances', TRUE, p_quantity * v_price, p_date);
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'ar_account', FALSE, p_quantity * v_price, p_date);
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'inventory_account', TRUE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'COGS', FALSE, p_quantity * v_cost, p_date);

    ELSIF p_action_type = 'Purchase Return' THEN
        -- Journal entry for inventory movement
        INSERT INTO Finance.purchasereturns
		(payableId,  returnAmount, returnDate)
        VALUES 
		(p_reference_id, p_quantity * v_price, p_date);
            
        Update Finance.ap_ext
        SET
        Status = 'Returned'
        WHERE 
        PayableID = p_reference_id;
            
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'ap_account', TRUE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'inventory_account', FALSE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'PR&Allowances', FALSE, p_quantity * v_cost, p_date);    
    ELSE
        RAISE EXCEPTION 'Unsupported action type';
    END IF;
    
  

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Return Module Transaction failed: %', SQLERRM;

END;
$$;


-- ====================================================
-- TRANSFER MODULE 
-- ===================================================
CREATE OR REPLACE PROCEDURE Finance.transfer_module
(
    IN p_clientId INT,
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

    SELECT productCost, productPrice
    INTO v_cost, v_price
    FROM Finance.products
    WHERE ProductID = p_product_id;

    IF p_action_type = 'Transfer' THEN
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'inventory_account', TRUE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'inventory_account', FALSE, p_quantity * v_cost, p_date);
        
        ELSE
            RAISE EXCEPTION 'Invalid Action Type';
        END IF;
  

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transfer Module Transaction failed: %', SQLERRM;

END;
$$;

-- ====================================================
-- INVENTORY PROCESS
-- ===================================================
CREATE OR REPLACE PROCEDURE Finance.process_inventory_transaction
(
    IN p_clientId INT,
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

            --SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

            IF p_quantity <= 0 OR p_quantity IS NULL THEN
                RAISE EXCEPTION 'Quantity must be greater than 0';
            END IF;

            IF p_date IS NULL THEN
                RAISE EXCEPTION 'Date parameter is empty %', SQLERRM;
            END IF;

            IF p_action_type IS NULL OR p_action_type = '' THEN
                RAISE EXCEPTION 'Action Type is empty %', SQLERRM;
            END IF;

            IF p_product_id IS NULL OR p_product_id <= 0 THEN
                RAISE EXCEPTION 'Producit Id is invalid %', SQLERRM;
            END IF;

            IF p_warehouse_id IS NULL OR p_warehouse_id <= 0 THEN
                RAISE EXCEPTION 'Warehouse Id is invalid %', SQLERRM;
            END IF;
            
            -- 🧠 Isolation level (strong consistency)

            SELECT productName INTO v_product_name
            FROM Finance.products
            WHERE ProductId = p_product_id;


            -- 🔒 Lock product FIRST (consistent order = deadlock prevention)
            PERFORM 1
            FROM Finance.products
            WHERE productId = p_product_id
            FOR UPDATE;

            -- 🔒 Lock warehouse SECOND
            PERFORM 1
            FROM Finance.warehouses
            WHERE warehouseId = p_warehouse_id
            FOR UPDATE;

            INSERT INTO Finance.transactions (description, idempotencyKey, clientId)
            VALUES (
                CONCAT( 'Inventory Transaction With Action Type of ', p_action_type , 
                        ' Date on ',p_Date, 
                        ' Product name ', v_product_name),
                p_idempotency_key, p_clientId
                )
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
                p_clientId, new_transaction_id, p_product_id, p_action_type,
                    p_quantity, p_date, p_reference_id
                );

            ELSIF p_action_type IN ('Sale Return','Purchase Return') THEN
                CALL Finance.return_module(
                p_clientId, new_transaction_id, p_product_id, p_action_type,
                    p_quantity, p_date, p_reference_id
                );

            ELSIF p_action_type = 'Transfer' THEN
                CALL Finance.transfer_module(
                    p_clientId, new_transaction_id, p_product_id, p_action_type,
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
                    RAISE EXCEPTION 'Inventory Procuess Module Transaction failed %', SQLERRM;
        END;
   END LOOP;
END;
$$;