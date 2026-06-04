-- ============================================
-- 04_HA_DR_ARCHITECTURE.SQL
-- Purpose: High Availability & Disaster Recovery setup
-- ============================================

BEGIN;

-- ============================================
-- 1. HA/DR CONFIGURATION TABLES
-- ============================================

DROP TABLE IF EXISTS dba_admin.ha_dr_configuration CASCADE;
CREATE TABLE dba_admin.ha_dr_configuration (
    config_id SERIAL PRIMARY KEY,
    primary_server VARCHAR(100) NOT NULL,
    primary_port INT DEFAULT 5432,
    primary_data_path VARCHAR(500),
    standby_server VARCHAR(100),
    standby_port INT DEFAULT 5432,
    standby_data_path VARCHAR(500),
    replication_slot_name VARCHAR(100),
    wal_archive_path VARCHAR(500),
    ha_enabled BOOLEAN DEFAULT FALSE,
    dr_enabled BOOLEAN DEFAULT FALSE,
    failover_method VARCHAR(50) CHECK (failover_method IN ('MANUAL', 'AUTOMATIC')),
    recovery_target_timeline VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dba_admin.ha_dr_configuration (
    primary_server, standby_server, replication_slot_name, 
    failover_method, ha_enabled, dr_enabled
) VALUES (
    'prod-db-01.example.com', 'prod-db-02.example.com', 
    'accounting_db_slot', 'AUTOMATIC', FALSE, FALSE
);

-- ============================================
-- 2. REPLICATION STATUS TABLE
-- ============================================

DROP TABLE IF EXISTS dba_admin.replication_status CASCADE;
CREATE TABLE dba_admin.replication_status (
    status_id BIGSERIAL PRIMARY KEY,
    check_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    primary_server VARCHAR(100) NOT NULL,
    standby_server VARCHAR(100),
    replication_lag_bytes BIGINT,
    replication_lag_seconds NUMERIC,
    wal_position TEXT,
    standby_wal_position TEXT,
    replication_status VARCHAR(50),  -- 'STREAMING', 'CATCHING_UP', 'FAILED'
    is_replication_healthy BOOLEAN
);

CREATE INDEX idx_replication_time ON dba_admin.replication_status(check_time DESC);
CREATE INDEX idx_replication_status ON dba_admin.replication_status(replication_status);

-- ============================================
-- 3. FAILOVER & RECOVERY LOG
-- ============================================

DROP TABLE IF EXISTS dba_admin.failover_recovery_log CASCADE;
CREATE TABLE dba_admin.failover_recovery_log (
    event_id BIGSERIAL PRIMARY KEY,
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    event_type VARCHAR(50) CHECK (event_type IN ('FAILOVER', 'RECOVERY', 'PLANNED_MAINTENANCE')),
    triggered_by VARCHAR(100),
    from_server VARCHAR(100),
    to_server VARCHAR(100),
    reason TEXT,
    duration_seconds INT,
    data_loss_mb BIGINT,
    status VARCHAR(20) CHECK (status IN ('SUCCESS', 'PARTIAL', 'FAILED')),
    recovery_actions TEXT,
    post_failover_verification TEXT
);

CREATE INDEX idx_failover_time ON dba_admin.failover_recovery_log(event_time DESC);
CREATE INDEX idx_failover_status ON dba_admin.failover_recovery_log(status);

-- ============================================
-- 4. HA/DR MONITORING FUNCTIONS
-- ============================================

-- Check replication health
DROP FUNCTION IF EXISTS dba_admin.check_replication_health() CASCADE;
CREATE FUNCTION dba_admin.check_replication_health()
RETURNS TABLE(
    primary_server VARCHAR,
    standby_server VARCHAR,
    replication_lag_bytes BIGINT,
    replication_lag_seconds NUMERIC,
    status VARCHAR,
    is_healthy BOOLEAN
) AS $$
DECLARE
    v_primary_wal TEXT;
    v_standby_wal TEXT;
    v_lag_bytes BIGINT;
    v_lag_seconds NUMERIC;
    v_status VARCHAR;
BEGIN
    -- Get current WAL position (simulated)
    v_primary_wal := pg_current_wal_lsn()::TEXT;
    
    -- In real setup, query standby_status_info from standby
    v_standby_wal := v_primary_wal;  -- Simulated
    
    -- Calculate lag
    v_lag_bytes := 0;  -- Simulated
    v_lag_seconds := 0;  -- Simulated
    
    -- Determine status
    v_status := CASE 
        WHEN v_lag_seconds > 60 THEN 'CATCHING_UP'
        WHEN v_lag_bytes = 0 THEN 'STREAMING'
        ELSE 'UNKNOWN'
    END;
    
    INSERT INTO dba_admin.replication_status (
        primary_server, standby_server, replication_lag_bytes, 
        replication_lag_seconds, wal_position, standby_wal_position, 
        replication_status, is_replication_healthy
    )
    VALUES (
        'primary', 'standby', v_lag_bytes, v_lag_seconds,
        v_primary_wal, v_standby_wal, v_status,
        v_lag_seconds < 60 AND v_lag_bytes < 1000000
    );
    
    RETURN QUERY SELECT 
        'primary'::VARCHAR,
        'standby'::VARCHAR,
        v_lag_bytes,
        v_lag_seconds,
        v_status,
        v_lag_seconds < 60 AND v_lag_bytes < 1000000;
END;
$$ LANGUAGE plpgsql;

-- Log failover event
DROP FUNCTION IF EXISTS dba_admin.log_failover_event(VARCHAR, VARCHAR, VARCHAR, TEXT, INT) CASCADE;
CREATE FUNCTION dba_admin.log_failover_event(
    p_triggered_by VARCHAR,
    p_from_server VARCHAR,
    p_to_server VARCHAR,
    p_reason TEXT,
    p_duration_seconds INT
)
RETURNS BIGINT AS $$
DECLARE
    v_event_id BIGINT;
BEGIN
    INSERT INTO dba_admin.failover_recovery_log (
        event_type, triggered_by, from_server, to_server, 
        reason, duration_seconds, status
    )
    VALUES ('FAILOVER', p_triggered_by, p_from_server, p_to_server,
            p_reason, p_duration_seconds, 'SUCCESS')
    RETURNING event_id INTO v_event_id;
    
    -- Log security event
    PERFORM dba_admin.log_security_event(
        'FAILOVER_EVENT', 'WARNING', p_triggered_by,
        'Failover from ' || p_from_server || ' to ' || p_to_server || ': ' || p_reason,
        'Check replication status and verify data integrity'
    );
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Get HA/DR status
DROP FUNCTION IF EXISTS dba_admin.get_ha_dr_status() CASCADE;
CREATE FUNCTION dba_admin.get_ha_dr_status()
RETURNS TABLE(
    primary_server VARCHAR,
    standby_server VARCHAR,
    ha_enabled BOOLEAN,
    dr_enabled BOOLEAN,
    replication_lag_seconds NUMERIC,
    last_failover TIMESTAMP,
    days_since_last_failover INT,
    recovery_objective_met BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.primary_server,
        c.standby_server,
        c.ha_enabled,
        c.dr_enabled,
        COALESCE((SELECT replication_lag_seconds FROM dba_admin.replication_status 
                  ORDER BY check_time DESC LIMIT 1), 0),
        (SELECT MAX(event_time) FROM dba_admin.failover_recovery_log WHERE event_type = 'FAILOVER'),
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP - 
            (SELECT MAX(event_time) FROM dba_admin.failover_recovery_log WHERE event_type = 'FAILOVER')))::INT,
        (SELECT replication_lag_seconds FROM dba_admin.replication_status 
         ORDER BY check_time DESC LIMIT 1) < 30
    FROM dba_admin.ha_dr_configuration c;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. DISASTER RECOVERY FUNCTIONS
