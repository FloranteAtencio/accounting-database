-- ============================================
-- 03_SECURITY_ACCESS_CONTROL_FRAMEWORK.SQL
-- Purpose: Security, authentication, and access control
-- ============================================

BEGIN;

-- ============================================
-- 1. USER & ROLE MANAGEMENT TABLES
-- ============================================

DROP TABLE IF EXISTS dba_admin.user_access_log CASCADE;
CREATE TABLE dba_admin.user_access_log (
    access_id BIGSERIAL PRIMARY KEY,
    user_name VARCHAR(100) NOT NULL,
    login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    logout_time TIMESTAMP,
    ip_address INET,
    session_duration INTERVAL,
    access_type VARCHAR(50),  -- 'LOGIN', 'QUERY', 'MODIFICATION'
    status VARCHAR(20) CHECK (status IN ('SUCCESS', 'FAILED')),
    failure_reason TEXT,
    database_accessed VARCHAR(100)
);

CREATE INDEX idx_user_access_time ON dba_admin.user_access_log(login_time DESC);
CREATE INDEX idx_user_access_user ON dba_admin.user_access_log(user_name);
CREATE INDEX idx_user_access_status ON dba_admin.user_access_log(status);

-- ============================================
-- 2. SECURITY AUDIT TABLES
-- ============================================

DROP TABLE IF EXISTS dba_admin.security_events CASCADE;
CREATE TABLE dba_admin.security_events (
    event_id BIGSERIAL PRIMARY KEY,
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    event_type VARCHAR(100) NOT NULL,  -- 'PERMISSION_CHANGE', 'FAILED_LOGIN', 'SENSITIVE_DATA_ACCESS'
    severity VARCHAR(20) CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    user_name VARCHAR(100),
    affected_object VARCHAR(255),
    action_description TEXT,
    response_action TEXT
);

CREATE INDEX idx_security_events_time ON dba_admin.security_events(event_time DESC);
CREATE INDEX idx_security_events_severity ON dba_admin.security_events(severity);
CREATE INDEX idx_security_events_type ON dba_admin.security_events(event_type);

-- ============================================
-- 3. CREATE DATABASE ROLES
-- ============================================

-- Admin role (full access)
DROP ROLE IF EXISTS db_admin CASCADE;
CREATE ROLE db_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA Finance TO db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Finance TO db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA Finance TO db_admin;
GRANT ALL PRIVILEGES ON SCHEMA Finance TO db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT ALL ON TABLES TO db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT ALL ON SEQUENCES TO db_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT ALL ON FUNCTIONS TO db_admin;

-- Read-only role
DROP ROLE IF EXISTS db_readonly CASCADE;
CREATE ROLE db_readonly;
GRANT USAGE ON SCHEMA Finance TO db_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA Finance TO db_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA Finance GRANT SELECT ON TABLES TO db_readonly;

-- Analyst role (read + reporting)
DROP ROLE IF EXISTS db_analyst CASCADE;
CREATE ROLE db_analyst;
GRANT USAGE ON SCHEMA Finance TO db_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA Finance TO db_analyst;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Finance TO db_analyst;

-- Application role (data import/export)
DROP ROLE IF EXISTS db_app CASCADE;
CREATE ROLE db_app;
GRANT USAGE ON SCHEMA Finance TO db_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA Finance TO db_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Finance TO db_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA Finance TO db_app;

-- Auditor role (audit logging access)
DROP ROLE IF EXISTS db_auditor CASCADE;
CREATE ROLE db_auditor;
GRANT USAGE ON SCHEMA Finance TO db_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA Finance TO db_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA dba_admin TO db_auditor;

-- ============================================
-- 4. CREATE DATABASE USERS
-- ============================================

-- Example users (change passwords in production)
DROP USER IF EXISTS admin_user CASCADE;
CREATE USER admin_user WITH PASSWORD 'change_me_in_production' IN ROLE db_admin;

DROP USER IF EXISTS app_user CASCADE;
CREATE USER app_user WITH PASSWORD 'change_me_in_production' IN ROLE db_app;

DROP USER IF EXISTS analyst_user CASCADE;
CREATE USER analyst_user WITH PASSWORD 'change_me_in_production' IN ROLE db_analyst;

DROP USER IF EXISTS readonly_user CASCADE;
CREATE USER readonly_user WITH PASSWORD 'change_me_in_production' IN ROLE db_readonly;

DROP USER IF EXISTS auditor_user CASCADE;
CREATE USER auditor_user WITH PASSWORD 'change_me_in_production' IN ROLE db_auditor;

-- ============================================
-- 5. PASSWORD POLICY FUNCTIONS
-- ============================================

