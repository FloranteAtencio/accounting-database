BEGIN;
-- ============================================
-- Seperated Functions
-- STEP 1. create function audit log
-- Created functions to seperate from the main trigger function
-- ============================================

CREATE OR REPLACE FUNCTION Finance.create_audit_log(
    p_table_name TEXT,
    p_record_data TEXT,
    p_operation TEXT,
    p_changed_by TEXT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_id INT;
    v_prev_hash TEXT;
BEGIN

    SELECT row_hash
    INTO v_prev_hash
    FROM Finance.audit_logs
    ORDER BY audit_id DESC
    LIMIT 1
    FOR UPDATE;

    INSERT INTO Finance.audit_logs(
        table_name,
        rec_transact,
        operation,
        changed_by,
        prev_hash,
        row_hash
    )
    VALUES (
        p_table_name,
        p_record_data,
        p_operation,
        p_changed_by,
        v_prev_hash,
        md5(
            COALESCE(v_prev_hash,'')
            || p_table_name
            || p_operation
            || p_record_data
        )
    )
    RETURNING audit_id
    INTO v_audit_id;

    RETURN v_audit_id;

END;
$$;

-- ============================================
-- Seperated Functions
-- STEP 2. Create Extended Audit Function
-- Created functions to seperate from the main trigger function
-- ============================================

CREATE OR REPLACE FUNCTION Finance.write_extended_audit(
    p_audit_id INT,
    p_client_id INT,
    p_table_name TEXT,
    p_record_id INT,
    p_operation TEXT,
    p_field_name TEXT,
    p_old_value TEXT,
    p_new_value TEXT,
    p_changed_by TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO Finance.audit_logs_extended(
        audit_id,
        client_id,
        table_name,
        record_id,
        operation,
        field_name,
        old_value,
        new_value,
        changed_by
    )
    VALUES(
        p_audit_id,
        p_client_id,
        p_table_name,
        p_record_id,
        p_operation,
        p_field_name,
        p_old_value,
        p_new_value,
        p_changed_by
    );

END;
$$;

-- ============================================
-- Seperated Functions
-- STEP 3. Create function trigger
-- ============================================

CREATE OR REPLACE FUNCTION Finance.fn_extended_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_client_id INT;
    v_record_text TEXT;
    v_pk_column TEXT;
    v_record_pk INT;
    v_audit_id INT;
    v_changed_by TEXT;
BEGIN

    v_changed_by := CURRENT_USER;
    v_pk_column := TG_ARGV[0];

    IF TG_OP = 'DELETE' THEN
        v_client_id := COALESCE(OLD.client_id,NULL);
        v_record_text := OLD::TEXT;

        EXECUTE format(
            'SELECT ($1).%I',
            v_pk_column
        )
        INTO v_record_pk
        USING OLD;

    ELSE
        v_client_id := COALESCE(NEW.client_id,NULL);
        v_record_text := NEW::TEXT;

        EXECUTE format(
            'SELECT ($1).%I',
            v_pk_column
        )
        INTO v_record_pk
        USING NEW;
    END IF;

    --------------------------------------------------
    -- Create blockchain audit record
    --------------------------------------------------

    v_audit_id :=
        Finance.create_audit_log(
            TG_TABLE_NAME,
            v_record_text,
            TG_OP,
            v_changed_by
        );

    --------------------------------------------------
    -- Store row snapshot
    --------------------------------------------------

    IF TG_OP = 'DELETE' THEN

        PERFORM Finance.write_extended_audit(
            v_audit_id,
            v_client_id,
            TG_TABLE_NAME,
            v_record_pk,
            TG_OP,
            '*ROW*',
            row_to_json(OLD)::TEXT,
            NULL,
            v_changed_by
        );

        RETURN OLD;

    END IF;

    IF TG_OP = 'INSERT' THEN

        PERFORM Finance.write_extended_audit(
            v_audit_id,
            v_client_id,
            TG_TABLE_NAME,
            v_record_pk,
            TG_OP,
            '*ROW*',
            NULL,
            row_to_json(NEW)::TEXT,
            v_changed_by
        );

        RETURN NEW;

    END IF;

    IF TG_OP = 'UPDATE' THEN

    FOR v_field IN
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = TG_TABLE_SCHEMA
          AND table_name = TG_TABLE_NAME
    LOOP

        EXECUTE format(
            'SELECT ($1).%I::TEXT, ($2).%I::TEXT',
            v_field,
            v_field
        )
        INTO v_old_value, v_new_value
        USING OLD, NEW;

        IF v_old_value IS DISTINCT FROM v_new_value THEN

            PERFORM Finance.write_extended_audit(
                v_audit_id,
                v_client_id,
                TG_TABLE_NAME,
                v_record_pk,
                'UPDATE',
                v_field,
                v_old_value,
                v_new_value,
                v_changed_by
            );

        END IF;

    END LOOP;

    RETURN NEW;

END IF;

END;
$$;

-- 1
CREATE TRIGGER audit_transactions
AFTER INSERT OR UPDATE OR DELETE ON Finance.transactions
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(transaction_id);
-- 2
CREATE TRIGGER audit_inventory
AFTER INSERT OR UPDATE OR DELETE ON Finance.inventory_audits
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(management_id)
-- 3
CREATE TRIGGER audit_journals
AFTER INSERT OR UPDATE OR DELETE ON Finance.journals
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(journal_id)
-- 4
CREATE TRIGGER audit_ap
AFTER INSERT OR UPDATE OR DELETE ON Finance.account_payables
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(payable_id);
-- 5
CREATE TRIGGER audit_ar
AFTER INSERT OR UPDATE OR DELETE ON Finance.account_receivables
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(receivable_id);
-- 6
CREATE TRIGGER customer_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.customers 
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(customer_id);
-- 7 
CREATE TRIGGER supplier_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.vendors 
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(vendor_id);
-- 8
CREATE TRIGGER product_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.products 
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(product_id);
-- 9
CREATE TRIGGER inventory_transfers_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.inventory_transfers 
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(transfer_id);
-- 10
CREATE TRIGGER purchase_returns_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.purchase_returns 
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(return_id);
-- 11
CREATE TRIGGER warehouse_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.warehouses 
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(warehouse_id);
-- 12
CREATE TRIGGER sale_returns_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.sale_returns 
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(return_id);
-- 13
CREATE TRIGGER clients_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.clients
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(client_id);
-- 14
CREATE TRIGGER coatemplates_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.coa_templates
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(template_id);
-- 15
CREATE TRIGGER account_roles_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.account_roles
FOR  EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(role_id);
-- 16
CREATE TRIGGER account_properties_changes 
AFTER INSERT OR UPDATE OR DELETE ON Finance.account_properties
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(property_id);
-- 17
CREATE TRIGGER account_receivables_ext_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.ar_ext
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(ar_ext_id);
-- 18
CREATE TRIGGER account_payables_ext_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.ap_ext
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(ap_ext_id);
-- 19
CREATE TRIGGER coa_templates_account_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.coa_template_accounts
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(template_account_Id);
-- 20
CREATE TRIGGER charts_changes
AFTER INSERT OR UPDATE OR DELETE ON Finance.charts
FOR EACH ROW EXECUTE FUNCTION Finance.fn_extended_audit_trigger(chart_id);

COMMIT;