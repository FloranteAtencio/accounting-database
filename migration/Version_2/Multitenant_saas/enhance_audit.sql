-- ============================================
-- ENHANCED AUDIT & EVENT LOGGING
-- Version: 2.0
-- Purpose: Track all changes with context, impact, and compliance
-- ============================================

BEGIN;

-- ============================================
-- 1. ENHANCED AUDIT LOGS TABLE
-- ============================================

DROP TABLE IF EXISTS finance.audit_logs_extended CASCADE;
CREATE TABLE finance.audit_logs_extended (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    operation VARCHAR(20) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id BIGINT,
    
    -- WHO & WHEN
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- WHAT CHANGED
    old_values JSONB,
    new_values JSONB,
    fields_changed TEXT[],  -- Array of changed columns
    
    -- WHERE & HOW
    ip_address INET,
    client_id INT REFERENCES finance.clients(client_id) ON DELETE SET NULL,
    
    -- COMPLIANCE
    prev_hash TEXT,
    row_hash TEXT,
    hash_chain_valid BOOLEAN DEFAULT TRUE,
    
    -- INDEXES FOR PERFORMANCE
    INDEX idx_audit_table_date (table_name, changed_at DESC),
    INDEX idx_audit_user_date (changed_by, changed_at DESC),
    INDEX idx_audit_record (table_name, record_id),
    INDEX idx_audit_client (client_id)
);

-- ============================================
-- 2. EVENT LOG WITH DETAILED TRACKING
-- ============================================

DROP TABLE IF EXISTS finance.event_logs_detailed CASCADE;
CREATE TABLE finance.event_logs_detailed (
    event_id BIGSERIAL PRIMARY KEY,
    
    -- EVENT CLASSIFICATION
    event_type VARCHAR(100) NOT NULL,  -- e.g., 'TRANSACTION_CREATED', 'JOURNAL_POSTED', 'RECONCILIATION_COMPLETED'
    event_category VARCHAR(50) NOT NULL CHECK (event_category IN ('FINANCIAL', 'SYSTEM', 'SECURITY', 'COMPLIANCE', 'DATA_QUALITY')),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('INFO', 'WARNING', 'ERROR', 'CRITICAL')),
    
    -- EVENT DETAILS
    description TEXT NOT NULL,
    payload JSONB NOT NULL,  -- Structured event data
    context JSONB,  -- Additional context
    
    -- WHO & WHEN
    triggered_by VARCHAR(100) NOT NULL,
    triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- TRANSACTION INFO
    transaction_id BIGINT REFERENCES finance.transactions(transaction_id) ON DELETE SET NULL,
    journal_id BIGINT REFERENCES finance.journals(journal_id) ON DELETE SET NULL,
    client_id INT REFERENCES finance.clients(client_id) ON DELETE SET NULL,
    
    -- IDEMPOTENCY & STATUS
    idempotency_key TEXT UNIQUE,
    status VARCHAR(20) DEFAULT 'RECORDED' CHECK (status IN ('RECORDED', 'PROCESSED', 'FAILED', 'RETRY')),
    processed_at TIMESTAMP,
    
    -- ERROR TRACKING
    error_message TEXT,
    error_stack_trace TEXT,
    retry_count INT DEFAULT 0,
    
    -- INDEXES FOR PERFORMANCE
    INDEX idx_event_type_date (event_type, triggered_at DESC),
    INDEX idx_event_category_severity (event_category, severity),
    INDEX idx_event_client (client_id, triggered_at DESC),
    INDEX idx_event_status (status, triggered_at DESC)
);

-- ============================================
-- 3. TRANSACTION LIFECYCLE LOG
-- ============================================

DROP TABLE IF EXISTS finance.transaction_lifecycle CASCADE;
CREATE TABLE finance.transaction_lifecycle (
    lifecycle_id BIGSERIAL PRIMARY KEY,
    
    transaction_id BIGINT NOT NULL REFERENCES finance.transactions(transaction_id) ON DELETE CASCADE,
    
    -- LIFECYCLE STATES
    state VARCHAR(50) NOT NULL CHECK (state IN ('DRAFT', 'SUBMITTED', 'POSTED', 'RECONCILED', 'APPROVED', 'ARCHIVED', 'REVERSED')),
    previous_state VARCHAR(50),
    
    -- STATE CHANGE DETAILS
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason TEXT,  -- Why the state changed
    
    -- APPROVAL CHAIN (if applicable)
    requires_approval BOOLEAN DEFAULT FALSE,
    approved_by VARCHAR(100),
    approved_at TIMESTAMP,
    approval_notes TEXT,
    
    -- FINANCIAL IMPACT
    amount_affected DECIMAL(15,2),
    journal_count INT,
    
    INDEX idx_transaction_lifecycle (transaction_id, changed_at DESC),
    INDEX idx_state_changes (state, changed_at DESC)
);

-- ============================================
-- 4. COMPLIANCE EVENT LOG
-- ============================================