DROP FUNCTION IF EXISTS dba_admin.validate_password_strength(VARCHAR) CASCADE;
CREATE FUNCTION dba_admin.validate_password_strength(p_password VARCHAR)
RETURNS TABLE(is_valid BOOLEAN, errors TEXT) AS $$
DECLARE
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Minimum length
    IF LENGTH(p_password) < 12 THEN
        v_errors := array_append(v_errors, 'Password must be at least 12 characters');
    END IF;
    
    -- Must contain uppercase
    IF p_password !~ '[A-Z]' THEN
        v_errors := array_append(v_errors, 'Password must contain uppercase letter');
    END IF;
    
    -- Must contain lowercase
    IF p_password !~ '[a-z]' THEN
        v_errors := array_append(v_errors, 'Password must contain lowercase letter');
    END IF;
    
    -- Must contain number
    IF p_password !~ '[0-9]' THEN
        v_errors := array_append(v_errors, 'Password must contain number');
    END IF;
    
    -- Must contain special character
    IF p_password !~ '[!@#$%^&*()_+\-=\[\]{};:,.<>?]' THEN
        v_errors := array_append(v_errors, 'Password must contain special character');
    END IF;
    
    RETURN QUERY SELECT 
        array_length(v_errors, 1) IS NULL,
        array_to_string(v_errors, '; ');
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. SECURITY MONITORING FUNCTIONS
-- ============================================

-- Log user access
DROP FUNCTION IF EXISTS dba_admin.log_user_access(VARCHAR, VARCHAR, INET, VARCHAR) CASCADE;
CREATE FUNCTION dba_admin.log_user_access(
    p_user_name VARCHAR,
    p_status VARCHAR,
    p_ip_address INET DEFAULT NULL,
    p_failure_reason VARCHAR DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_access_id BIGINT;
BEGIN
    INSERT INTO dba_admin.user_access_log (
        user_name, status, ip_address, failure_reason, access_type, database_accessed
    )
    VALUES (p_user_name, p_status, p_ip_address, p_failure_reason, 'LOGIN', current_database())
    RETURNING access_id INTO v_access_id;
    
    -- Log security event if failed
    IF p_status = 'FAILED' THEN
        PERFORM dba_admin.log_security_event(
            'FAILED_LOGIN', 'CRITICAL', p_user_name, 
            'Failed login attempt from ' || COALESCE(p_ip_address::TEXT, 'unknown'),
            p_failure_reason
        );
    END IF;
    
    RETURN v_access_id;
END;
$$ LANGUAGE plpgsql;

-- Log security event
DROP FUNCTION IF EXISTS dba_admin.log_security_event(VARCHAR, VARCHAR, VARCHAR, TEXT, TEXT) CASCADE;
CREATE FUNCTION dba_admin.log_security_event(
    p_event_type VARCHAR,
    p_severity VARCHAR,
    p_user_name VARCHAR,
    p_description TEXT,
    p_response_action TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_id BIGINT;
BEGIN
    INSERT INTO dba_admin.security_events (
        event_type, severity, user_name, action_description, response_action
    )
    VALUES (p_event_type, p_severity, p_user_name, p_description, p_response_action)
    RETURNING event_id INTO v_event_id;
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Get security violations
DROP FUNCTION IF EXISTS dba_admin.get_security_violations(INT) CASCADE;
CREATE FUNCTION dba_admin.get_security_violations(p_hours INT DEFAULT 24)
RETURNS TABLE(
    event_id BIGINT,
    event_time TIMESTAMP,
    event_type VARCHAR,
    severity VARCHAR,
    user_name VARCHAR,
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        se.event_id,
        se.event_time,
        se.event_type,
        se.severity,
        se.user_name,
        se.action_description
    FROM dba_admin.security_events se
    WHERE se.event_time > CURRENT_TIMESTAMP - (p_hours || ' hours')::INTERVAL
        AND se.severity IN ('WARNING', 'CRITICAL')
    ORDER BY se.event_time DESC;
END;
$$ LANGUAGE plpgsql;

-- Get user access history
DROP FUNCTION IF EXISTS dba_admin.get_user_access_history(VARCHAR, INT) CASCADE;
CREATE FUNCTION dba_admin.get_user_access_history(
    p_user_name VARCHAR,
    p_days INT DEFAULT 7
)
RETURNS TABLE(
    login_time TIMESTAMP,
    logout_time TIMESTAMP,
    ip_address INET,
    session_duration INTERVAL,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ual.login_time,
        ual.logout_time,
        ual.ip_address,
        ual.session_duration,
        ual.status
    FROM dba_admin.user_access_log ual
    WHERE ual.user_name = p_user_name
        AND ual.login_time > CURRENT_TIMESTAMP - (p_days || ' days')::INTERVAL
    ORDER BY ual.login_time DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verification
SELECT 'Security & Access Control Framework Successfully Installed' AS status;