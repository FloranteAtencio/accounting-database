CREATE OR REPLACE FUNCTION Finance.audit_log_chain()
RETURNS TRIGGER AS $$
DECLARE
    v_prev_hash TEXT;
    v_record_id TEXT;
BEGIN
    v_record_id := COALESCE(NEW::text, OLD::text);

    SELECT row_hash INTO v_prev_hash
    FROM Finance.audit_logs
    ORDER BY audit_id DESC
    LIMIT 1
    FOR UPDATE;

    INSERT INTO Finance.audit_logs (
        table_name,
        rec_transact,
        operation,
        changed_by,
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
-- 1
CREATE TRIGGER audit_transactions
AFTER INSERT OR UPDATE OR DELETE ON Finance.transactions
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 2
CREATE TRIGGER audit_inventory
AFTER INSERT OR UPDATE OR DELETE ON Finance.inventory_audits
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 3
CREATE TRIGGER audit_journals
AFTER INSERT OR UPDATE OR DELETE ON Finance.journals
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 4
CREATE TRIGGER audit_ap
AFTER INSERT OR UPDATE OR DELETE ON Finance.account_payables
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 5
CREATE TRIGGER audit_ar
AFTER INSERT OR UPDATE OR DELETE ON Finance.account_receivables
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 6
CREATE TRIGGER customer_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.customers 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 7 
CREATE TRIGGER supplier_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.vendors 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 8
CREATE TRIGGER product_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.products 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 9
CREATE TRIGGER inventory_transfers_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.inventory_transfers 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 10
CREATE TRIGGER purchase_returns_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.purchase_returns 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 11
CREATE TRIGGER warehouse_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.warehouses 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 12
CREATE TRIGGER sale_returns_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.sale_returns 
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 13
CREATE TRIGGER clients_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.clients
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 14
CREATE TRIGGER coatemplates_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.coa_templates
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 15
CREATE TRIGGER account_roles_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.account_roles
FOR  EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 16
CREATE TRIGGER account_properties_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.account_properties
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 17
CREATE TRIGGER account_receivables_ext_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.ar_ext
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 18
CREATE TRIGGER account_payables_ext_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.ap_ext
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
-- 19
CREATE TRIGGER coa_templates_account_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.coa_template_accounts
FOR EACH ROW EXECUTE FUNCTION Finance.audit_log_chain();
