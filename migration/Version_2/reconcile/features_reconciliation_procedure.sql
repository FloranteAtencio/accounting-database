BEGIN;

SELECT 'Loading Bank Reconciliation Procedures...';

-- ============================================
-- PROCEDURE 1: Simple Bank Reconciliation
-- Uses SELECT query approach (no permanent table updates)
-- ============================================
CREATE OR REPLACE FUNCTION Finance.simple_bank_reconciliation(
    p_account_id INT,
    p_statement_date DATE
)
RETURNS TABLE (
    account_number VARCHAR(50),
    bank_name VARCHAR(100),
    statement_balance DECIMAL(15,2),
    book_balance DECIMAL(15,2),
    outstanding_checks DECIMAL(15,2),
    deposits_in_transit DECIMAL(15,2),
    reconciled_balance DECIMAL(15,2),
    difference DECIMAL(15,2),
    status VARCHAR(50)
) AS $$
DECLARE
    v_account_number VARCHAR(50);
    v_bank_name VARCHAR(100);
    v_statement_balance DECIMAL(15,2);
    v_book_balance DECIMAL(15,2);
    v_outstanding_checks DECIMAL(15,2);
    v_deposits_in_transit DECIMAL(15,2);
    v_reconciled_balance DECIMAL(15,2);
    v_difference DECIMAL(15,2);
    v_status VARCHAR(50);
BEGIN
    -- Get bank account info
    SELECT ba.account_number, ba.bank_name
    INTO v_account_number, v_bank_name
    FROM Finance.bank_accounts ba
    WHERE ba.account_id = p_account_id;
    
    -- Get statement balance
    SELECT bs.closing_balance
    INTO v_statement_balance
    FROM Finance.bank_statements bs
    WHERE bs.account_id = p_account_id
    AND bs.statement_date = p_statement_date;
    
    -- Get book balance from journals (GL)
    SELECT COALESCE(SUM(CASE WHEN j.journal THEN j.amount ELSE -j.amount END), 0)
    INTO v_book_balance
    FROM Finance.journals j
    INNER JOIN Finance.bank_accounts ba ON ba.chart_id = j.chart_id
    WHERE ba.account_id = p_account_id
    AND j.date <= p_statement_date;
    
    -- Get outstanding checks (debits not yet cleared)
    SELECT COALESCE(SUM(CASE WHEN bt.transaction_type = 'DEBIT' THEN bt.amount ELSE 0 END), 0)
    INTO v_outstanding_checks
    FROM Finance.bank_transactions bt
    INNER JOIN Finance.bank_statements bs ON bt.statement_id = bs.statement_id
    WHERE bs.account_id = p_account_id
    AND bt.transaction_date > p_statement_date
    AND bt.transaction_type = 'DEBIT';
    
    -- Get deposits in transit (credits not yet cleared)
    SELECT COALESCE(SUM(CASE WHEN bt.transaction_type = 'CREDIT' THEN bt.amount ELSE 0 END), 0)
    INTO v_deposits_in_transit
    FROM Finance.bank_transactions bt
    INNER JOIN Finance.bank_statements bs ON bt.statement_id = bs.statement_id
    WHERE bs.account_id = p_account_id
    AND bt.transaction_date > p_statement_date
    AND bt.transaction_type = 'CREDIT';
    
    -- Calculate reconciled balance
    v_reconciled_balance := v_book_balance - v_outstanding_checks + v_deposits_in_transit;
    
    -- Calculate difference
    v_difference := v_statement_balance - v_reconciled_balance;
    
    -- Determine status
    v_status := CASE 
        WHEN v_difference = 0 THEN 'RECONCILED'
        WHEN ABS(v_difference) < 100 THEN 'VARIANCE (Minor)'
        ELSE 'VARIANCE (Major)'
    END;
    
    RETURN QUERY SELECT 
        v_account_number,
        v_bank_name,
        v_statement_balance,
        v_book_balance,
        v_outstanding_checks,
        v_deposits_in_transit,
        v_reconciled_balance,
        v_difference,
        v_status;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PROCEDURE 2: Detailed Bank Reconciliation Report
