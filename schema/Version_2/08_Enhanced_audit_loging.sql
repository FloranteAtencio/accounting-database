-- ============================================
-- 10_ENHANCED_AUDIT_LOGGING.SQL
-- Purpose: Extended audit logging with import tracking
-- and field-level change tracking
-- ============================================

BEGIN;

-- ============================================
-- 1. EXTENDED AUDIT LOGS TABLE
-- ============================================

DROP TABLE IF EXISTS Finance.audit_logs_extended CASCADE;
CREATE TABLE Finance.audit_logs_extended (
    extended_audit_id BIGSERIAL PRIMARY KEY,
    audit_id INT REFERENCES Finance.audit_logs(audit_id) ON DELETE NO ACTION,
    client_id INT REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    table_name VARCHAR(255) NOT NULL,
    record_id INT NOT NULL,
    operation VARCHAR(20) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    field_name VARCHAR(255),
    old_value TEXT,
    new_value TEXT,
    changed_by VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    session_id TEXT,
    UNIQUE(audit_id, field_name)
);

CREATE INDEX idx_audit_logs_extended_client ON Finance.audit_logs_extended(client_id);
CREATE INDEX idx_audit_logs_extended_time ON Finance.audit_logs_extended(changed_at);
CREATE INDEX idx_audit_logs_extended_user ON Finance.audit_logs_extended(changed_by);
CREATE INDEX idx_audit_logs_extended_record ON Finance.audit_logs_extended(table_name, record_id);

-- ============================================
-- 2. IMPORT SESSION TRACKING
-- ============================================

DROP TABLE IF EXISTS Finance.import_sessions CASCADE;
CREATE TABLE Finance.import_sessions (
    session_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    import_type VARCHAR(50) NOT NULL,  -- 'transactions', 'ar', 'ap', 'inventory', etc.
    imported_by VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'IN_PROGRESS' CHECK (status IN ('IN_PROGRESS', 'SUCCESS', 'PARTIAL_SUCCESS', 'FAILED')),
    total_records INT DEFAULT 0,
    successful_records INT DEFAULT 0,
    failed_records INT DEFAULT 0,
    error_summary TEXT,
    source_file VARCHAR(500),
    notes TEXT
);

CREATE INDEX idx_import_sessions_client ON Finance.import_sessions(client_id);
CREATE INDEX idx_import_sessions_status ON Finance.import_sessions(status);
CREATE INDEX idx_import_sessions_date ON Finance.import_sessions(started_at);

-- ============================================
-- 3. IMPORT DETAIL LOG
-- ============================================

DROP TABLE IF EXISTS Finance.import_detail_logs CASCADE;
CREATE TABLE Finance.import_detail_logs (
    detail_id BIGSERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES Finance.import_sessions(session_id) ON DELETE NO ACTION,
    row_number INT NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    record_data JSONB NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('SUCCESS', 'FAILED', 'SKIPPED', 'WARNED')),
    error_message TEXT,
    warning_message TEXT,
    created_record_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_import_detail_session ON Finance.import_detail_logs(session_id);
CREATE INDEX idx_import_detail_status ON Finance.import_detail_logs(status);
CREATE INDEX idx_import_detail_table ON Finance.import_detail_logs(table_name);

-- ============================================
-- 4. IMPORT VALIDATION LOG
-- ============================================

