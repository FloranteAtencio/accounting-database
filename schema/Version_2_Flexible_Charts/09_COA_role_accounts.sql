CREATE OR REPLACE PROCEDURE Finance.assign_account_role(
    IN p_account_description TEXT,
    IN p_role_name TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_rows_affected INT;
BEGIN
    -- Insert roles for matching accounts
    INSERT INTO Finance.accountroles (chartId, roleName)
    SELECT
        chartId,
        p_role_name
    FROM Finance.charts
    WHERE account LIKE p_account_description || '%'  -- Concatenate % inside string
    ON CONFLICT (chartId, rolename) DO NOTHING;

    -- Get number of rows affected
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    RAISE NOTICE 'Account description "%" applied to role "%" for % accounts', 
        p_account_description, p_role_name, v_rows_affected;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to apply role: %', SQLERRM;
END;
$$;