-- Shows line-by-line matched and unmatched items
-- ============================================
CREATE OR REPLACE FUNCTION Finance.detailed_bank_reconciliation_report(
    p_account_id INT,
    p_statement_date DATE
)
RETURNS TABLE (
    section VARCHAR(50),
    item_description VARCHAR(255),
    bank_amount DECIMAL(15,2),
    book_amount DECIMAL(15,2),
    status VARCHAR(20),
    reconciliation_notes TEXT
) AS $$
BEGIN
    -- Bank Statement Items
    RETURN QUERY
    SELECT 
        'BANK STATEMENT'::VARCHAR(50),
        'Opening Balance'::VARCHAR(255),
        NULL::DECIMAL(15,2),
        bs.opening_balance,
        'STATEMENT'::VARCHAR(20),
        'Beginning balance from bank'::TEXT
    FROM Finance.bank_statements bs
    WHERE bs.account_id = p_account_id
    AND bs.statement_date = p_statement_date;
    
    -- Bank transactions
    RETURN QUERY
    SELECT 
        'BANK TRANSACTION'::VARCHAR(50),
        bt.description,
        CASE WHEN bt.transaction_type = 'CREDIT' THEN bt.amount ELSE -bt.amount END,
        NULL::DECIMAL(15,2),
        'BANK'::VARCHAR(20),
        'From bank statement: ' || bt.reference_number::TEXT
    FROM Finance.bank_transactions bt
    INNER JOIN Finance.bank_statements bs ON bt.statement_id = bs.statement_id
    WHERE bs.account_id = p_account_id
    AND bs.statement_date = p_statement_date
    ORDER BY bt.transaction_date;
    
    -- Matched journal entries
    RETURN QUERY
    SELECT 
        'JOURNAL ENTRY'::VARCHAR(50),
        j.description,
        NULL::DECIMAL(15,2),
        CASE WHEN j.journal THEN j.amount ELSE -j.amount END,
        'MATCHED'::VARCHAR(20),
        'Matched to GL'::TEXT
    FROM Finance.journals j
    INNER JOIN Finance.bank_accounts ba ON ba.chart_id = j.chart_id
    WHERE ba.account_id = p_account_id
    AND j.date <= p_statement_date
    ORDER BY j.date;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PROCEDURE 3: Automatic Reconciliation Matching
-- Matches bank transactions to journal entries
-- ============================================
CREATE OR REPLACE PROCEDURE Finance.auto_match_bank_transactions(
    p_account_id INT,
    p_statement_date DATE,
    p_variance_tolerance DECIMAL DEFAULT 0.01
)
LANGUAGE plpgsql AS $$
DECLARE
    v_reconciliation_id INT;
    v_bank_trans_id INT;
    v_journal_id INT;
    v_bank_amount DECIMAL(15,2);
    v_journal_amount DECIMAL(15,2);
    v_matched_count INT := 0;
    v_unmatched_count INT := 0;
BEGIN
    -- Create reconciliation record
    INSERT INTO Finance.bank_reconciliations 
        (account_id, reconciliation_date, statement_balance, book_balance, status)
    SELECT 
        p_account_id,
        p_statement_date,
        bs.closing_balance,
        COALESCE(SUM(CASE WHEN j.journal THEN j.amount ELSE -j.amount END), 0),
        'IN_PROGRESS'
    FROM Finance.bank_statements bs
    LEFT JOIN Finance.journals j ON j.chart_id IN (
        SELECT chart_id FROM Finance.bank_accounts WHERE account_id = p_account_id
    )
    AND j.date <= p_statement_date
    WHERE bs.account_id = p_account_id
    AND bs.statement_date = p_statement_date
    GROUP BY bs.closing_balance
    RETURNING reconciliation_id INTO v_reconciliation_id;
    
    -- Attempt to match bank transactions to journal entries
    FOR v_bank_trans_id, v_bank_amount IN
        SELECT bt.bank_trans_id, 
            CASE WHEN bt.transaction_type = 'CREDIT' THEN bt.amount ELSE -bt.amount END
        FROM Finance.bank_transactions bt
        INNER JOIN Finance.bank_statements bs ON bt.statement_id = bs.statement_id
        WHERE bs.account_id = p_account_id
        AND bs.statement_date = p_statement_date
    LOOP
        -- Find matching journal entry
        SELECT j.journal_id, 
            CASE WHEN j.journal THEN j.amount ELSE -j.amount END
        INTO v_journal_id, v_journal_amount
        FROM Finance.journals j
        WHERE ABS(v_bank_amount - CASE WHEN j.journal THEN j.amount ELSE -j.amount END) <= p_variance_tolerance
        AND j.date <= p_statement_date
        AND NOT EXISTS (
            SELECT 1 FROM Finance.reconciliation_matches rm 
            WHERE rm.journal_id = j.journal_id
        )
        LIMIT 1;
        
        IF v_journal_id IS NOT NULL THEN
            -- Insert match
            INSERT INTO Finance.reconciliation_matches 
                (reconciliation_id, bank_trans_id, journal_id, matched_amount)
            VALUES (v_reconciliation_id, v_bank_trans_id, v_journal_id, v_bank_amount);
            
            v_matched_count := v_matched_count + 1;
        ELSE
            v_unmatched_count := v_unmatched_count + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Reconciliation %: Matched %, Unmatched %', v_reconciliation_id, v_matched_count, v_unmatched_count;
END;
$$;

SELECT 'Bank Reconciliation Procedures Loaded Successfully!';
COMMIT;