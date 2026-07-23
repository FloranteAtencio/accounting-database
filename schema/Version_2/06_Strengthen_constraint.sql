-- ============================================
-- 09_STRENGTHEN_CONSTRAINTS.SQL
-- Purpose: Add domain types, constraints, and indexes
-- to prevent bad data and ensure referential integrity
-- ============================================

BEGIN;

-- ============================================
-- 1. DOMAIN TYPES (Reusable Validation)
-- ============================================

-- -- Email domain
-- DROP DOMAIN IF EXISTS email_type CASCADE;
-- CREATE DOMAIN email_type AS VARCHAR(255)
--     CONSTRAINT valid_email CHECK (VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$');

-- -- Phone domain
-- DROP DOMAIN IF EXISTS phone_type CASCADE;
-- CREATE DOMAIN phone_type AS VARCHAR(20)
--     CONSTRAINT valid_phone CHECK (VALUE ~ '^\+?1?\d{9,15}$' OR VALUE = '');

-- -- Amount domain (non-negative)
-- DROP DOMAIN IF EXISTS amount_type CASCADE;
-- CREATE DOMAIN amount_type AS DECIMAL(15,2)
--     CONSTRAINT positive_amount CHECK (VALUE >= 0);

-- -- Quantity domain (positive integer)
-- DROP DOMAIN IF EXISTS quantity_type CASCADE;
-- CREATE DOMAIN quantity_type AS INT
--     CONSTRAINT positive_quantity CHECK (VALUE > 0);

-- -- Account code domain
-- DROP DOMAIN IF EXISTS account_code_type CASCADE;
-- CREATE DOMAIN account_code_type AS INT
--     CONSTRAINT valid_account_code CHECK (VALUE > 0);

-- ============================================
-- 2. STRENGTHEN EXISTING TABLES
-- ============================================

-- Clients table
ALTER TABLE Finance.clients
    ALTER COLUMN info SET NOT NULL;

-- Chart of Accounts
ALTER TABLE Finance.charts
    ADD CONSTRAINT unique_client_account_code UNIQUE (client_id, account_code),
    ALTER COLUMN account SET NOT NULL,
    ALTER COLUMN account_code SET NOT NULL,
    ALTER COLUMN type SET NOT NULL,
    ALTER COLUMN is_active SET DEFAULT TRUE;

-- Transactions
ALTER TABLE Finance.transactions
    ADD CONSTRAINT unique_idempotency_key UNIQUE (idempotency_key),
    ALTER COLUMN description SET NOT NULL,
    ALTER COLUMN idempotency_key SET NOT NULL;

-- Journals
ALTER TABLE Finance.journals
    ALTER COLUMN date SET NOT NULL,
    ALTER COLUMN amount SET NOT NULL,
    ADD CONSTRAINT positive_journal_amount CHECK (amount >= 0);

-- Customers
ALTER TABLE Finance.customers
    ALTER COLUMN customer_name SET NOT NULL,
    ALTER COLUMN contact_info SET NOT NULL,
    ALTER COLUMN email SET NOT NULL,
    ALTER COLUMN address SET NOT NULL;

-- Vendors
ALTER TABLE Finance.vendors
    ALTER COLUMN vendor_name SET NOT NULL,
    ALTER COLUMN contact_info SET NOT NULL,
    ALTER COLUMN email SET NOT NULL,
    ALTER COLUMN address SET NOT NULL;

-- Products
ALTER TABLE Finance.products
    ALTER COLUMN product_name SET NOT NULL,
    ALTER COLUMN product_unit SET NOT NULL;

-- Operations
ALTER TABLE Finance.operations
    ALTER COLUMN quantity SET NOT NULL,
    ALTER COLUMN product_cost SET NOT NULL,
    ALTER COLUMN product_price SET NOT NULL,
    ALTER COLUMN purchase_date SET NOT NULL,
    ADD CONSTRAINT positive_operation_cost CHECK (product_cost >= 0),
    ADD CONSTRAINT positive_operation_price CHECK (product_price >= 0);

-- Warehouses
ALTER TABLE Finance.warehouses
    ALTER COLUMN warehouse_name SET NOT NULL,
    ALTER COLUMN location SET NOT NULL;

-- Account Receivables
ALTER TABLE Finance.account_receivables
    ALTER COLUMN transaction_id SET NOT NULL,
    ALTER COLUMN customer_id SET NOT NULL;

-- AR Extension
ALTER TABLE Finance.ar_ext
    ALTER COLUMN amount SET NOT NULL,
    ALTER COLUMN due_date SET NOT NULL,
    ALTER COLUMN invoice_date SET NOT NULL,
    ALTER COLUMN status SET NOT NULL,
    ADD CONSTRAINT positive_ar_amount CHECK (amount >= 0),
    ADD CONSTRAINT valid_ar_dates CHECK (invoice_date <= due_date);

-- Account Payables
ALTER TABLE Finance.account_payables
    ALTER COLUMN transaction_id SET NOT NULL,
    ALTER COLUMN vendor_id SET NOT NULL;

-- AP Extension
ALTER TABLE Finance.ap_ext
    ALTER COLUMN amount SET NOT NULL,
    ALTER COLUMN due_date SET NOT NULL,
    ALTER COLUMN invoice_date SET NOT NULL,
    ALTER COLUMN status SET NOT NULL,
    ADD CONSTRAINT positive_ap_amount CHECK (amount >= 0),
    ADD CONSTRAINT valid_ap_dates CHECK (invoice_date <= due_date);

-- Inventory Audits
ALTER TABLE Finance.inventory_audits
    ALTER COLUMN product_id SET NOT NULL,
    ALTER COLUMN warehouse_id SET NOT NULL,
    ALTER COLUMN transaction_id SET NOT NULL,
    ALTER COLUMN action_type SET NOT NULL,
    ALTER COLUMN quantity SET NOT NULL,
    ALTER COLUMN movement_date SET NOT NULL,
    ADD CONSTRAINT valid_action_type CHECK (action_type IN ('Purchase', 'Sale', 'Sale Return', 'Purchase Return', 'Transfer'));

-- Purchase Returns
ALTER TABLE Finance.purchase_returns
    ALTER COLUMN payable_id SET NOT NULL,
    ALTER COLUMN return_amount SET NOT NULL,
    ALTER COLUMN return_date SET NOT NULL;

-- Sale Returns
ALTER TABLE Finance.sale_returns
    ALTER COLUMN receivable_id SET NOT NULL,
    ALTER COLUMN return_amount SET NOT NULL,
    ALTER COLUMN return_date SET NOT NULL;

-- Inventory Transfers
ALTER TABLE Finance.inventory_transfers
    ALTER COLUMN from_location_id SET NOT NULL,
    ALTER COLUMN to_location_id SET NOT NULL,
    ALTER COLUMN product_id SET NOT NULL,
    ALTER COLUMN quantity SET NOT NULL,
    ALTER COLUMN transfer_date SET NOT NULL,
    ADD CONSTRAINT different_locations CHECK (from_location_id != to_location_id);

-- Audit Logs
ALTER TABLE Finance.audit_logs
    ALTER COLUMN table_name SET NOT NULL,
    ALTER COLUMN rec_transact SET NOT NULL,
    ALTER COLUMN operation SET NOT NULL,
    ALTER COLUMN changed_by SET NOT NULL;

-- Event Log
ALTER TABLE Finance.event_log
    ALTER COLUMN event_type SET NOT NULL,
    ALTER COLUMN payload SET NOT NULL,
    ALTER COLUMN idempotency_key SET NOT NULL;

    ALTER TABLE Finance.charts 
    ADD CONSTRAINT charts_chk_type CHECK (Type IN ('Asset', 'Liability', 'Equity', 'Revenue', 'Expense','Contra Revenue','Contra Asset','Contra Liability','Contra Equity','Contra Expense'));

    ALTER TABLE Finance.inventory_audits 
    ADD CONSTRAINT inventoryaudits_chk_actiontype CHECK (Action_type IN ('Purchase', 'Sale', 'Sale Return', 'Purchase Return', 'Transfer'));

    ALTER TABLE Finance.ap_ext 
    ADD CONSTRAINT accountpayable_chk_status CHECK (Status IN ('Pending', 'Paid', 'Overdue','Returned','Partially Returned','Partially Paid'));

    ALTER TABLE Finance.ar_ext
    ADD CONSTRAINT accountreceivables_chk_status CHECK (Status IN ('Pending', 'Paid', 'Overdue','Returned','Partially Returned','Partially Paid'));

    ALTER TABLE Finance.audit_logs 
    ADD CONSTRAINT auditlogs_chk_status CHECK (Operation IN ('INSERT', 'UPDATE', 'DELETE'));

    ALTER TABLE Finance.vendors
    ADD CONSTRAINT chk_valid_email_supplier CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

    ALTER TABLE Finance.customers
    ADD CONSTRAINT chk_valid_email_customers CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');


-- -- ============================================
-- -- 3. ADD PERFORMANCE INDEXES
-- -- ============================================

-- -- Transactions indexes
-- CREATE INDEX IF NOT EXISTS idx_transactions_client_id ON Finance.transactions(client_id);
-- CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON Finance.transactions(created_at);
-- CREATE INDEX IF NOT EXISTS idx_transactions_idempotency ON Finance.transactions(idempotency_key);

-- -- Journals indexes
-- CREATE INDEX IF NOT EXISTS idx_journals_date ON Finance.journals(date);
-- CREATE INDEX IF NOT EXISTS idx_journals_transaction_id ON Finance.journals(transaction_id);
-- CREATE INDEX IF NOT EXISTS idx_journals_chart_id ON Finance.journals(chart_id);

-- -- AR/AP indexes
-- CREATE INDEX IF NOT EXISTS idx_ar_ext_due_date ON Finance.ar_ext(due_date);
-- CREATE INDEX IF NOT EXISTS idx_ar_ext_status ON Finance.ar_ext(status);
-- CREATE INDEX IF NOT EXISTS idx_ap_ext_due_date ON Finance.ap_ext(due_date);
-- CREATE INDEX IF NOT EXISTS idx_ap_ext_status ON Finance.ap_ext(status);

-- -- Inventory indexes
-- CREATE INDEX IF NOT EXISTS idx_inventory_audits_date ON Finance.inventory_audits(movement_date);
-- CREATE INDEX IF NOT EXISTS idx_inventory_audits_product ON Finance.inventory_audits(product_id);
-- CREATE INDEX IF NOT EXISTS idx_inventory_audits_warehouse ON Finance.inventory_audits(warehouse_id);

-- -- Audit indexes
-- CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON Finance.audit_logs(log_time);
-- CREATE INDEX IF NOT EXISTS idx_audit_logs_table ON Finance.audit_logs(table_name);
-- CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON Finance.audit_logs(changed_by);

-- -- Event log indexes
-- CREATE INDEX IF NOT EXISTS idx_event_log_type ON Finance.event_log(event_type);
-- CREATE INDEX IF NOT EXISTS idx_event_log_status ON Finance.event_log(status);
-- CREATE INDEX IF NOT EXISTS idx_event_log_created ON Finance.event_log(created_at);

COMMIT;

-- Verification
SELECT 'Constraints and Indexes Successfully Applied' AS status;