BEGIN;

    CREATE INDEX idx_journals_date ON Finance.journals(date);

    CREATE INDEX idx_charts_client ON Finance.charts(clientId);
    CREATE INDEX idx_charts_active ON Finance.charts(clientId, is_active);

    CREATE INDEX idx_account_roles_chart ON Finance.accountroles(chartId);
    CREATE INDEX idx_account_roles_name ON Finance.accountroles(roleName);

    CREATE INDEX idx_inventory_product ON Finance.inventoryaudits(productId);
    CREATE INDEX idx_inventory_warehouse ON Finance.inventoryaudits(warehouseId);

    CREATE INDEX idx_transactions_id ON Finance.transactions(transactionId);

    CREATE INDEX idx_journals_transaction ON Finance.journals(transactionId);
    CREATE INDEX idx_journals_chart ON Finance.journals(chartId);

    CREATE INDEX idx_ar_customer ON Finance.accountreceivables(customerId);
    CREATE INDEX idx_ap_supplier ON Finance.accountpayables(supplierId);

    CREATE INDEX idx_inventory_composite 
    ON Finance.inventoryaudits(productid, warehouseid); 

COMMIT;