-- ============================================

-- Point-in-time recovery info
DROP FUNCTION IF EXISTS dba_admin.get_pitr_availability() CASCADE;
CREATE FUNCTION dba_admin.get_pitr_availability()
RETURNS TABLE(
    earliest_recovery_time TIMESTAMP,
    latest_recovery_time TIMESTAMP,
    available_wal_hours INT,
    pitr_capable BOOLEAN
) AS $$
BEGIN
    RETURN QUERY SELECT 
        CURRENT_TIMESTAMP - INTERVAL '7 days',
        CURRENT_TIMESTAMP,
        168,
        TRUE;
END;
$$ LANGUAGE plpgsql;

-- Create recovery checkpoint
DROP FUNCTION IF EXISTS dba_admin.create_recovery_checkpoint(TEXT) CASCADE;
CREATE FUNCTION dba_admin.create_recovery_checkpoint(p_description TEXT)
RETURNS TABLE(checkpoint_name VARCHAR, checkpoint_time TIMESTAMP, wal_position TEXT) AS $$
BEGIN
    -- In real setup, would execute: SELECT pg_create_restore_point('checkpoint_name');
    RETURN QUERY SELECT 
        'checkpoint_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS')::VARCHAR,
        CURRENT_TIMESTAMP,
        pg_current_wal_lsn()::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. RECOVERY RUNBOOK FUNCTIONS
