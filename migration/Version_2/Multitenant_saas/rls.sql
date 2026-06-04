-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Version: 2.0
-- Purpose: Ensure users only see data for their client/organization
-- ============================================

BEGIN;

-- ============================================
-- PREREQUISITE: Enable RLS on tables
-- ============================================

ALTER TABLE finance.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.charts ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.journals ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.account_receivables ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.account_payables ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.ar_ext ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.ap_ext ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance.inventory_audits ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 1. HELPER FUNCTION: Get current client_id
-- ============================================

CREATE OR REPLACE FUNCTION finance.get_current_client_id()
RETURNS INT AS $$
BEGIN
    RETURN COALESCE(
        (current_setting('app.current_client_id', true))::INT,
        1  -- Default to client 1 if not set
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 2. CLIENT TABLE RLS
-- ============================================

-- Clients can only see their own record
CREATE POLICY clients_select_own ON finance.clients
    FOR SELECT
    USING (client_id = finance.get_current_client_id());

CREATE POLICY clients_update_own ON finance.clients
    FOR UPDATE
    USING (client_id = finance.get_current_client_id())
    WITH CHECK (client_id = finance.get_current_client_id());

-- ============================================
-- 3. CHART OF ACCOUNTS RLS
-- ============================================

-- Users see only charts for their assigned client
CREATE POLICY charts_select_by_client ON finance.charts
    FOR SELECT
    USING (client_id = finance.get_current_client_id());

CREATE POLICY charts_insert_for_client ON finance.charts
    FOR INSERT
    WITH CHECK (client_id = finance.get_current_client_id());

CREATE POLICY charts_update_own_client ON finance.charts
    FOR UPDATE
    USING (client_id = finance.get_current_client_id())
    WITH CHECK (client_id = finance.get_current_client_id());

-- ============================================
-- 4. TRANSACTIONS RLS
-- ============================================

-- Transactions filtered by client
CREATE POLICY transactions_select_by_client ON finance.transactions
    FOR SELECT
    USING (client_id = finance.get_current_client_id());

CREATE POLICY transactions_insert_for_client ON finance.transactions
    FOR INSERT
    WITH CHECK (client_id = finance.get_current_client_id());

CREATE POLICY transactions_update_own_client ON finance.transactions
    FOR UPDATE
    USING (client_id = finance.get_current_client_id())
    WITH CHECK (client_id = finance.get_current_client_id());

-- ============================================
-- 5. JOURNALS RLS (via transaction.client_id)
-- ============================================

-- Journals visible only if related transaction belongs to user's client
CREATE POLICY journals_select_by_client ON finance.journals
    FOR SELECT
    USING (
        transaction_id IN (
            SELECT transaction_id 
            FROM finance.transactions 
            WHERE client_id = finance.get_current_client_id()
        )
    );

CREATE POLICY journals_insert_for_client ON finance.journals
    FOR INSERT
    WITH CHECK (
        transaction_id IN (
            SELECT transaction_id 
            FROM finance.transactions 
            WHERE client_id = finance.get_current_client_id()
        )
    );

-- ============================================
-- 6. ACCOUNTS RECEIVABLE RLS
-- ============================================

CREATE POLICY ar_select_by_client ON finance.account_receivables
    FOR SELECT
    USING (
        transaction_id IN (
            SELECT transaction_id 
            FROM finance.transactions 
            WHERE client_id = finance.get_current_client_id()
        )
    );

CREATE POLICY ar_insert_for_client ON finance.account_receivables
    FOR INSERT
    WITH CHECK (
        transaction_id IN (
            SELECT transaction_id 
            FROM finance.transactions 
            WHERE client_id = finance.get_current_client_id()
        )
    );

-- ============================================
-- 7. ACCOUNTS PAYABLE RLS
-- ============================================

CREATE POLICY ap_select_by_client ON finance.account_payables
    FOR SELECT
    USING (
        transaction_id IN (
            SELECT transaction_id 
            FROM finance.transactions 
            WHERE client_id = finance.get_current_client_id()
        )
    );

CREATE POLICY ap_insert_for_client ON finance.account_payables
    FOR INSERT
    WITH CHECK (
        transaction_id IN (
            SELECT transaction_id 
            FROM finance.transactions 
            WHERE client_id = finance.get_current_client_id()
        )
    );

-- ============================================
-- 8. AR/AP EXTENSIONS RLS
-- ============================================

CREATE POLICY ar_ext_select_by_client ON finance.ar_ext
    FOR SELECT
    USING (
        receivable_id IN (
            SELECT ar.receivable_id 
            FROM finance.account_receivables ar
            WHERE ar.transaction_id IN (
                SELECT transaction_id 
                FROM finance.transactions 
                WHERE client_id = finance.get_current_client_id()
            )
        )
    );

CREATE POLICY ap_ext_select_by_client ON finance.ap_ext
    FOR SELECT
    USING (
        payable_id IN (
            SELECT ap.payable_id 
            FROM finance.account_payables ap
            WHERE ap.transaction_id IN (
                SELECT transaction_id 
                FROM finance.transactions 
                WHERE client_id = finance.get_current_client_id()
            )
        )
    );

-- ============================================
-- 9. CUSTOMERS RLS
-- ============================================

-- Assuming customers have client relationship
-- If not, add client_id column to customers table
CREATE POLICY customers_select_any ON finance.customers
    FOR SELECT
    USING (true);  -- Adjust based on your customer model

-- ============================================
-- 10. VENDORS/SUPPLIERS RLS
-- ============================================

CREATE POLICY vendors_select_any ON finance.vendors
    FOR SELECT
    USING (true);  -- Adjust based on your vendor model

-- ============================================
-- 11. INVENTORY AUDITS RLS
-- ============================================

CREATE POLICY inventory_audits_select_by_client ON finance.inventory_audits
    FOR SELECT
    USING (
        transaction_id IN (
            SELECT transaction_id 
            FROM finance.transactions 
            WHERE client_id = finance.get_current_client_id()
        )
    );

-- ============================================
-- ENABLE RLS ENFORCEMENT
-- ============================================

ALTER TABLE finance.audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_logs_select_auditors ON finance.audit_logs
    FOR SELECT
    USING (true);  -- Auditors can see all audit logs

COMMIT;

-- ============================================
-- USAGE EXAMPLES
-- ============================================

-- To set client context before queries:
-- SET app.current_client_id = '1';
-- SELECT * FROM finance.transactions;  -- Only returns transactions for client 1

-- To reset:
-- RESET app.current_client_id;
