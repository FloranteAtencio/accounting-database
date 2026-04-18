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
        RecTransact,
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

CREATE TRIGGER customer_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.customers 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER supplier_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.suppliers 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER product_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.products 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER inventory_transfers_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.inventorytransfers 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER purchase_returns_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.purchasereturns 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER warehouse_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.warehouses 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER sale_returns_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.salereturns 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER clients_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.clients
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER coatemplates_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.coatemplates
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER account_roles_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.accountroles
FOR  EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();

CREATE TRIGGER account_properties_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.accountproperties
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
