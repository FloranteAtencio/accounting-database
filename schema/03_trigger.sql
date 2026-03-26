------------------- 2️⃣Now creating a trigger to log changes to the Customers table -----------
CREATE OR REPLACE FUNCTION Finance.log_customers_changes()
RETURNS TRIGGER AS $$
BEGIN

    INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
    VALUES ('Customers', COALESCE(NEW.CustomerID, OLD.CustomerID), TG_OP, current_user);
    RETURN NEW;
    
    EXCEPTION
        WHEN OTHERS THEN        
            RAISE EXCEPTION 'Customers Auditlogs Failed %', SQLERRM;

END;
$$ LANGUAGE plpgsql;
       
CREATE TRIGGER customer_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.customers FOR EACH ROW EXECUTE FUNCTION Finance.log_customers_changes();

CREATE OR REPLACE FUNCTION Finance.log_suppliers_changes()
RETURNS TRIGGER AS $$
BEGIN

    
    INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
    VALUES ('Suppliers', COALESCE(NEW.SupplierID,OLD.SupplierID), TG_OP, current_user);
    RETURN NEW;
    
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Supplier Auditlogs Failed % ', SQLERRM;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER supplier_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.suppliers FOR EACH ROW EXECUTE FUNCTION Finance.log_suppliers_changes();

CREATE OR REPLACE FUNCTION Finance.log_products_changes()
RETURNS TRIGGER AS $$
BEGIN

    
    INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
    VALUES ('Products', COALESCE(NEW.ProductID,OLD.ProductID), TG_OP, current_user);
    RETURN NEW;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Products Auditlog Failed %', SQLERRM;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER product_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.products FOR EACH ROW EXECUTE FUNCTION Finance.log_products_changes();

CREATE OR REPLACE FUNCTION Finance.log_warehouse_changes()
RETURNS TRIGGER AS $$
BEGIN


    INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
    VALUES ('Warehouse', COALESCE(NEW.WarehouseID,OLD.WarehouseID), TG_OP, current_user);
    RETURN NEW;

    EXCEPTION
        WHEN OTHERS THEN            
            RAISE EXCEPTION 'Warehouse Auditlog Failed %', SQLERRM;


END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER warehouse_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.warehouses FOR EACH ROW EXECUTE FUNCTION Finance.log_warehouse_changes();


-- CREATE OR REPLACE FUNCTION Finance.log_InventoryManagement_changes()
-- RETURNS TRIGGER AS $$
-- BEGIN


--     INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
--     VALUES ('InventoryManagement', COALESCE(NEW.ManagementID,OLD.ManagementID), TG_OP, current_user);
--     RETURN NEW;

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Inventory Management Auditlog Failed %', SQLERRM;

-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER inventory_management_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.inventoryaudits FOR EACH ROW EXECUTE FUNCTION Finance.log_InventoryManagement_changes();

-- CREATE OR REPLACE FUNCTION Finance.log_Receivable_changes()
-- RETURNS TRIGGER AS $$
-- BEGIN

--     INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
--     VALUES ('AccountsReceivable', COALESCE(NEW.ReceivableID,OLD.ReceivableID), TG_OP, current_user);
--     RETURN NEW;

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Account Receivable Auditlogs Failed %', SQLERRM;

-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER receivable_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.accountreceivables FOR EACH ROW EXECUTE FUNCTION Finance.log_Receivable_changes();

-- CREATE OR REPLACE FUNCTION Finance.log_Payable_changes()
-- RETURNS TRIGGER AS $$
-- BEGIN

--     INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
--     VALUES ('AccountsPayable', COALESCE(NEW.PayableID,OLD.PayableID), TG_OP, current_user);
--     RETURN NEW;

--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Account Payable Auditlogs Failed %', SQLERRM;

-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER payable_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.accountpayables FOR EACH ROW EXECUTE FUNCTION Finance.log_Payable_changes();

CREATE OR REPLACE FUNCTION Finance.Sale_Returns_Changes()
RETURNS TRIGGER AS $$
BEGIN

    INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
    VALUES ('Sale Returns', COALESCE(NEW.ReturnID,OLD.ReturnID), TG_OP, current_user);
    RETURN NEW;
    
    EXCEPTION
        WHEN OTHERS THEN            
            RAISE EXCEPTION 'Sales Return Auditlogs Failed %', SQLERRM;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sale_returns_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.salereturns FOR EACH ROW EXECUTE FUNCTION Finance.Sale_Returns_Changes();

CREATE OR REPLACE FUNCTION Finance.Purchase_Returns_Changes()
RETURNS TRIGGER AS $$
BEGIN

    INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
    VALUES ('Purchase Returns', COALESCE(NEW.ReturnID, OLD.ReturnID), TG_OP, current_user);
    RETURN NEW;
    
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Purchase Return Auditlogs Failed %', SQLERRM;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER purchase_returns_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.purchasereturns FOR EACH ROW EXECUTE FUNCTION Finance.Purchase_Returns_Changes();

CREATE OR REPLACE FUNCTION Finance.Inventory_Transfers_Changes()
RETURNS TRIGGER AS $$
BEGIN

    INSERT INTO Finance.auditlogs (TableName, RecordedID, Operation, ChangedBy)
    VALUES ('Inventory Transfers', COALESCE(NEW.TransferID,OLD.TransferID), TG_OP, current_user);
    RETURN NEW;
    
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Inventory Transfer Auditlogs Failed %', SQLERRM;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER inventory_transfers_changes AFTER INSERT OR UPDATE OR DELETE ON Finance.inventorytransfers FOR EACH ROW EXECUTE FUNCTION Finance.Inventory_Transfers_Changes();


CREATE OR REPLACE FUNCTION Finance.audit_log_chain()
RETURNS TRIGGER AS $$
DECLARE
    v_prev_hash TEXT;
    v_record_id TEXT;
BEGIN
    v_record_id := COALESCE(NEW::text, OLD::text);

    SELECT row_hash INTO v_prev_hash
    FROM Finance.auditlogs
    ORDER BY AuditID DESC
    LIMIT 1
    FOR UPDATE;

    INSERT INTO Finance.auditlogs (
        TableName,
        RecordedID,
        Operation,
        ChangedBy,
        prev_hash,
        row_hash
    )
    VALUES (
        TG_TABLE_NAME,
        v_record_id,
        TG_OP,
        current_user,
        v_prev_hash,
        md5(
            COALESCE(v_prev_hash, '') ||
            TG_TABLE_NAME ||
            TG_OP ||
            v_record_id
        )
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_transactions
AFTER INSERT OR UPDATE OR DELETE ON Finance.transactions
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER audit_inventory
AFTER INSERT OR UPDATE OR DELETE ON Finance.inventoryaudits
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER audit_journals
AFTER INSERT OR UPDATE OR DELETE ON Finance.journals
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER audit_ap
AFTER INSERT OR UPDATE OR DELETE ON Finance.accountpayables
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER audit_ar
AFTER INSERT OR UPDATE OR DELETE ON Finance.accountreceivables
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();