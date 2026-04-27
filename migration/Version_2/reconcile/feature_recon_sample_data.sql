BEGIN;

SELECT 'Loading Bank Reconciliation Sample Data...';

-- ============================================
-- 1. BANK ACCOUNTS
-- ============================================
INSERT INTO Finance.bank_accounts 
    (client_id, chart_id, account_number, bank_name, account_type, currency, is_active)
VALUES
(1, 1, '1234567890', 'BDO Bank', 'Checking', 'PHP', TRUE),
(1, 1, '0987654321', 'BPI Bank', 'Savings', 'PHP', TRUE);

-- ============================================
-- 2. BANK STATEMENTS
-- ============================================
INSERT INTO Finance.bank_statements 
    (account_id, statement_date, opening_balance, closing_balance, statement_period_start, statement_period_end, uploaded_at)
VALUES
(1, '2025-01-31'::DATE, 100000.00, 156500.00, '2025-01-01'::DATE, '2025-01-31'::DATE, CURRENT_TIMESTAMP),
(1, '2025-02-28'::DATE, 156500.00, 185750.00, '2025-02-01'::DATE, '2025-02-28'::DATE, CURRENT_TIMESTAMP);

-- ============================================
-- 3. BANK TRANSACTIONS (From bank statement)
-- ============================================
INSERT INTO Finance.bank_transactions 
    (statement_id, transaction_date, description, amount, transaction_type, reference_number)
VALUES
-- January Statement Transactions
(1, '2025-01-02'::DATE, 'Customer Payment A', 50000.00, 'CREDIT', 'DEP-001'),
(1, '2025-01-05'::DATE, 'Customer Payment B', 25000.00, 'CREDIT', 'DEP-002'),
(1, '2025-01-08'::DATE, 'Supplier Invoice X', 10000.00, 'DEBIT', 'CHK-001'),
(1, '2025-01-12'::DATE, 'Supplier Invoice Y', 5000.00, 'DEBIT', 'CHK-002'),
(1, '2025-01-15'::DATE, 'Payroll Expense', 15500.00, 'DEBIT', 'CHK-003'),
(1, '2025-01-20'::DATE, 'Miscellaneous', 1000.00, 'DEBIT', 'CHK-004');

-- ============================================
-- 4. RECONCILIATION RECORDS
-- ============================================
INSERT INTO Finance.bank_reconciliations 
    (account_id, reconciliation_date, statement_balance, book_balance, difference, status)
VALUES
(1, '2025-01-31'::DATE, 156500.00, 156000.00, 500.00, 'VARIANCE');

SELECT 'Bank Reconciliation Sample Data Loaded Successfully!';
COMMIT;