DROP TABLE IF EXISTS Finance.import_validation_log CASCADE;
CREATE TABLE Finance.import_validation_log (
    validation_id BIGSERIAL PRIMARY KEY,
    session_id INT REFERENCES Finance.import_sessions(session_id) ON DELETE NO ACTION,
    row_number INT NOT NULL,
    field_name VARCHAR(255) NOT NULL,
    validation_rule VARCHAR(255) NOT NULL,
    expected_value TEXT,
    actual_value TEXT,
    is_valid BOOLEAN NOT NULL,
    severity VARCHAR(20) DEFAULT 'ERROR' CHECK (severity IN ('ERROR', 'WARNING', 'INFO')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_import_validation_session ON Finance.import_validation_log(session_id);
CREATE INDEX idx_import_validation_field ON Finance.import_validation_log(field_name);

-- ============================================
-- 5. AUDIT HELPER FUNCTIONS
-- ============================================

-- Function to start an import session
DROP FUNCTION IF EXISTS Finance.start_import_session(INT, VARCHAR, VARCHAR, VARCHAR) CASCADE;
CREATE FUNCTION Finance.start_import_session(
    p_client_id INT,
    p_import_type VARCHAR,
    p_imported_by VARCHAR,
    p_source_file VARCHAR DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    v_session_id INT;
BEGIN
    INSERT INTO Finance.import_sessions (client_id, import_type, imported_by, source_file, status)
    VALUES (p_client_id, p_import_type, p_imported_by, p_source_file, 'IN_PROGRESS')
    RETURNING session_id INTO v_session_id;
    
    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql;

-- Function to log an import record
DROP FUNCTION IF EXISTS Finance.log_import_record(INT, INT, VARCHAR, JSONB, VARCHAR, TEXT, INT) CASCADE;
CREATE FUNCTION Finance.log_import_record(
    p_session_id INT,
    p_row_number INT,
    p_table_name VARCHAR,
    p_record_data JSONB,
    p_status VARCHAR,
    p_error_message TEXT DEFAULT NULL,
    p_created_record_id INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_detail_id BIGINT;
BEGIN
    INSERT INTO Finance.import_detail_logs (
        session_id, row_number, table_name, record_data, 
        status, error_message, created_record_id
    )
    VALUES (p_session_id, p_row_number, p_table_name, p_record_data, 
            p_status, p_error_message, p_created_record_id)
    RETURNING detail_id INTO v_detail_id;
    
    -- Update import session counts
    UPDATE Finance.import_sessions
    SET total_records = total_records + 1,
        successful_records = CASE WHEN p_status = 'SUCCESS' THEN successful_records + 1 ELSE successful_records END,
        failed_records = CASE WHEN p_status = 'FAILED' THEN failed_records + 1 ELSE failed_records END
    WHERE session_id = p_session_id;
    
    RETURN v_detail_id;
END;
$$ LANGUAGE plpgsql;

-- Function to complete an import session
DROP FUNCTION IF EXISTS Finance.complete_import_session(INT, VARCHAR, TEXT) CASCADE;
CREATE FUNCTION Finance.complete_import_session(
    p_session_id INT,
    p_final_status VARCHAR,
    p_error_summary TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE Finance.import_sessions
    SET status = p_final_status,
        completed_at = CURRENT_TIMESTAMP,
        error_summary = p_error_summary
    WHERE session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get import history for a client
DROP FUNCTION IF EXISTS Finance.get_import_history(INT, INT) CASCADE;
CREATE FUNCTION Finance.get_import_history(
    p_client_id INT,
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    session_id INT,
    import_type VARCHAR,
    imported_by VARCHAR,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR,
    total_records INT,
    successful_records INT,
    failed_records INT,
    success_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.session_id,
        s.import_type,
        s.imported_by,
        s.started_at,
        s.completed_at,
        s.status,
        s.total_records,
        s.successful_records,
        s.failed_records,
        CASE WHEN s.total_records > 0 
             THEN ROUND((s.successful_records::NUMERIC / s.total_records * 100), 2)
             ELSE 0 END
    FROM Finance.import_sessions s
    WHERE s.client_id = p_client_id
    ORDER BY s.started_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to get failed imports
DROP FUNCTION IF EXISTS Finance.get_failed_imports(INT, INT) CASCADE;
CREATE FUNCTION Finance.get_failed_imports(
    p_client_id INT,
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    session_id INT,
    import_type VARCHAR,
    row_number INT,
    table_name VARCHAR,
    error_message TEXT,
    failed_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        idl.session_id,
        s.import_type,
        idl.row_number,
        idl.table_name,
        idl.error_message,
        idl.created_at
    FROM Finance.import_detail_logs idl
    JOIN Finance.import_sessions s ON idl.session_id = s.session_id
    WHERE s.client_id = p_client_id AND idl.status = 'FAILED'
    ORDER BY idl.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to get user audit trail
DROP FUNCTION IF EXISTS Finance.get_user_audit_trail(VARCHAR, INT) CASCADE;
CREATE FUNCTION Finance.get_user_audit_trail(
    p_username VARCHAR,
    p_days INT DEFAULT 30
)
RETURNS TABLE (
    audit_id INT,
    table_name VARCHAR,
    operation VARCHAR,
    record_id INT,
    old_value TEXT,
    new_value TEXT,
    changed_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ale.extended_audit_id::INT,
        ale.table_name,
        ale.operation,
        ale.record_id,
        ale.old_value,
        ale.new_value,
        ale.changed_at
    FROM Finance.audit_logs_extended ale
    WHERE ale.changed_by = p_username 
        AND ale.changed_at >= CURRENT_TIMESTAMP - (p_days || ' days')::INTERVAL
    ORDER BY ale.changed_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verification
SELECT 'Enhanced Audit Logging Successfully Implemented' AS status;