DROP TABLE IF EXISTS finance.compliance_log CASCADE;
CREATE TABLE finance.compliance_log (
    compliance_id BIGSERIAL PRIMARY KEY,
    
    -- COMPLIANCE RULES
    rule_id VARCHAR(100) NOT NULL,  -- e.g., 'MIN_JOURNAL_DEBIT_CREDIT', 'AP_AGING_THRESHOLD'
    rule_name VARCHAR(255) NOT NULL,
    rule_description TEXT,
    
    -- VIOLATION DETAILS
    violation_detected BOOLEAN NOT NULL,
    severity VARCHAR(20) CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    
    -- CONTEXT
    table_name VARCHAR(255),
    record_id BIGINT,
    affected_data JSONB,
    
    -- ACTION TAKEN
    action_required VARCHAR(255),
    action_taken TEXT,
    resolved_by VARCHAR(100),
    resolved_at TIMESTAMP,
    
    -- AUDIT TRAIL
    detected_by VARCHAR(100) NOT NULL,
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_id INT REFERENCES finance.clients(client_id) ON DELETE SET NULL,
    
    INDEX idx_compliance_rule (rule_id, detected_at DESC),
    INDEX idx_compliance_violation (violation_detected, severity)
);

-- ============================================
-- 5. ENHANCED AUDIT FUNCTION WITH CONTEXT
-- ============================================

CREATE OR REPLACE FUNCTION finance.audit_log_enhanced()
RETURNS TRIGGER AS $$
DECLARE
    v_prev_hash TEXT;
    v_new_hash TEXT;
    v_fields_changed TEXT[];
    v_field_name TEXT;
    v_old_val TEXT;
    v_new_val TEXT;
    v_record_id BIGINT;
    v_client_id INT := NULL;
    v_ip_address INET := NULL;
