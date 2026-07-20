
-- ============================================
-- 6. JOURNAL ENTRY PROCEDURE
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
-- 7. AR TRANSACTION PROCEDURE (FULLY FIXED)
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
    client_check INT;
    customer_check INT; -- Fixed typo: was cusotmer_check
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
            -- 1. Find Accounts
            SELECT c.chart_id INTO v_cash_chart
            FROM Finance.charts c
            INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
            WHERE c.client_id = p_clientId 
            AND ar.role_name = 'cash_account_ar'
            AND c.is_active = TRUE
            LIMIT 1;

            SELECT c.chart_id INTO v_ar_chart
            FROM Finance.charts c
            INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
            WHERE c.client_id = p_clientId 
            AND ar.role_name = 'ar_account'
            AND c.is_active = TRUE
            LIMIT 1;

            -- 2. Validate Client Existence (Fixed: Added semicolons and IS NULL)
            SELECT a.client_id INTO client_check
            FROM Finance.clients a
            WHERE a.client_id = p_clientId
            LIMIT 1; -- Fixed: Added semicolon

            SELECT a.customer_id INTO customer_check -- Fixed: Variable name typo
            FROM Finance.customers a
            WHERE a.customer_id = p_CustomersID
            LIMIT 1; -- Fixed: Added semicolon

            -- Check Client
            IF client_check IS NULL THEN -- Fixed: IN NULL -> IS NULL
                PERFORM Finance.log_compliance_check(
                    p_clientId, 
                    'Client Rules',  
                    'Client not found!', 
                    'CLIENT_CHECK', 
                    'FAIL', 
                    'Client ID not found in database'
                );
                RAISE EXCEPTION 'Client not found!';
            END IF;

            -- Check Customer
            IF customer_check IS NULL THEN
                PERFORM Finance.log_compliance_check(
                    p_clientId, 
                    'Customer Rules',  
                    'Customer not found!', 
                    'CUSTOMER_CHECK', 
                    'FAIL', 
                    'Customer ID not found in database'
                );
                RAISE EXCEPTION 'Customer not found!';
            END IF;

            -- Check Accounts (Crucial: Must happen AFTER client check)
            IF v_cash_chart IS NULL OR v_ar_chart IS NULL THEN
                RAISE EXCEPTION 'Required accounts (cash_account_ar/ar_account) not found for client %', p_clientId;
            END IF;

            -- 3. Locking (Optimized: Lock after validation to reduce lock time if validation fails)
            PERFORM 1 FROM Finance.clients WHERE client_id = p_clientId FOR UPDATE;
            PERFORM 1 FROM Finance.customers WHERE customer_id = p_CustomersID FOR UPDATE;

            -- 4. Compliance Checks
            
            -- Amount Check
            IF p_Amount < 0 THEN
                PERFORM Finance.log_compliance_check(
                    p_clientId, 
                    'Amounts Rule',  
                    'Positive Amount Only!', 
                    'AMOUNT_CHECK', 
                    'FAIL', 
                    format('Amount is %s', p_Amount)
                );
                RAISE EXCEPTION 'Invalid Amount: Must be positive';
            END IF;

            -- Date Check
            IF p_InvoiceDate > p_DueDate THEN
                PERFORM Finance.log_compliance_check(
                    p_clientId, 
                    'Dates Rule',  
                    'Due date must be after invoice date', 
                    'DATE_CHECK', 
                    'FAIL', 
                    format('Invoice: %s, Due: %s', p_InvoiceDate, p_DueDate) -- Fixed: 2 placeholders for 2 args
                );
                RAISE EXCEPTION 'Due Date must be after Invoice Date';
            END IF; 

            -- 5. Insert Transaction
            INSERT INTO Finance.transactions (description, idempotency_key, client_id)
            VALUES (
                CONCAT('Account Receivable With Amount of ', p_Amount, 
                    ' Due Date on ', p_DueDate, 
                    ' Status ', p_Status),
                p_idempotency_key, p_clientId
            )
            ON CONFLICT (idempotency_key) DO NOTHING
            RETURNING transaction_id INTO new_transaction_id;

            -- Handle Idempotency
            IF new_transaction_id IS NULL THEN
                SELECT transaction_id INTO new_transaction_id
                FROM Finance.transactions
                WHERE idempotency_key = p_idempotency_key;
                
                IF new_transaction_id IS NOT NULL THEN
                    PERFORM Finance.log_compliance_check(
                        p_clientId, 
                        'Duplicate Rules',  
                        'Duplicate Transaction Detected', 
                        'DUPLICATE_CHECK', 
                        'FAIL', 
                        format('Duplicate Transaction ID: %s', new_transaction_id)
                    );
                    RAISE NOTICE 'Transaction already exists with ID: %', new_transaction_id;
                    RETURN; 
                ELSE
                    RAISE EXCEPTION 'Unexpected error: Idempotency check failed but no record found.';
                END IF;
            END IF;
    
            -- 6. Insert AR Records
            INSERT INTO Finance.account_receivables (customer_id, transaction_id)
            VALUES (p_CustomersID, new_transaction_id)
            RETURNING receivable_id INTO new_returning_id;

            INSERT INTO Finance.ar_ext (amount, due_date, invoice_date, status, receivable_id)
            VALUES (p_Amount, p_DueDate, p_InvoiceDate, p_Status, new_returning_id);

            -- 7. Journal Entries
            CALL Finance.insert_journal(p_clientId, new_transaction_id, 'cash_account_ar', FALSE, p_Amount, p_InvoiceDate);
            CALL Finance.insert_journal(p_clientId, new_transaction_id, 'ar_account', TRUE, p_Amount, p_InvoiceDate);
            
            -- 8. Log State Change
            CALL Finance.record_state_change(new_transaction_id, p_clientId, 'DRAFT', 'For Validation', current_user, 'Account Receivables successful draft!');

            EXIT; -- Success
            
        EXCEPTION
            WHEN serialization_failure OR deadlock_detected THEN
                v_retry_count := v_retry_count + 1;
                IF v_retry_count >= v_max_retries THEN
                    RAISE EXCEPTION 'Transaction failed after % retries', v_retry_count;
                END IF;
                PERFORM pg_sleep(0.1);
            WHEN OTHERS THEN
                RAISE EXCEPTION 'AR Transaction failed: %', SQLERRM;
        END;
    END LOOP;
END;
$$;