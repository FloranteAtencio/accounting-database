BEGIN;

    CREATE INDEX idx_journals_date ON Finance.journals(Date);

    CREATE INDEX idx_charts_client ON Finance.charts(clientId);
    CREATE INDEX idx_charts_active ON Finance.charts(clientId, is_active);

    CREATE INDEX idx_account_roles_chart ON Finance.account_roles(chartId);
    CREATE INDEX idx_account_roles_name ON Finance.account_roles(role_name);

    CREATE INDEX idx_inventory_product ON Finance.inventoryaudits(productid);
    CREATE INDEX idx_inventory_warehouse ON Finance.inventoryaudits(warehouseid);

    CREATE INDEX idx_transactions_id ON Finance.transactions(transactionid);

    CREATE INDEX idx_journals_transaction ON Finance.journals(transactionid);
    CREATE INDEX idx_journals_chart ON Finance.journals(chartid);

    CREATE INDEX idx_ar_customer ON Finance.accountreceivables(customerid);
    CREATE INDEX idx_ap_supplier ON Finance.accountpayables(supplierid);

    CREATE INDEX idx_inventory_composite 
    ON Finance.inventoryaudits(productid, warehouseid); 

COMMIT;