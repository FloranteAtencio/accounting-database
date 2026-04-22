BEGIN;

    CREATE INDEX idx_journals_date ON Finance.journals(date);

    CREATE INDEX idx_charts_client ON Finance.charts(clientId);
    CREATE INDEX idx_charts_active ON Finance.charts(clientId, is_active);

    CREATE INDEX idx_account_roles_chart ON Finance.account_roles(chartId);
    CREATE INDEX idx_account_roles_name ON Finance.accountroles(roleName);

    CREATE INDEX idx_inventory_product ON Finance.inventory_audits(productId);
    CREATE INDEX idx_inventory_warehouse ON Finance.inventory_audits(warehouseId);

    CREATE INDEX idx_transactions_id ON Finance.transactions(transactionId);

    CREATE INDEX idx_journals_transaction ON Finance.journals(transactionId);
    CREATE INDEX idx_journals_chart ON Finance.journals(chartId);

    CREATE INDEX idx_ar_customer ON Finance.account_receivables(customerId);
    CREATE INDEX idx_ap_supplier ON Finance.account_payables(supplierId);

    CREATE INDEX idx_inventory_composite 
    ON Finance.inventory_audits(productid, warehouseid); 

COMMIT;
