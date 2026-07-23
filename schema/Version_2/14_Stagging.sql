-- =======================================================================
-- 14. STAGING SHCEMA PART 
-- this stagging schema is for validation, sanitation and approval matters!
-- ====================================================================

SELECT '14. StagGing schema Start' as  Status;

BEGIN;

CREATE SCHEMA Staging;

-- 1. STAGING TABLE
CREATE TABLE IF NOT EXISTS Staging.stg_ar_imports(
    id BIGSERIAL PRIMARY KEY,
    session_id INT,
    customer_code TEXT,
    client_code TEXT,
    amount TEXT,
    invoice_date TEXT,
    due_date TEXT,
    status TEXT,
    validation_status VARCHAR(20),
    validations_error TEXT,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. WORKFLOW TABLE
CREATE TABLE IF NOT EXISTS Staging.import_workflows (
    session_id INT,
    staging_record_id BIGINT,
    staging_table VARCHAR(50),
    previous_state VARCHAR(50),
    new_state VARCHAR(50),
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 3. APPROVAL TABLE
CREATE TABLE Staging.import_approvals (
    session_id INT,
    staging_record_id BIGINT,   

    approval_level SMALLINT,
    approval_status VARCHAR(20),

    approved_by VARCHAR(100),
    approved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    comments TEXT
);


DROP FUNCTION IF EXISTS Staging.ar_import_data(INT,INT,DATE,DATE,DECIMAL) CASCADE;
CREATE FUNCTION Staging.ar_import_data(
    p_session_id INT,
    p_client_id INT,
    p_customer_id INT,
    p_invoice_date DATE,
    p_due_date DATE,
    p_amount DECIMAL(12,2)

)
RETURNS INT AS $$
DECLARE
    new_ar_staging_id INT;
BEGIN
    INSERT INTO Staging.stg_ar_imports( 
        session_id, 
        client_code,
        customer_code, 
        invoice_date, 
        due_date, 
        amount, 
        validation_status, 
        validation_errors, 
        imported_at) 
    VALUES ( p_session_id, p_client_id, p_customer_id, p_due_date, p_invoice_date, 'DRAFT', NULL, NOW())
    RETURNING ar_staging_id INTO new_ar_staging_id;

    INSERT INTO Staging.import_workflows
    (session_id, staging_record_id, staging_table,previous_state, new_state, change_by)
    VALUES(p_session_id, new_ar_staging_id, 'Staging.ar_import_data', 'DRAFT', NULL, current_user);

    RETURN new_ar_staging_id;
END; 
$$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE Staging.import_workflow_sanitation(
    IN p_session_id INT,
    IN table_related TEXT
)
LANGUAGE plpgsql as $$
DECLARE
    
    new_session_id INT;

BEGIN
    SELECT session_id INTO new_session_id
    FROM Finance.import_sessions a
    WHERE a.session_id = p_session_id
    LIMIT 1;
    -- IMPORTANT: Validate table name first to prevent SQL injection
    -- If table_related comes from user input, check it against a whitelist
    IF table_related NOT IN ('stg_ar_imports', 'stg_other_table') THEN
        RAISE EXCEPTION 'Invalid table name: %', table_related;
    END IF;

    IF new_session_id IS NULL THEN
        RAISE EXCEPTION 'invalid Session ID : %', new_session_id;
    END IF;

    PERFORM 1 FROM Finance.import_sessions a where a.session_id = p_session_id;
    
    EXECUTE format(
        $fmt$
        UPDATE Staging.%I s
        SET 
            validation_status = CASE 
                WHEN b.customer_id IS NULL THEN ''INVALID''
                WHEN c.client_id IS NULL THEN ''INVALID''
                WHEN s.amount !~ ''^[0-9.]+$'' THEN ''INVALID''
                WHEN s.invoice_date !~ ''^\d{{4}}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$'' THEN ''INVALID''  
                WHEN s.due_date !~ ''^\d{{4}}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$'' THEN ''INVALID''  
                ELSE ''VALID''
            END,
            validation_error = CASE 
                WHEN b.customer_id IS NULL THEN ''Customer not found''
                WHEN c.client_id IS NULL THEN ''Client not found''
                WHEN s.amount !~ ''^[0-9.]+$'' THEN ''Invalid amount format''
                WHEN s.invoice_date !~ ''^\d{{4}}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$'' THEN ''Invalid Date''  
                WHEN s.due_date !~ ''^\d{{4}}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$'' THEN ''Invalid Date''
                ELSE NULL
            END
        FROM Finance.clients c
        JOIN Finance.customers b ON b.customer_code = s.customer_code 
        WHERE s.client_code = c.client_id
        AND s.session_id = %s
        AND s.validation_status = ''DRAFT'' 
        $fmt$,
        table_related,  -- %I: Table name (Identifier)
        p_session_id    -- %s: Session ID (Value)
        );

        EXECUTE format(
            $fmt$
            UPDATE Staging.import_workflows a
            SET
                new_state = ''PENDING'',
                previous_state = ''DRAFT'',
                notes = ''PENDING FOR VALIDATION''
            FROM Staging.%I b
            WHERE a.staging_record_id = b.id 
            AND a.session_id = b.session_id
            AND b.validation_status = ''VALID''
            $fmt$, 
            table_related);

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Staging import sanitation failed: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE Staging.import_workflow_validation(
    IN p_session_id INT,
    IN table_related VARCHAR(50)
)
LANGUAGE plpgsql as $$
DECLARE
    new_session_id INT;
BEGIN

    SELECT session_id INTO new_session_id
    FROM Finance.import_sessions a
    WHERE a.session_id = p_session_id
    LIMIT 1;

    IF table_related NOT IN ('stg_ar_imports', 'stg_other_table') THEN
        RAISE EXCEPTION 'Invalid table name: %', table_related;
    END IF;

    IF new_session_id IS NULL THEN
        RAISE EXCEPTION 'invalid Session ID : %', new_session_id;
    END IF;

    PERFORM 1 FROM Finance.import_sessions WHERE session_id = p_session_id;

    EXECUTE format(
        $fmt$
        UPDATE Staging.import_workflows a
        SET
            new_state = ''VALID'',
            previous_state = ''PENDING'',
            notes = ''PENDING FOR APPROVAL''
        FROM Staging.%I b
        WHERE a.staging_record_id = b.id 
        AND a.session_id = b.session_id
        AND b.validation_status = ''VALID''
        $fmt$,
        , table_related);

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Staging import workflow validation failed: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE Staging.import_workflow_approval(
    IN p_session_id INT,
    IN p_level SMALLINT,
    IN p_status  VARCHAR(20),
    IN p_approve_by VARCHAR(20),
    IN p_approve_state VARCHAR(20)
)
LANGUAGE plpgsql as $$
DECLARE
    new_session_id INT;
    new_previous_state VARCHAR(50);
BEGIN

    SELECT session_id INTO new_session_id
    FROM Finance.import_sessions a
    WHERE a.session_id = p_session_id
    LIMIT 1;

    SELECT new_state INTO new_previous_state
    FROM Staging.import_workflow a
    WHERE a.session_id = p_session_id
    LIMIT 1;
    
    IF new_session_id IS NULL THEN
        RAISE EXCEPTION 'Please Check Session_id provided!';
    END IF;

    IF p_approve_state NOT IN ('APPROVE_L1','APPROVE_L2','APPROVE_L3') THEN
        RAISE EXCEPTION 'Please Check approve state: APPROVE_L1, APPROVE_L2, APPROVE_L3'
    END IF;

    PERFORM 1 FROM Finance.import_sessions a where a.session_id = p_session_id;

    INSERT INTO Staging.import_approvals (session_id, staging_record_id,approval_status,approval_level,approved_by)
    SELECT  a.session_id,
            a.staging_record_id,
            p_status,
            p_level,
            p_approve_by
    FROM Staging.import_workflow a 
    WHERE a.new_state = 'VALID' AND a.session_id = new_session_id;

    UPDATE import_workflow
    SET new_state = p_approve_state,
        previous_state = new_previous_state
    WHERE session_id = new_session_id AND new_state = new_previous_state;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Staging import approval failed: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE Staging.post_ar_import(p_session_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    new_previous_state VARCHAR(50);
BEGIN

    SELECT session_id INTO new_session_id
    FROM Finance.import_sessions a
    WHERE a.session_id = p_session_id
    LIMIT 1;

    SELECT new_state INTO new_previous_state
    FROM Staging.import_workflow a
    WHERE a.session_id = p_session_id
    LIMIT 1;
   

    IF new_session_id IS NULL THEN
        RAISE EXCEPTION 'invalid Session ID : %', new_session_id;
    END IF;

    PERFORM 1 FROM Finance.import_sessions WHERE session_id = p_session_id;
 
    FOR r IN
        SELECT *
        FROM Staging.stg_ar_import
        WHERE session_id = p_session_id
          AND validation_status = 'APPROVED_L3'
    LOOP
        CALL Finance.ar_transaction(
            r.client_id,
            r.customer_id,
            r.due_date::DATE,
            r.invoice_date::DATE,
            r.amount::DECIMAL,
            r.status,
            gen_random_uuid()::TEXT
        );
    END LOOP;
    
    UPDATE import_workflow
    SET new_state = 'POSTED',
        previous_state = new_previous_state
    WHERE session_id = new_session_id AND new_state = new_previous_state;

END;
$$;

COMMIT;

SELECT '14. Stagging schema COMPLETE!' as  Status;
