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
    SELECT c.chart_id INTO v_chart_id
    FROM Finance.charts c
    INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
    WHERE c.client_id = p_clientId 
      AND ar.role_name = p_account_role
      AND c.is_active = TRUE
    LIMIT 1;

    IF v_chart_id IS NULL THEN
        RAISE EXCEPTION 'Account role % not found for client %', p_account_role, p_clientId;
    END IF;

    INSERT INTO Finance.journals (transaction_id, chart_id, date, journal, amount)
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
            SELECT c.chart_id INTO v_cash_chart
            FROM Finance.charts c
            INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
            WHERE c.client_id = p_clientId 
            AND ar.role_name = 'cash_account_ar'
            AND c.is_active = TRUE
            LIMIT 1;

            -- Find AR account
            SELECT c.chart_id INTO v_ar_chart
            FROM Finance.charts c
            INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
            WHERE c.client_id = p_clientId 
            AND ar.role_name = 'ar_account'
            AND c.is_active = TRUE
            LIMIT 1;

            IF v_cash_chart IS NULL OR v_ar_chart IS NULL THEN
                RAISE EXCEPTION 'Required accounts (cash_account_ar/ar_account) not found for client %', p_clientId;
            END IF;

            PERFORM 1
            FROM Finance.clients
            WHERE client_id = p_clientId
            FOR UPDATE;

            PERFORM 1
            FROM Finance.customers
            WHERE customer_id = p_CustomersID
            FOR UPDATE;

            -- Balance check
            -- SELECT SUM(
            --     CASE WHEN journal THEN amount ELSE -amount END
            -- ) INTO v_balance
            -- FROM Finance.journals
            -- WHERE chart_id = v_cash_chart;

            -- IF p_Amount < COALESCE(v_balance, 0) THEN
            --     RAISE EXCEPTION 'Insufficient Funds. Available: %, Required: %', COALESCE(v_balance, 0), p_Amount;
            -- END IF;

            -- Insert transaction
            INSERT INTO Finance.transactions (description, idempotency_key, client_id)
            VALUES (
                CONCAT('Account Receivable With Amount of ', p_Amount, 
                    ' Due Date on ', p_DueDate, 
                    ' Status ', p_Status),
                p_idempotency_key, p_clientId
            )
            ON CONFLICT (idempotency_key) DO NOTHING
            RETURNING Transaction_id INTO new_transaction_id;

            IF new_transaction_id IS NULL THEN
                SELECT transaction_id INTO new_transaction_id
                FROM Finance.transactions
                WHERE idempotency_key = p_idempotency_key;
                RETURN;
            END IF;

            -- Insert AR record
            INSERT INTO Finance.account_receivables (customer_id, transaction_id)
            VALUES (p_CustomersID, new_transaction_id)
            RETURNING receivable_id INTO new_returning_id;

            -- Insert AR extension
            INSERT INTO Finance.ar_ext (amount, due_date, invoice_date, status, receivable_id)
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
            SELECT c.chart_id INTO v_cash_chart
            FROM Finance.charts c
            INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
            WHERE c.client_id = p_clientId 
            AND ar.role_name = 'cash_account_ap'
            AND c.is_active = TRUE
            LIMIT 1;

            -- Find AP account
            SELECT c.chart_id INTO v_ap_chart
            FROM Finance.charts c
            INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
            WHERE c.client_id = p_clientId 
            AND ar.role_name = 'ap_account'
            AND c.is_active = TRUE
            LIMIT 1;

            IF v_cash_chart IS NULL OR v_ap_chart IS NULL THEN
                RAISE EXCEPTION 'Required accounts (cash_account_ap/ap_account) not found for client %', p_clientId;
            END IF;

            PERFORM 1
            FROM Finance.clients
            WHERE client_id = p_clientId
            FOR UPDATE;

            PERFORM 1
            FROM Finance.suppliers
            WHERE supplier_id = p_VendorID
            FOR UPDATE;

            -- Insert transaction
            INSERT INTO Finance.transactions (description, idempotency_key, client_id)
            VALUES (
                CONCAT('Account Payable With Amount of ', p_Amount, 
                    ' Due Date on ', p_DueDate, 
                    ' Status ', p_Status),
                p_idempotency_key, p_clientId
            )
            ON CONFLICT (idempotency_key) DO NOTHING
            RETURNING Transaction_id INTO new_transaction_id;

            IF new_transaction_id IS NULL THEN
                SELECT transaction_id INTO new_transaction_id
                FROM Finance.transactions
                WHERE idempotency_key = p_idempotency_key;
                RETURN;
            END IF;

            -- Insert AP record
            INSERT INTO Finance.account_payables (supplier_id, transaction_id)
            VALUES (p_VendorID, new_transaction_id)
            RETURNING Payable_id INTO new_returning_id;

            -- Insert AP extension
            INSERT INTO Finance.ap_ext (amount, due_date, invoice_date, status, payable_id)
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
        SELECT c.chart_id INTO v_cash_chart
        FROM Finance.charts c
        INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
        WHERE c.client_id = p_clientId 
          AND ar.role_name = 'cash_account_ar'
          AND c.is_active = TRUE
        LIMIT 1;

        -- Find expense account
        SELECT c.chart_id INTO v_expense_chart
        FROM Finance.charts c
        INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
        WHERE c.client_id = p_clientId 
          AND ar.role_name = 'expense_account'
          AND c.is_active = TRUE
        LIMIT 1;

        IF v_cash_chart IS NULL OR v_expense_chart IS NULL THEN
            RAISE EXCEPTION 'Required accounts (cash/expense) not found for client %', p_clientId;
        END IF;

        PERFORM 1  
        FROM Finance.clients
        WHERE client_id = p_clientId
        FOR UPDATE;

        -- Insert transaction
        INSERT INTO Finance.transactions (description, idempotency_key, client_id)
        VALUES (p_Description, p_idempotency_key,p_clientId)
        ON CONFLICT (idempotency_key) DO NOTHING
        RETURNING Transaction_id INTO new_transaction_id;

        IF new_transaction_id IS NULL THEN
            SELECT transaction_id INTO new_transaction_id
            FROM Finance.transactions
            WHERE idempotency_key = p_idempotency_key;
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
        SELECT c.chart_id INTO v_cash_chart
        FROM Finance.charts c
        INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
        WHERE c.client_id = p_clientId 
          AND ar.role_name = 'cash_account_ar'
          AND c.is_active = TRUE
        LIMIT 1;

        -- Find revenue account
        SELECT c.chart_id INTO v_revenue_chart
        FROM Finance.charts c
        INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
        WHERE c.client_id = p_clientId 
          AND ar.role_name = 'revenue_account'
          AND c.is_active = TRUE
        LIMIT 1;

        IF v_cash_chart IS NULL OR v_revenue_chart IS NULL THEN
            RAISE EXCEPTION 'Required accounts (cash/revenue) not found for client %', p_clientId;
        END IF;

        PERFORM 1
        FROM Finance.clients
        WHERE client_id = p_clientId
        FOR UPDATE;

        -- Insert transaction
        INSERT INTO Finance.transactions (description, idempotency_key, client_id)
        VALUES (p_Description, p_idempotency_key, p_clientId)
        ON CONFLICT (idempotency_key) DO NOTHING
        RETURNING Transaction_id INTO new_transaction_id;

        IF new_transaction_id IS NULL THEN
            SELECT Transaction_id INTO new_transaction_id
            FROM Finance.transactions
            WHERE idempotency_key = p_idempotency_key;
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
    WHERE client_id = p_clientId
    FOR UPDATE;

    -- Copy template accounts into client's COA
    INSERT INTO Finance.charts (client_id, account, account_code, type, is_active)
    SELECT 
        p_clientId,
        account_name,
        account_code,
        account_type,
        TRUE
    FROM Finance.coa_template_accounts
    WHERE template_id = p_template_id
    ON CONFLICT (client_id, account_code) DO NOTHING;  -- Skip duplicates

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

    INSERT INTO Finance.inventory_audits
    (product_id, warehouse_id, transaction_id, action_type, quantity, movement_date)
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
    v_cost_purchase DECIMAL;
    v_price_purchase DECIMAL;
    v_cost_sales DECIMAL;
    v_price_sales DECIMAL;
    v_taxrate DECIMAL;
    new_returning_id INT;
    v_quantity INT;
    v_operation_id INT;
    quantity_holder INT;

    operation_cursor CURSOR FOR
        SELECT operation_id, product_cost, product_price, quantity
        FROM Finance.operations
        WHERE product_id = p_product_id;
    
