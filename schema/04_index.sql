-- CREATE OR REPLACE PROCEDURE indexes_at()LANGUAGE plpgsql AS $$
BEGIN;

    CREATE INDEX idx_inventory_product ON Finance.inventoryaudits(productid);
    CREATE INDEX idx_inventory_warehouse ON Finance.inventoryaudits(warehouseid);

    CREATE INDEX idx_transactions_id ON Finance.transactions(transactionid);

    CREATE INDEX idx_journals_transaction ON Finance.journals(transactionid);
    CREATE INDEX idx_journals_chart ON Finance.journals(chartid);

    CREATE INDEX idx_ar_customer ON Finance.accountreceivables(customerid);
    CREATE INDEX idx_ap_supplier ON Finance.accountpayables(supplierid);

    CREATE INDEX idx_inventory_composite 
    ON Finance.inventoryaudits(productid, warehouseid); 

-- END;
-- $$;
-- BEGIN;
-- Call indexes_at();
COMMIT;