BEGIN
    -- Get IP if available (requires pgpool or application layer to set)
    v_ip_address := COALESCE(
        (current_setting('app.client_ip', true))::INET,
        '0.0.0.0'::INET
    );
    
    -- Determine record ID
    v_record_id := COALESCE((NEW).*, (OLD).*);
    
    -- Try to get client_id if table has it
    IF TG_TABLE_NAME IN ('transactions', 'journals', 'charts') THEN
        CASE TG_TABLE_NAME
            WHEN 'transactions' THEN v_client_id := (COALESCE(NEW, OLD)).client_id;
            WHEN 'journals' THEN 
                v_client_id := (SELECT client_id FROM finance.transactions 
                               WHERE transaction_id = (COALESCE(NEW, OLD)).transaction_id LIMIT 1);
            WHEN 'charts' THEN v_client_id := (COALESCE(NEW, OLD)).client_id;
        END CASE;
    END IF;
    
    -- Detect which fields changed (for UPDATE operations)
    IF TG_OP = 'UPDATE' THEN
        v_fields_changed := ARRAY[]::TEXT[];
        FOR v_field_name IN (SELECT json_object_keys(to_json(NEW))) LOOP
            v_old_val := (to_json(OLD) ->> v_field_name)::TEXT;
            v_new_val := (to_json(NEW) ->> v_field_name)::TEXT;
            IF v_old_val IS DISTINCT FROM v_new_val THEN
                v_fields_changed := array_append(v_fields_changed, v_field_name);
            END IF;
        END LOOP;
    END IF;
    
    -- Get previous hash
    SELECT row_hash INTO v_prev_hash
    FROM finance.audit_logs_extended
    WHERE table_name = TG_TABLE_NAME
    ORDER BY audit_id DESC
    LIMIT 1;
    
    -- Calculate new hash
    v_new_hash := md5(
        COALESCE(v_prev_hash, '') ||
        TG_TABLE_NAME ||
        TG_OP ||
        (COALESCE(NEW, OLD))::TEXT
    );
    
    -- Insert audit record
    INSERT INTO finance.audit_logs_extended (
        table_name,
        operation,
        record_id,
        changed_by,
        changed_at,
        old_values,
        new_values,
        fields_changed,
        ip_address,
        client_id,
        prev_hash,
        row_hash
    ) VALUES (
        TG_TABLE_NAME,
        TG_OP,
        v_record_id,
        current_user,
        CURRENT_TIMESTAMP,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('UPDATE', 'INSERT') THEN to_jsonb(NEW) ELSE NULL END,
        v_fields_changed,
        v_ip_address,
        v_client_id,
        v_prev_hash,
        v_new_hash
    );
    
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. EVENT LOG FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION finance.log_event(
    p_event_type VARCHAR,
    p_event_category VARCHAR,
    p_severity VARCHAR,
    p_description TEXT,
    p_payload JSONB,
    p_transaction_id BIGINT DEFAULT NULL,
    p_journal_id BIGINT DEFAULT NULL,
    p_client_id INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_id BIGINT;
    v_idempotency_key TEXT;
BEGIN
    -- Generate idempotency key
    v_idempotency_key := md5(
        p_event_type || '::' ||
        p_transaction_id::TEXT || '::' ||
        CURRENT_TIMESTAMP::TEXT
    );
    
    INSERT INTO finance.event_logs_detailed (
        event_type,
        event_category,
        severity,
        description,
        payload,
        triggered_by,
        triggered_at,
        transaction_id,
        journal_id,
        client_id,
        idempotency_key,
        status
    ) VALUES (
        p_event_type,
        p_event_category,
        p_severity,
        p_description,
        p_payload,
        current_user,
        CURRENT_TIMESTAMP,
        p_transaction_id,
        p_journal_id,
        p_client_id,
        v_idempotency_key,
        'RECORDED'
    ) RETURNING event_id INTO v_event_id;
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. TRANSACTION LIFECYCLE TRACKING
-- ============================================

CREATE OR REPLACE FUNCTION finance.track_transaction_state_change(
    p_transaction_id BIGINT,
    p_new_state VARCHAR,
    p_reason TEXT DEFAULT NULL,
    p_amount DECIMAL DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_previous_state VARCHAR;
BEGIN
    -- Get current state
    SELECT state INTO v_previous_state
    FROM finance.transaction_lifecycle
    WHERE transaction_id = p_transaction_id
    ORDER BY lifecycle_id DESC
    LIMIT 1;
    
    -- Insert state change
    INSERT INTO finance.transaction_lifecycle (
        transaction_id,
        state,
        previous_state,
        changed_by,
        reason,
        amount_affected
    ) VALUES (
        p_transaction_id,
        p_new_state,
        v_previous_state,
        current_user,
        p_reason,
        p_amount
    );
    
    -- Log event
    PERFORM finance.log_event(
        'TRANSACTION_STATE_CHANGE'::VARCHAR,
        'FINANCIAL'::VARCHAR,
        'INFO'::VARCHAR,
        'Transaction state changed from ' || v_previous_state || ' to ' || p_new_state,
        jsonb_build_object(
            'transaction_id', p_transaction_id,
            'previous_state', v_previous_state,
            'new_state', p_new_state,
            'reason', p_reason
        ),
        p_transaction_id
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 8. COMPLIANCE CHECK FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION finance.check_debit_credit_balance()
RETURNS TABLE (
    rule_id VARCHAR,
    violation_detected BOOLEAN,
    total_debits DECIMAL,
    total_credits DECIMAL,
    difference DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        'DOUBLE_ENTRY_BALANCE'::VARCHAR,
        ABS(
            COALESCE(SUM(CASE WHEN journal THEN amount ELSE 0 END), 0) -
            COALESCE(SUM(CASE WHEN NOT journal THEN amount ELSE 0 END), 0)
        ) > 0.01 AS violation_detected,
        COALESCE(SUM(CASE WHEN journal THEN amount ELSE 0 END), 0)::DECIMAL,
        COALESCE(SUM(CASE WHEN NOT journal THEN amount ELSE 0 END), 0)::DECIMAL,
        ABS(
            COALESCE(SUM(CASE WHEN journal THEN amount ELSE 0 END), 0) -
            COALESCE(SUM(CASE WHEN NOT journal THEN amount ELSE 0 END), 0)
        )::DECIMAL
    FROM finance.journals;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 9. ATTACH ENHANCED TRIGGERS TO TABLES
-- ============================================

-- Apply enhanced audit trigger to key tables
CREATE TRIGGER audit_transactions_enhanced
AFTER INSERT OR UPDATE OR DELETE ON finance.transactions
FOR EACH ROW EXECUTE FUNCTION finance.audit_log_enhanced();

CREATE TRIGGER audit_journals_enhanced
AFTER INSERT OR UPDATE OR DELETE ON finance.journals
FOR EACH ROW EXECUTE FUNCTION finance.audit_log_enhanced();

CREATE TRIGGER audit_ar_enhanced
AFTER INSERT OR UPDATE OR DELETE ON finance.account_receivables
FOR EACH ROW EXECUTE FUNCTION finance.audit_log_enhanced();

CREATE TRIGGER audit_ap_enhanced
AFTER INSERT OR UPDATE OR DELETE ON finance.account_payables
FOR EACH ROW EXECUTE FUNCTION finance.audit_log_enhanced();

COMMIT;

-- ============================================
-- EXAMPLE QUERIES
-- ============================================

/*
-- View all changes by user
SELECT changed_by, operation, table_name, COUNT(*) as change_count, MAX(changed_at) as last_change
FROM finance.audit_logs_extended
GROUP BY changed_by, operation, table_name
ORDER BY last_change DESC;

-- View transaction state history
SELECT lifecycle_id, transaction_id, state, previous_state, changed_by, changed_at, reason
FROM finance.transaction_lifecycle
WHERE transaction_id = 123
ORDER BY lifecycle_id;

-- Check compliance violations
SELECT rule_id, violation_detected, detected_at, severity, action_required
FROM finance.compliance_log
WHERE violation_detected = TRUE
ORDER BY detected_at DESC;

-- View recent events
SELECT event_id, event_type, event_category, severity, triggered_at, triggered_by
FROM finance.event_logs_detailed
ORDER BY triggered_at DESC
LIMIT 50;
*/
