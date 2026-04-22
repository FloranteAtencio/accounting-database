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

