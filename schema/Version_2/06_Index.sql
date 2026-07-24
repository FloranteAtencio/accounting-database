
-- Verification
SELECT '04. Index ADD PERFORMANCE INDEXES' AS status;

BEGIN;
    -- ============================================
    -- 04. Index ADD PERFORMANCE INDEXES
    -- ============================================
    CREATE INDEX IF NOT EXISTS idx_journals_date ON Finance.journals(date);

    CREATE INDEX IF NOT EXISTS idx_charts_client ON Finance.charts(client_id);
    CREATE INDEX IF NOT EXISTS idx_charts_active ON Finance.charts(client_id, is_active);

    CREATE INDEX IF NOT EXISTS idx_account_roles_chart ON Finance.account_roles(chart_id);
    CREATE INDEX IF NOT EXISTS idx_account_roles_name ON Finance.account_roles(role_name);

    CREATE INDEX IF NOT EXISTS idx_inventory_product ON Finance.inventory_audits(product_id);
    CREATE INDEX IF NOT EXISTS idx_inventory_warehouse ON Finance.inventory_audits(warehouse_id);

    CREATE INDEX IF NOT EXISTS idx_transactions_id ON Finance.transactions(transaction_id);

    CREATE INDEX IF NOT EXISTS idx_journals_transaction ON Finance.journals(transaction_id);
    CREATE INDEX IF NOT EXISTS idx_journals_chart ON Finance.journals(chart_id);

    CREATE INDEX IF NOT EXISTS idx_ar_customer ON Finance.account_receivables(customer_id);
    CREATE INDEX IF NOT EXISTS idx_ap_supplier ON Finance.account_payables(vendor_id);

    CREATE INDEX IF NOT EXISTS idx_inventory_composite ON Finance.inventory_audits(product_id, warehouse_id); 

    -- Transactions indexes
    CREATE INDEX IF NOT EXISTS idx_transactions_client_id ON Finance.transactions(client_id);
    CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON Finance.transactions(created_at);
    CREATE INDEX IF NOT EXISTS idx_transactions_idempotency ON Finance.transactions(idempotency_key);

    -- Journals indexes
    CREATE INDEX IF NOT EXISTS idx_journals_date ON Finance.journals(date);
    CREATE INDEX IF NOT EXISTS idx_journals_transaction_id ON Finance.journals(transaction_id);
    CREATE INDEX IF NOT EXISTS idx_journals_chart_id ON Finance.journals(chart_id);

    -- AR/AP indexes
    CREATE INDEX IF NOT EXISTS idx_ar_ext_due_date ON Finance.ar_ext(due_date);
    CREATE INDEX IF NOT EXISTS idx_ar_ext_status ON Finance.ar_ext(status);
    CREATE INDEX IF NOT EXISTS idx_ap_ext_due_date ON Finance.ap_ext(due_date);
    CREATE INDEX IF NOT EXISTS idx_ap_ext_status ON Finance.ap_ext(status);

    -- Inventory indexes
    CREATE INDEX IF NOT EXISTS idx_inventory_audits_date ON Finance.inventory_audits(movement_date);
    CREATE INDEX IF NOT EXISTS idx_inventory_audits_product ON Finance.inventory_audits(product_id);
    CREATE INDEX IF NOT EXISTS idx_inventory_audits_warehouse ON Finance.inventory_audits(warehouse_id);

    -- Audit indexes
    CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON Finance.audit_logs(log_time);
    CREATE INDEX IF NOT EXISTS idx_audit_logs_table ON Finance.audit_logs(table_name);
    CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON Finance.audit_logs(changed_by);

    -- Event log indexes
    CREATE INDEX IF NOT EXISTS idx_event_log_type ON Finance.event_log(event_type);
    CREATE INDEX IF NOT EXISTS idx_event_log_status ON Finance.event_log(status);
    CREATE INDEX IF NOT EXISTS idx_event_log_created ON Finance.event_log(created_at);

COMMIT;

SELECT 'Indexes Successfully Applied' AS status;