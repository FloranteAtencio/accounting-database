CREATE OR REPLACE PROCEDURE Finance.assign_account_role(
    IN p_account_description TEXT,
    IN p_role_name TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_rows_affected INT;
BEGIN
    -- Insert roles for matching accounts
    INSERT INTO Finance.account_roles (chart_id, role_name)
    SELECT
        chart_id,
        p_role_name
    FROM Finance.charts
    WHERE account LIKE p_account_description || '%'  -- Concatenate % inside string
    ON CONFLICT (chart_id, role_name) DO NOTHING;

    -- Get number of rows affected
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    RAISE NOTICE 'Account description "%" applied to role "%" for % accounts', 
        p_account_description, p_role_name, v_rows_affected;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to apply role: %', SQLERRM;
END;
$$;

-- ====================================================
-- COA TEMPLATE
-- ===================================================
CREATE OR REPLACE PROCEDURE Finance.apply_coa_template(
    IN p_clientId INT,
    IN p_template_id INT
)
LANGUAGE plpgsql AS $$
BEGIN

    PERFORM 1
    FROM Finance.clients
    WHERE client_id = p_clientId
    FOR UPDATE;

    -- Copy template accounts into client's COA
    INSERT INTO Finance.charts (client_id, account, account_code, type, is_active)
    SELECT 
        p_clientId,
        account_name,
        account_code,
        account_type,
        TRUE
    FROM Finance.coa_template_accounts
    WHERE template_id = p_template_id
    ON CONFLICT (client_id, account_code) DO NOTHING;  -- Skip duplicates

    RAISE NOTICE 'Template % applied to client %', p_template_id, p_clientId;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'COA Transaction Failed to apply template: %', SQLERRM;
END;
$$;
