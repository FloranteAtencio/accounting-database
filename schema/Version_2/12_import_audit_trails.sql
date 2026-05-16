-- ============================================
-- 12_IMPORT_AUDIT_TRAIL.SQL
-- Purpose: Complete audit trail for compliance
-- with state tracking and reconciliation
-- ============================================

BEGIN;

-- ============================================
-- 1. TRANSACTION STATE TRACKING
-- ============================================

DROP TABLE IF EXISTS Finance.transaction_lifecycle CASCADE;
CREATE TABLE Finance.transaction_lifecycle (
    lifecycle_id BIGSERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES Finance.transactions(transaction_id) ON DELETE NO ACTION,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    previous_state VARCHAR(50),
    new_state VARCHAR(50) NOT NULL CHECK (new_state IN (
        'DRAFT', 'SUBMITTED', 'VALIDATED', 'POSTED', 
        'RECONCILED', 'APPROVED', 'ARCHIVED', 'REJECTED'
    )),
    state_reason VARCHAR(255),
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

CREATE INDEX idx_transaction_lifecycle_id ON Finance.transaction_lifecycle(transaction_id);
CREATE INDEX idx_transaction_lifecycle_client ON Finance.transaction_lifecycle(client_id);
CREATE INDEX idx_transaction_lifecycle_state ON Finance.transaction_lifecycle(new_state);
CREATE INDEX idx_transaction_lifecycle_time ON Finance.transaction_lifecycle(changed_at);

-- ============================================
-- 2. APPROVAL CHAIN TRACKING
-- ============================================

DROP TABLE IF EXISTS Finance.approval_chain CASCADE;
CREATE TABLE Finance.approval_chain (
    approval_id BIGSERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES Finance.transactions(transaction_id) ON DELETE NO ACTION,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    approval_level INT NOT NULL,  -- 1=Bookkeeper, 2=Supervisor, 3=Manager, etc.
    approver_role VARCHAR(100) NOT NULL,
    approver_name VARCHAR(100),
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    approval_comment TEXT,
    approved_at TIMESTAMP,
    required_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_approval_chain_transaction ON Finance.approval_chain(transaction_id);
CREATE INDEX idx_approval_chain_status ON Finance.approval_chain(status);

-- ============================================
-- 3. RECONCILIATION TRACKING
-- ============================================

DROP TABLE IF EXISTS Finance.reconciliation_tracking CASCADE;
CREATE TABLE Finance.reconciliation_tracking (
    reconciliation_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    account_id INT NOT NULL REFERENCES Finance.charts(chart_id) ON DELETE NO ACTION,
    reconciliation_date DATE NOT NULL,
    reconciled_by VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'IN_PROGRESS', 'RECONCILED', 'DISCREPANCY_FOUND')),
    opening_balance DECIMAL(15,2),
    closing_balance DECIMAL(15,2),
    expected_balance DECIMAL(15,2),
    discrepancy_amount DECIMAL(15,2),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX idx_reconciliation_account ON Finance.reconciliation_tracking(account_id);
CREATE INDEX idx_reconciliation_date ON Finance.reconciliation_tracking(reconciliation_date);
CREATE INDEX idx_reconciliation_status ON Finance.reconciliation_tracking(status);

-- ============================================
-- 4. RECORD LINEAGE (Data Provenance)
-- ============================================

DROP TABLE IF EXISTS Finance.record_lineage CASCADE;
CREATE TABLE Finance.record_lineage (
    lineage_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    record_id INT NOT NULL,
    client_id INT REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    source_type VARCHAR(50) NOT NULL CHECK (source_type IN (
        'MANUAL_ENTRY', 'SPREADSHEET_IMPORT', 'API_IMPORT', 
        'SYSTEM_GENERATED', 'CORRECTION', 'REVERSAL'
    )),
    source_file VARCHAR(500),
    import_session_id INT REFERENCES Finance.import_sessions(session_id) ON DELETE NO ACTION,
    import_row_number INT,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100),
    last_modified_at TIMESTAMP,
    is_original BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_record_lineage_table ON Finance.record_lineage(table_name, record_id);
CREATE INDEX idx_record_lineage_source ON Finance.record_lineage(source_type);
CREATE INDEX idx_record_lineage_session ON Finance.record_lineage(import_session_id);

-- ============================================
-- 5. COMPLIANCE LOG
-- ============================================

DROP TABLE IF EXISTS Finance.compliance_log CASCADE;
CREATE TABLE Finance.compliance_log (
    compliance_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    compliance_rule VARCHAR(255) NOT NULL,
    rule_description TEXT,
    check_type VARCHAR(50) NOT NULL CHECK (check_type IN (
        'BALANCE_CHECK', 'AMOUNT_CHECK', 'DATE_CHECK', 
        'DUPLICATE_CHECK', 'THRESHOLD_CHECK', 'RECONCILIATION_CHECK'
    )),
    status VARCHAR(20) NOT NULL CHECK (status IN ('PASS', 'FAIL', 'WARNING')),
    details TEXT,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolution_status VARCHAR(20) CHECK (resolution_status IN ('UNRESOLVED', 'RESOLVED', 'WAIVED')),
    resolution_notes TEXT,
    resolved_at TIMESTAMP
);

CREATE INDEX idx_compliance_client ON Finance.compliance_log(client_id);
CREATE INDEX idx_compliance_status ON Finance.compliance_log(status);
CREATE INDEX idx_compliance_rule ON Finance.compliance_log(compliance_rule);

-- ============================================
-- 6. AUDIT TRAIL FUNCTIONS
-- ============================================

-- Record state change
DROP FUNCTION IF EXISTS Finance.record_state_change(INT, INT, VARCHAR, VARCHAR, VARCHAR, VARCHAR) CASCADE;
CREATE FUNCTION Finance.record_state_change(
    p_transaction_id INT,
    p_client_id INT,
    p_new_state VARCHAR,
    p_state_reason VARCHAR,
    p_changed_by VARCHAR,
    p_notes VARCHAR DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_previous_state VARCHAR;
    v_lifecycle_id BIGINT;
BEGIN
    -- Get previous state
    SELECT new_state INTO v_previous_state
    FROM Finance.transaction_lifecycle
    WHERE transaction_id = p_transaction_id
    ORDER BY changed_at DESC
    LIMIT 1;
    
    -- Insert new state record
    INSERT INTO Finance.transaction_lifecycle (
        transaction_id, client_id, previous_state, new_state, 
        state_reason, changed_by, notes
    )
    VALUES (p_transaction_id, p_client_id, v_previous_state, p_new_state, 
            p_state_reason, p_changed_by, p_notes)
    RETURNING lifecycle_id INTO v_lifecycle_id;
    
    RETURN v_lifecycle_id;
END;
$$ LANGUAGE plpgsql;

-- Record approval
DROP FUNCTION IF EXISTS Finance.record_approval(INT, INT, INT, VARCHAR, VARCHAR, VARCHAR, TEXT) CASCADE;
CREATE FUNCTION Finance.record_approval(
    p_transaction_id INT,
    p_client_id INT,
    p_approval_level INT,
    p_approver_role VARCHAR,
    p_approver_name VARCHAR,
    p_status VARCHAR,
    p_comment TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_approval_id BIGINT;
BEGIN
    INSERT INTO Finance.approval_chain (
        transaction_id, client_id, approval_level, approver_role,
        approver_name, status, approval_comment, approved_at
    )
    VALUES (p_transaction_id, p_client_id, p_approval_level, p_approver_role,
            p_approver_name, p_status, p_comment,
            CASE WHEN p_status = 'APPROVED' THEN CURRENT_TIMESTAMP ELSE NULL END)
    RETURNING approval_id INTO v_approval_id;
    
    RETURN v_approval_id;
END;
$$ LANGUAGE plpgsql;

-- Record lineage
DROP FUNCTION IF EXISTS Finance.record_lineage_entry(VARCHAR, INT, INT, VARCHAR, VARCHAR, INT, INT, VARCHAR) CASCADE;
CREATE FUNCTION Finance.record_lineage_entry(
    p_table_name VARCHAR,
    p_record_id INT,
    p_client_id INT,
    p_source_type VARCHAR,
    p_created_by VARCHAR,
    p_import_session_id INT DEFAULT NULL,
    p_import_row_number INT DEFAULT NULL,
    p_source_file VARCHAR DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_lineage_id BIGINT;
BEGIN
    INSERT INTO Finance.record_lineage (
        table_name, record_id, client_id, source_type, source_file,
        import_session_id, import_row_number, created_by, created_at
    )
    VALUES (p_table_name, p_record_id, p_client_id, p_source_type, p_source_file,
            p_import_session_id, p_import_row_number, p_created_by, CURRENT_TIMESTAMP)
    RETURNING lineage_id INTO v_lineage_id;
    
    RETURN v_lineage_id;
END;
$$ LANGUAGE plpgsql;

-- Log compliance check
DROP FUNCTION IF EXISTS Finance.log_compliance_check(INT, VARCHAR, TEXT, VARCHAR, VARCHAR, TEXT) CASCADE;
CREATE FUNCTION Finance.log_compliance_check(
    p_client_id INT,
    p_rule_name VARCHAR,
    p_rule_description TEXT,
    p_check_type VARCHAR,
    p_status VARCHAR,
    p_details TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_compliance_id BIGINT;
BEGIN
    INSERT INTO Finance.compliance_log (
        client_id, compliance_rule, rule_description, check_type, status, details
    )
    VALUES (p_client_id, p_rule_name, p_rule_description, p_check_type, p_status, p_details)
    RETURNING compliance_id INTO v_compliance_id;
    
    RETURN v_compliance_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. COMPLETE AUDIT QUERY FUNCTIONS
-- ============================================

-- Get complete transaction audit
DROP FUNCTION IF EXISTS Finance.get_complete_transaction_audit(INT) CASCADE;
CREATE FUNCTION Finance.get_complete_transaction_audit(p_transaction_id INT)
RETURNS TABLE (
    audit_type VARCHAR,
    event_time TIMESTAMP,
    event_details TEXT,
    changed_by VARCHAR,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    -- State changes
    SELECT 
        'STATE_CHANGE'::VARCHAR,
        tl.changed_at,
        'State: ' || COALESCE(tl.previous_state, 'N/A') || ' → ' || tl.new_state || ' (' || tl.state_reason || ')'::TEXT,
        tl.changed_by,
        tl.new_state::VARCHAR
    FROM Finance.transaction_lifecycle tl
    WHERE tl.transaction_id = p_transaction_id
    
    UNION ALL
    
    -- Approvals
    SELECT 
        'APPROVAL'::VARCHAR,
        ac.created_at,
        'Level ' || ac.approval_level::TEXT || ': ' || ac.approver_role || ' - ' || ac.status::TEXT::TEXT,
        ac.approver_name,
        ac.status::VARCHAR
    FROM Finance.approval_chain ac
    WHERE ac.transaction_id = p_transaction_id
    
    UNION ALL
    
    -- Audit trail
    SELECT 
        'AUDIT_LOG'::VARCHAR,
        al.log_time,
        'Table: ' || al.table_name || ' Operation: ' || al.operation::TEXT,
        al.changed_by,
        'LOGGED'::VARCHAR
    FROM Finance.audit_logs al
    WHERE al.rec_transact LIKE '%"transaction_id":' || p_transaction_id::TEXT || '%'
    
    ORDER BY event_time DESC;
END;
$$ LANGUAGE plpgsql;

-- Get reconciliation report
DROP FUNCTION IF EXISTS Finance.get_reconciliation_report(INT, DATE, DATE) CASCADE;
CREATE FUNCTION Finance.get_reconciliation_report(
    p_client_id INT,
    p_from_date DATE,
    p_to_date DATE
)
RETURNS TABLE (
    account_name VARCHAR,
    reconciliation_date DATE,
    opening_balance DECIMAL,
    closing_balance DECIMAL,
    expected_balance DECIMAL,
    discrepancy_amount DECIMAL,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.account::VARCHAR,
        rt.reconciliation_date,
        rt.opening_balance,
        rt.closing_balance,
        rt.expected_balance,
        rt.discrepancy_amount,
        rt.status::VARCHAR
    FROM Finance.reconciliation_tracking rt
    JOIN Finance.charts c ON rt.account_id = c.chart_id
    WHERE rt.client_id = p_client_id
        AND rt.reconciliation_date BETWEEN p_from_date AND p_to_date
    ORDER BY rt.reconciliation_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Get record lineage
DROP FUNCTION IF EXISTS Finance.get_record_lineage(VARCHAR, INT) CASCADE;
CREATE FUNCTION Finance.get_record_lineage(
    p_table_name VARCHAR,
    p_record_id INT
)
RETURNS TABLE (
    source_type VARCHAR,
    source_file VARCHAR,
    created_by VARCHAR,
    created_at TIMESTAMP,
    last_modified_by VARCHAR,
    last_modified_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rl.source_type::VARCHAR,
        rl.source_file::VARCHAR,
        rl.created_by::VARCHAR,
        rl.created_at,
        rl.last_modified_by::VARCHAR,
        rl.last_modified_at
    FROM Finance.record_lineage rl
    WHERE rl.table_name = p_table_name AND rl.record_id = p_record_id;
END;
$$ LANGUAGE plpgsql;

-- Get compliance violations
DROP FUNCTION IF EXISTS Finance.get_compliance_violations(INT, INT) CASCADE;
CREATE FUNCTION Finance.get_compliance_violations(
    p_client_id INT,
    p_days INT DEFAULT 30
)
RETURNS TABLE (
    compliance_id BIGINT,
    rule_name VARCHAR,
    check_type VARCHAR,
    status VARCHAR,
    details TEXT,
    checked_at TIMESTAMP,
    resolution_status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cl.compliance_id,
        cl.compliance_rule::VARCHAR,
        cl.check_type::VARCHAR,
        cl.status::VARCHAR,
        cl.details::TEXT,
        cl.checked_at,
        COALESCE(cl.resolution_status, 'UNRESOLVED')::VARCHAR
    FROM Finance.compliance_log cl
    WHERE cl.client_id = p_client_id
        AND cl.status != 'PASS'
        AND cl.checked_at >= CURRENT_TIMESTAMP - (p_days || ' days')::INTERVAL
    ORDER BY cl.checked_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verification
SELECT 'Import Audit Trail Successfully Implemented' AS status;