BEGIN    
    -- FIX 1: Added semicolon here
    SELECT rate_percentage 
    INTO v_taxrate
    FROM finance.tax_rates
    WHERE tax_type = 'VAT';

    IF LOWER(p_action_type) = 'purchase' THEN
        
        SELECT product_cost, product_price
        INTO v_cost_purchase, v_price_purchase
        FROM Finance.operations
        WHERE operation_id = p_product_id;

        -- Accounts Payable
        INSERT INTO Finance.account_payables 
        (supplier_id, transaction_id)
        VALUES
        (p_reference_id, p_transaction_id)
        RETURNING Payable_id INTO new_returning_id;

        INSERT INTO Finance.ap_ext
        (amount, due_date, invoice_date, status, payable_id)
        VALUES
        ((p_quantity * v_cost_purchase) * (1 + v_taxrate), p_date + INTERVAL '30 days', p_date, 'Pending', new_returning_id);

        -- FIX 2: Added missing closing parenthesis and semicolon
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'inventory_account', TRUE, p_quantity * v_cost_purchase, p_date);
        
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'Input VAT Receivable - Asset', TRUE, (p_quantity * v_cost_purchase) * v_taxrate, p_date);
        
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'ap_account', FALSE, (p_quantity * v_cost_purchase) * (1 + v_taxrate), p_date);

    ELSIF LOWER(p_action_type) = 'sale' THEN
        quantity_holder := p_quantity;
        OPEN operation_cursor;
        LOOP
            FETCH operation_cursor INTO v_operation_id, v_cost_sales, v_price_sales, v_quantity;
            EXIT WHEN NOT FOUND;

            IF v_quantity > 0 THEN
                -- FIX 3: Added semicolon
                quantity_holder := quantity_holder - v_quantity; 
                
                -- Accounts Receivable
                INSERT INTO Finance.account_receivables
                (customer_id, transaction_id)
                VALUES
                (p_reference_id, p_transaction_id)
                RETURNING Receivable_id INTO new_returning_id;

                -- Note: Logic check on this formula: (Price * Tax) + Cost? 
                -- Usually AR is just Price * (1+Tax). 
                -- Keeping your logic but fixing syntax.
                INSERT INTO Finance.ar_ext
                (amount, due_date, invoice_date, status, receivable_id)
                VALUES
                (((p_quantity * v_price_sales) * (1 + v_taxrate)), p_date + INTERVAL '30 days', p_date, 'Pending', new_returning_id);

                CALL Finance.insert_journal(p_clientId, p_transaction_id, 'ar_account', TRUE, (p_quantity * v_price_sales) * (1 + v_taxrate), p_date);
                CALL Finance.insert_journal(p_clientId, p_transaction_id, 'revenue_account', FALSE, p_quantity * v_price_sales, p_date);
                CALL Finance.insert_journal(p_clientId, p_transaction_id, 'Output VAT Payable - Liability', FALSE, (p_quantity * v_price_sales) * v_taxrate, p_date);
                
                CALL Finance.insert_journal(p_clientId, p_transaction_id, 'COGS', TRUE, p_quantity * v_cost_sales, p_date);
                CALL Finance.insert_journal(p_clientId, p_transaction_id, 'inventory_account', FALSE, p_quantity * v_cost_sales, p_date);
                
                IF quantity_holder <= 0 THEN
                    UPDATE Finance.operations
                    SET quantity = quantity - v_quantity -- Fixed logic: subtract the specific chunk used
                    WHERE operation_id = v_operation_id;

                    EXIT;
                END IF;
            END IF;
        END LOOP;
        CLOSE operation_cursor;        
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

    SELECT product_cost, product_price
    INTO v_cost, v_price
    FROM Finance.operations
    WHERE product_id = p_product_id;

    IF LOWER(p_action_type) = 'sale return' THEN
            -- Journal entry for inventory movement
            INSERT INTO Finance.sale_returns
		(receivable_id,  return_Amount, return_date)
            VALUES 
		(p_reference_id, p_quantity * v_price, p_date);
            
        Update Finance.ar_ext
        SET
        Status = 'Returned'
        WHERE 
           Receivable_id = p_reference_id;

        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'SR&Allowances', FALSE, p_quantity * v_price, p_date);
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'ar_account', TRUE, p_quantity * v_price, p_date);
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'inventory_account', FALSE, p_quantity * v_cost, p_date);
        CALL Finance.insert_journal(p_clientId, p_transaction_id, 'COGS', TRUE, p_quantity * v_cost, p_date);

    ELSIF p_action_type = 'Purchase Return' THEN
        -- Journal entry for inventory movement
        INSERT INTO Finance.purchase_returns
		(payable_id,  return_Amount, return_date)
        VALUES 
		(p_reference_id, p_quantity * v_price, p_date);
            
        Update Finance.ap_ext
        SET
        Status = 'Returned'
        WHERE 
        Payable_id = p_reference_id;
            
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


