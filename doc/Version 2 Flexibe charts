Version 2 Flexible charts

-- Goal
Purpose is for multiple tenant of clients that has unique set of charts of account. This is will help us to distinct identify each client financial records and their own format of accounts.


-- Resolve
This update helps me from break my code with different accountcode and account base on our clients norms.With the help of this update we can assign and identify which account has role to use specific use for (Account Receivables, Account Payables Revenue and so on.)

-- Challenges
This update changes 20% of the version 1 and added. 
Tables added and modify some of tables for clients to be able distinctly identify.
Business logic this make multiple changes due inorder to adapt to the new update.

here are the code added to and edit from the version 1 

-- ============================================
-- 1. CLIENTS TABLE
-- this is where client information store
-- ============================================
DROP TABLE IF EXISTS Finance.clients CASCADE;
CREATE TABLE IF NOT EXISTS Finance.clients (
    clientId SERIAL PRIMARY KEY,
    info JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2. COA TEMPLATES (for reference/defaults)
-- template information for set of charts of account 
-- ============================================
DROP TABLE IF EXISTS Finance.coatemplates CASCADE;
CREATE TABLE IF NOT EXISTS Finance.coatemplates (
    templateId SERIAL PRIMARY KEY,
    templateName VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2.1 COA TEMPLATES (for reference/defaults)
-- the template chart of account 
-- ============================================
DROP TABLE IF EXISTS Finance.coatemplateaccounts CASCADE;
CREATE TABLE IF NOT EXISTS Finance.coatemplateaccounts (
    templateAccountId BIGSERIAL PRIMARY KEY,
    templateId INT NOT NULL REFERENCES Finance.coatemplates(templateid) ON DELETE CASCADE,
    accountCode INT NOT NULL,
    accountName VARCHAR(100) NOT NULL,
    accountType VARCHAR(50) NOT NULL,
    UNIQUE(templateid, accountcode)
);


-- ============================================
-- 3. CHART OF ACCOUNTS (client-specific)
-- the actual chart of account given to client and use for operations
-- ============================================
DROP TABLE IF EXISTS Finance.charts CASCADE;
CREATE TABLE IF NOT EXISTS Finance.charts (
    chartId BIGSERIAL PRIMARY KEY,
    clientId INT NOT NULL REFERENCES Finance.clients(clientId) ON DELETE CASCADE,
    account VARCHAR(100) NOT NULL,
    accountCode INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(clientId, accountCode)
);

-- ============================================
-- 4. ACCOUNT ROLES (flexible, multiple roles per account)
-- this is use to assign multiple accounts for specific use. 
-- ============================================
DROP TABLE IF EXISTS Finance.accountroles CASCADE;
CREATE TABLE IF NOT EXISTS Finance.accountroles (
    roleId SERIAL PRIMARY KEY,
    chartId INT NOT NULL REFERENCES Finance.charts(chartId) ON DELETE CASCADE,
    roleName VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(chartId, roleName)
);

-- ============================================
-- 5. ACCOUNT PROPERTIES
-- with this account for specification
-- ============================================
DROP TABLE IF EXISTS Finance.accountproperties CASCADE;
CREATE TABLE IF NOT EXISTS Finance.accountproperties (
    propertyId SERIAL PRIMARY KEY,
    chartId INT NOT NULL REFERENCES Finance.charts(chartId) ON DELETE CASCADE,
    is_payable BOOLEAN,
    is_debt BOOLEAN,
    is_bank_account BOOLEAN,
    is_credit_card BOOLEAN,
    requires_reconciliation BOOLEAN,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS Finance.transactions CASCADE;
CREATE TABLE IF NOT EXISTS Finance.transactions (
    transactionID BIGSERIAL PRIMARY KEY,
    description TEXT NOT NULL,
    idempotencyKey TEXT UNIQUE NOT NULL,
    clientId INT REFERENCES Finance.clients(clientId) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Business logic 

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

--- Disclaimer ---
I intentionally remove the partition table for me able to freely test and validate data. all of my partition table were date related