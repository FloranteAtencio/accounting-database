BEGIN;

SELECT 'Loading Bank Reconciliation Tables...';

-- ============================================
-- 1. BANK ACCOUNTS
-- ============================================
CREATE TABLE Finance.bank_accounts (
    account_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    chart_id INT NOT NULL REFERENCES Finance.charts(chart_id),
    account_number VARCHAR(50) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20),  -- Checking, Savings, etc
    currency VARCHAR(3) DEFAULT 'PHP',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_id, account_number)
);

-- ============================================
-- 2. BANK STATEMENTS
-- ============================================
CREATE TABLE Finance.bank_statements (
    statement_id BIGSERIAL PRIMARY KEY,
    account_id INT NOT NULL REFERENCES Finance.bank_accounts(account_id),
    statement_date DATE NOT NULL,
    opening_balance DECIMAL(15,2) NOT NULL,
    closing_balance DECIMAL(15,2) NOT NULL,
    statement_period_start DATE NOT NULL,
    statement_period_end DATE NOT NULL,
    statement_file VARCHAR(255),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(account_id, statement_date)
);

-- ============================================
-- 3. BANK TRANSACTIONS
-- ============================================
CREATE TABLE Finance.bank_transactions (
    bank_trans_id BIGSERIAL PRIMARY KEY,
    statement_id INT NOT NULL REFERENCES Finance.bank_statements(statement_id),
    transaction_date DATE NOT NULL,
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('DEBIT', 'CREDIT')),
    reference_number VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 4. BANK RECONCILIATION RECORDS
-- ============================================
CREATE TABLE Finance.bank_reconciliations (
    reconciliation_id BIGSERIAL PRIMARY KEY,
    account_id INT NOT NULL REFERENCES Finance.bank_accounts(account_id),
    reconciliation_date DATE NOT NULL,
    statement_balance DECIMAL(15,2) NOT NULL,
    book_balance DECIMAL(15,2) NOT NULL,
    difference DECIMAL(15,2),
    outstanding_checks DECIMAL(15,2) DEFAULT 0,
    deposits_in_transit DECIMAL(15,2) DEFAULT 0,
    reconciled_balance DECIMAL(15,2),
    status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'IN_PROGRESS', 'RECONCILED', 'VARIANCE')),
    reconciled_by VARCHAR(100),
    reconciled_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(account_id, reconciliation_date)
);

-- ============================================
-- 5. RECONCILIATION MATCHES
-- Maps bank transactions to journal entries
-- ============================================
CREATE TABLE Finance.reconciliation_matches (
    match_id BIGSERIAL PRIMARY KEY,
    reconciliation_id INT NOT NULL REFERENCES Finance.bank_reconciliations(reconciliation_id),
    bank_trans_id INT NOT NULL REFERENCES Finance.bank_transactions(bank_trans_id),
    journal_id INT NOT NULL REFERENCES Finance.journals(journal_id),
    matched_amount DECIMAL(15,2) NOT NULL,
    match_status VARCHAR(20) DEFAULT 'MATCHED' 
        CHECK (match_status IN ('MATCHED', 'PENDING', 'VARIANCE')),
    variance_amount DECIMAL(15,2),
    matched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. OUTSTANDING ITEMS (Not yet reconciled)
-- ============================================
CREATE TABLE Finance.outstanding_items (
    item_id BIGSERIAL PRIMARY KEY,
    reconciliation_id INT NOT NULL REFERENCES Finance.bank_reconciliations(reconciliation_id),
    item_type VARCHAR(20) NOT NULL CHECK (item_type IN ('CHECK', 'DEPOSIT', 'OTHER')),
    reference_number VARCHAR(50),
    amount DECIMAL(15,2) NOT NULL,
    item_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'OUTSTANDING' 
        CHECK (status IN ('OUTSTANDING', 'CLEARED', 'REMOVED')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT 'Bank Reconciliation Tables Loaded Successfully!';
COMMIT;