CREATE OR REPLACE PROCEDURE Finance.operations_module(
    IN p_product_id INT,
    IN p_product_price DECIMAL,
    IN p_product_cost DECIMAL,
    IN p_quantity INT,
    IN p_date DATE
)LANGUAGE plpgsql
AS $$
DECLARE

BEGIN

    INSERT INTO Finance.operations (product_id,quantity,product_cost,product_price,purchase_date)
    VALUES (p_product_id,p_quantity,p_product_price,p_product_cost,p_date);

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Journal entry failed: %', SQLERRM;
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

    SELECT product_cost, product_price
    INTO v_cost, v_price
    FROM Finance.operations
    WHERE Product_id = p_product_id;

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

--===================================
-- INVENTORY SALE 
--===================================
CREATE OR REPLACE PROCEDURE Finance.sale_inventory(
    IN p_clientId INT,
    IN p_product_id INT,
    IN p_warehouse_id INT,
    IN p_quantity INT,
    IN p_date DATE,
    IN p_reference_id INT,
    IN p_idempotency_key VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_transaction_id INT;
    var_total_quantity INT;
BEGIN

            IF p_quantity <= 0 OR p_quantity IS NULL THEN
                RAISE EXCEPTION 'Quantity must be greater than 0';
            END IF;

            IF p_date IS NULL THEN
                RAISE EXCEPTION 'Date parameter is empty %', SQLERRM;
            END IF;

            IF p_product_id IS NULL OR p_product_id <= 0 THEN
                RAISE EXCEPTION 'Producit Id is invalid %', SQLERRM;
            END IF;

            IF p_warehouse_id IS NULL OR p_warehouse_id <= 0 THEN
                RAISE EXCEPTION 'Warehouse Id is invalid %', SQLERRM;
            END IF;

            -- -- 🔒 Lock product FIRST (consistent order = deadlock prevention)
            PERFORM 1
            FROM Finance.products
            WHERE product_id = p_product_id
            FOR UPDATE;

            -- 🔒 Lock warehouse SECOND
            PERFORM 1
            FROM Finance.warehouses
            WHERE warehouse_id = p_warehouse_id
            FOR UPDATE;
            
            INSERT INTO Finance.transactions (description, idempotency_key, client_id)
            VALUES (
                CONCAT( 'Inventory Transaction With Action Type of ', p_action_type , 
                        ' Date on ',p_Date, 
                        ' Product name ', v_product_name),
                p_idempotency_key, p_clientId
                )
            ON CONFLICT(idempotency_key) DO NOTHING
            RETURNING Transaction_id INTO new_transaction_id;

            IF new_transaction_id IS NULL THEN
                SELECT Transaction_id INTO new_transaction_id
                FROM Finance.transactions
                WHERE idempotency_key = p_idempotency_key;

                RETURN;
            END IF;
            
            -- SELECT
            --     SUM( quantity ) 
            -- INTO var_total_quantity  -- Add your variable name here
            -- FROM Finance.operations
            -- WHERE product_id = p_product_id;

            -- if var_total_quantity <= 0 THEN
            --     RAISE EXCEPTION 'Insufficient quantity for product ID: % no remainig quantity %',p_product_id, var_total_quantity;
                
            -- if p_quantity > var_total_quantity THEN
            --     RAISE EXCEPTION 'Insufficient quantity for product ID: % remainig quantity % at warehouse %',p_product_id, var_total_quantity, p_warehouse_id;
            -- 📦 Inventory
            CALL Finance.inventory_module(
                p_product_id,
                p_warehouse_id,
                new_transaction_id,
                'Sale',
                p_quantity,
                p_date
            );

            CALL Finance.accounting_module(
                p_clientId, 
                new_transaction_id, 
                p_product_id, 
                'Sale',--p_action_type,
                p_quantity, 
                p_date, 
                p_reference_id
            );
    
    EXCEPTION
        WHEN OTHERS THEN
            -- ❌ Real error → stop immediately
            RAISE EXCEPTION 'Inventory Procuess Module Transaction failed %', SQLERRM;
END;
$$;

--===================================
-- INVENTORY PURCHASE 
--===================================
CREATE OR REPLACE PROCEDURE Finance.purchase_inventory(
    IN p_clientId INT,
    IN p_product_id INT,
    IN p_warehouse_id INT,
    --IN p_action_type VARCHAR(50),
    IN p_quantity INT,
    IN p_date DATE,
    IN p_reference_id INT,
    IN p_idempotency_key VARCHAR(255),
    IN p_product_cost DECIMAL,
    IN p_product_price DECIMAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_transaction_id INT;
    new_operation_id INT;
BEGIN
            IF p_quantity <= 0 OR p_quantity IS NULL THEN
                RAISE EXCEPTION 'Quantity must be greater than 0';
            END IF;

            IF p_date IS NULL THEN
                RAISE EXCEPTION 'Date parameter is empty %', SQLERRM;
            END IF;

            IF p_product_id IS NULL OR p_product_id <= 0 THEN
                RAISE EXCEPTION 'Producit Id is invalid %', SQLERRM;
            END IF;

            IF p_warehouse_id IS NULL OR p_warehouse_id <= 0 THEN
                RAISE EXCEPTION 'Warehouse Id is invalid %', SQLERRM;
            END IF;

            -- -- 🔒 Lock product FIRST (consistent order = deadlock prevention)
            PERFORM 1
            FROM Finance.products
            WHERE product_id = p_product_id
            FOR UPDATE;

            -- 🔒 Lock warehouse SECOND
            PERFORM 1
            FROM Finance.warehouses
            WHERE warehouse_id = p_warehouse_id
            FOR UPDATE;
            
            INSERT INTO Finance.transactions (description, idempotency_key, client_id)
            VALUES (
                CONCAT( 'Inventory Transaction With Action Type of ', p_action_type , 
                        ' Date on ',p_Date, 
                        ' Product name ', v_product_name),
                p_idempotency_key, p_clientId
                )
            ON CONFLICT(idempotency_key) DO NOTHING
            RETURNING Transaction_id INTO new_transaction_id;

            IF new_transaction_id IS NULL THEN
                SELECT Transaction_id INTO new_transaction_id
                FROM Finance.transactions
                WHERE idempotency_key = p_idempotency_key;
                RETURN;
            END IF;

            CALL Finance.inventory_module(
                p_product_id,
                p_warehouse_id,
                new_transaction_id,
                'Purchase',
                p_quantity,
                p_date
            );

            INSERT INTO Finance.operations (product_id,quantity,product_cost,product_price,purchase_date)
            VALUES (p_product_id,p_quantity,p_product_price,p_product_cost,p_date)
            RETURNING operation_id INTO new_operation_id;
            
            CALL Finance.accounting_module(
                p_clientId, 
                new_transaction_id, 
                new_operation_id, 
                'Purchase',--p_action_type,
                p_quantity, 
                p_date, 
                p_reference_id
            );    

    EXCEPTION
        WHEN OTHERS THEN
            -- ❌ Real error → stop immediately
            RAISE EXCEPTION 'Inventory Procuess Module Transaction failed %', SQLERRM;
END;
$$;

-- -- ====================================================
-- -- INVENTORY PROCESS
-- -- ===================================================
-- CREATE OR REPLACE PROCEDURE Finance.process_inventory_transaction
-- (
--     IN p_clientId INT,
--     IN p_product_id INT,
--     IN p_warehouse_id INT,
--     IN p_action_type VARCHAR(50),
--     IN p_quantity INT,
--     IN p_date DATE,
--     IN p_reference_id INT,
--     IN p_idempotency_key VARCHAR(255)
-- )
-- LANGUAGE plpgsql
-- AS $$
-- DECLARE
--     new_transaction_id INT;
--     v_retry_count INT := 0;
--     v_max_retries INT := 3;
--     var_total_quantity INT;
--     v_product_name VARCHAR(255);
-- BEGIN
--     -- 🔁 Retry loop for serialization / deadlocks
--     LOOP
--         BEGIN                   
--             --SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

--             IF p_quantity <= 0 OR p_quantity IS NULL THEN
--                 RAISE EXCEPTION 'Quantity must be greater than 0';
--             END IF;

--             IF p_date IS NULL THEN
--                 RAISE EXCEPTION 'Date parameter is empty %', SQLERRM;
--             END IF;

--             IF p_action_type IS NULL OR p_action_type = '' THEN
--                 RAISE EXCEPTION 'Action Type is empty %', SQLERRM;
--             END IF;

--             IF p_product_id IS NULL OR p_product_id <= 0 THEN
--                 RAISE EXCEPTION 'Producit Id is invalid %', SQLERRM;
--             END IF;

--             IF p_warehouse_id IS NULL OR p_warehouse_id <= 0 THEN
--                 RAISE EXCEPTION 'Warehouse Id is invalid %', SQLERRM;
--             END IF;
            
--             -- 🧠 Isolation level (strong consistency)
--             SELECT product_name INTO v_product_name
--             FROM Finance.products
--             WHERE Product_id = p_product_id;

--             -- 🔒 Lock product FIRST (consistent order = deadlock prevention)
--             PERFORM 1
--             FROM Finance.products
--             WHERE product_id = p_product_id
--             FOR UPDATE;

--             -- 🔒 Lock warehouse SECOND
--             PERFORM 1
--             FROM Finance.warehouses
--             WHERE warehouse_id = p_warehouse_id
--             FOR UPDATE;

--             INSERT INTO Finance.transactions (description, idempotency_key, client_id)
--             VALUES (
--                 CONCAT( 'Inventory Transaction With Action Type of ', p_action_type , 
--                         ' Date on ',p_Date, 
--                         ' Product name ', v_product_name),
--                 p_idempotency_key, p_clientId
--                 )
--             ON CONFLICT(idempotency_key) DO NOTHING
--             RETURNING Transaction_id INTO new_transaction_id;

--             IF new_transaction_id IS NULL THEN
--                 SELECT Transaction_id INTO new_transaction_id
--                 FROM Finance.transactions
--                 WHERE idempotency_key = p_idempotency_key;
                
--                 RETURN;
--             END IF;

--             SELECT  SUM(
--                     CASE 
--                         WHEN account_type IN ('Sale', 'Purchase Return') THEN -quantity 
--                         WHEN account_type IN ('Purchase', 'Sale Return') THEN quantity
--                         ELSE 0
--                     END
--                 ) 
--                 INTO var_total_quantity  -- Add your variable name here
--                 FROM Finance.inventory_audits
--                 WHERE product_id = p_product_id;

--             if var_total_quantity <= 0 THEN
--                 RAISE EXCEPTION 'Insufficient quantity for product ID: % no remainig quantity ',p_product_id, var_total_quantity;
                
--             if p_quantity > var_total_quantity THEN
--                 RAISE EXCEPTION 'Insufficient quantity for product ID: % remainig quantity % at warehouse %',p_product_id, var_total_quantity, p_warehouse_id;
--             -- 📦 Inventory
--             CALL Finance.inventory_module(
--                 p_product_id,
--                 p_warehouse_id,
--                 new_transaction_id,
--                 p_action_type,
--                 p_quantity,
--                 p_date
--             );

--             -- 💰 Accounting / Returns / Transfer
--             IF p_action_type IN ('Sale', 'Purchase') THEN
--                 CALL Finance.accounting_module(
--                 p_clientId, new_transaction_id, p_product_id, p_action_type,
--                     p_quantity, p_date, p_reference_id
--                 );

--             ELSIF p_action_type IN ('Sale Return','Purchase Return') THEN
--                 CALL Finance.return_module(
--                 p_clientId, new_transaction_id, p_product_id, p_action_type,
--                     p_quantity, p_date, p_reference_id
--                 );

--             ELSIF p_action_type = 'Transfer' THEN
--                 CALL Finance.transfer_module(
--                     p_clientId, new_transaction_id, p_product_id, p_action_type,
--                     p_quantity, p_date, p_reference_id
--                 );
--             ELSE
--                 RAISE EXCEPTION 'Unsupported action type';
--             END IF;

--             -- ✅ SUCCESS → exit retry loop
--             EXIT;

--             EXCEPTION
--                 WHEN serialization_failure OR deadlock_detected THEN
--                     v_retry_count := v_retry_count + 1;

--                     IF v_retry_count >= v_max_retries THEN
--                         RAISE EXCEPTION 'Transaction failed after % retries', v_retry_count;
--                     END IF;

--                     -- ⏳ Small delay before retry (helps contention)
--                     PERFORM pg_sleep(0.1);

--                 WHEN OTHERS THEN
--                     -- ❌ Real error → stop immediately
--                     RAISE EXCEPTION 'Inventory Procuess Module Transaction failed %', SQLERRM;
--         END;
--    END LOOP;
-- END;
-- $$;