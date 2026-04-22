BEGIN;

    CREATE INDEX idx_journals_date ON Finance.journals(date);

    CREATE INDEX idx_charts_client ON Finance.charts(client_id);
    CREATE INDEX idx_charts_active ON Finance.charts(client_id, is_active);

    CREATE INDEX idx_account_roles_chart ON Finance.account_roles(chart_id);
    CREATE INDEX idx_account_roles_name ON Finance.accountroles(role_name);

    CREATE INDEX idx_inventory_product ON Finance.inventory_audits(product_id);
    CREATE INDEX idx_inventory_warehouse ON Finance.inventory_audits(warehouse_id);

    CREATE INDEX idx_transactions_id ON Finance.transactions(transaction_id);

    CREATE INDEX idx_journals_transaction ON Finance.journals(transaction_id);
    CREATE INDEX idx_journals_chart ON Finance.journals(chart_id);

    CREATE INDEX idx_ar_customer ON Finance.account_receivables(customer_id);
    CREATE INDEX idx_ap_supplier ON Finance.account_payables(supplier_id);

    CREATE INDEX idx_inventory_composite 
    ON Finance.inventory_audits(product_id, warehouse_id); 

COMMIT;
