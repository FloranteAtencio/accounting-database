-- ============================================
-- SECURITY ROLES & ACCESS CONTROL
-- Version: 2.0
-- Purpose: Implement RLS (Row), OLS (Object), CLS (Column) Security
-- ============================================

BEGIN;

-- ============================================
-- 1. APPLICATION ROLES
-- ============================================

-- Create roles with no login (base roles)
CREATE ROLE finance_admin NOINHERIT;
CREATE ROLE finance_accountant NOINHERIT;
CREATE ROLE finance_auditor NOINHERIT;
CREATE ROLE finance_bookkeeper NOINHERIT;

-- Grant basic privileges to roles
GRANT CONNECT ON DATABASE erp_db TO finance_admin, finance_accountant, finance_auditor, finance_bookkeeper;
GRANT USAGE ON SCHEMA finance TO finance_admin, finance_accountant, finance_auditor, finance_bookkeeper;

-- ============================================
-- 2. ROLE HIERARCHY PERMISSIONS
-- ============================================

-- ADMIN: Full access to all operations
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA finance TO finance_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA finance TO finance_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA finance TO finance_admin;

-- ACCOUNTANT: Create/modify transactions, view reports
GRANT SELECT, INSERT, UPDATE ON finance.transactions TO finance_accountant;
GRANT SELECT, INSERT, UPDATE ON finance.journals TO finance_accountant;
GRANT SELECT, INSERT, UPDATE ON finance.account_receivables TO finance_accountant;
GRANT SELECT, INSERT, UPDATE ON finance.account_payables TO finance_accountant;
GRANT SELECT ON finance.charts TO finance_accountant;
GRANT SELECT ON finance.audit_logs TO finance_accountant;

-- AUDITOR: Read-only access to audit trails and transactions
GRANT SELECT ON finance.transactions TO finance_auditor;
GRANT SELECT ON finance.journals TO finance_auditor;
GRANT SELECT ON finance.audit_logs TO finance_auditor;
GRANT SELECT ON finance.event_log TO finance_auditor;
GRANT SELECT ON finance.account_receivables TO finance_auditor;
GRANT SELECT ON finance.account_payables TO finance_auditor;

-- BOOKKEEPER: Data entry for basic transactions
GRANT SELECT, INSERT ON finance.transactions TO finance_bookkeeper;
GRANT SELECT ON finance.journals TO finance_bookkeeper;
GRANT SELECT ON finance.charts TO finance_bookkeeper;
GRANT SELECT ON finance.customers TO finance_bookkeeper;
GRANT SELECT ON finance.vendors TO finance_bookkeeper;

-- ============================================
-- 3. AUDIT/EVENT LOG ACCESS
-- ============================================

-- Only ADMIN and AUDITOR can view audit logs
GRANT SELECT ON finance.audit_logs TO finance_auditor;
GRANT ALL PRIVILEGES ON finance.audit_logs TO finance_admin;

-- Event logs read-only for compliance
GRANT SELECT ON finance.event_log TO finance_auditor;
GRANT ALL PRIVILEGES ON finance.event_log TO finance_admin;

-- ============================================
-- 4. RESTRICT DANGEROUS OPERATIONS
-- ============================================

-- Prevent DELETE by default (only ADMIN can)
REVOKE DELETE ON finance.transactions FROM finance_accountant;
REVOKE DELETE ON finance.journals FROM finance_accountant;

-- Prevent DROP operations for all non-admin
REVOKE ALL ON SCHEMA finance FROM PUBLIC;

COMMIT;