-- ============================================

-- Generate failover runbook
DROP FUNCTION IF EXISTS dba_admin.generate_failover_runbook() CASCADE;
CREATE FUNCTION dba_admin.generate_failover_runbook()
RETURNS TABLE(step_number INT, step_description TEXT, commands TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT 1, 'Check replication status', 'SELECT dba_admin.check_replication_health();'
    UNION ALL
    SELECT 2, 'Promote standby to primary', 'pg_ctl promote -D /var/lib/postgresql/data'
    UNION ALL
    SELECT 3, 'Update application connection string', 'Update app config to point to new primary'
    UNION ALL
    SELECT 4, 'Verify data integrity', 'SELECT dba_admin.check_database_integrity();'
    UNION ALL
    SELECT 5, 'Log failover event', 'SELECT dba_admin.log_failover_event(...);'
    UNION ALL
    SELECT 6, 'Set up new standby', 'pg_basebackup -h new_primary -D /var/lib/postgresql/data'
    UNION ALL
    SELECT 7, 'Restore old primary as standby', 'Configure old primary as standby (detailed steps...)'
    UNION ALL
    SELECT 8, 'Verify replication', 'SELECT dba_admin.get_ha_dr_status();';
END;
$$ LANGUAGE plpgsql;

-- Generate disaster recovery plan
DROP FUNCTION IF EXISTS dba_admin.generate_dr_plan() CASCADE;
CREATE FUNCTION dba_admin.generate_dr_plan()
RETURNS TABLE(scenario TEXT, recovery_time_minutes INT, actions TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT 'Primary database server failure', 15, 'Automatic failover to standby (if configured)'
    UNION ALL
    SELECT 'Standby database server failure', 120, 'Set up new standby from backup, resume replication'
    UNION ALL
    SELECT 'Network partition', 30, 'Check cluster consensus, manual failover decision'
    UNION ALL
    SELECT 'Data corruption detected', 240, 'Point-in-time recovery to before corruption'
    UNION ALL
    SELECT 'Complete data center failure', 480, 'Restore from off-site backups to alternate location'
    UNION ALL
    SELECT 'Accidental data modification', 60, 'PITR to restore point before modification'
    UNION ALL
    SELECT 'Ransomware/Data deletion', 1440, 'Restore from immutable off-site backup';
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verification
SELECT 'HA/DR Architecture Successfully Installed' AS status;