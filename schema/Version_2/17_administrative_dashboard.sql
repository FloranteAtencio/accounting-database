-- ============================================
-- 06_ADMINISTRATIVE_DASHBOARD_QUERIES.SQL
-- Purpose: Key queries for DBA dashboard
-- ============================================

-- ============================================
-- SECTION 1: SYSTEM HEALTH OVERVIEW
-- ============================================

-- Overall system health status
SELECT 
    'System Health Dashboard' as metric_category,
    COUNT(CASE WHEN status = 'HEALTHY' THEN 1 END) as healthy_checks,
    COUNT(CASE WHEN status = 'WARNING' THEN 1 END) as warning_checks,
    COUNT(CASE WHEN status = 'ALERT' THEN 1 END) as alert_checks
FROM dba_admin.performance_metrics
WHERE metric_timestamp > CURRENT_TIMESTAMP - INTERVAL '1 hour';

-- ============================================
-- SECTION 2: BACKUP & RECOVERY STATUS
-- ============================================

-- Recent backups
SELECT 
    backup_id,
    backup_date,
    backup_type,
    status,
    ROUND(backup_size_mb / 1024.0, 2) as size_gb,
    backup_duration_seconds,
    CASE WHEN restored_at IS NOT NULL THEN 'VERIFIED' ELSE 'PENDING TEST' END as verification_status
FROM dba_admin.backup_history
ORDER BY backup_date DESC
LIMIT 10;

-- Backup recovery readiness
SELECT * FROM dba_admin.get_backup_recovery_status();

-- ============================================
-- SECTION 3: PERFORMANCE METRICS
-- ============================================

-- Current performance health
SELECT * FROM dba_admin.get_performance_health_status();

-- Top slow queries
SELECT * FROM dba_admin.find_slow_queries(1000);

-- Database size trend
SELECT 
    DATE_TRUNC('hour', metric_timestamp) as time_bucket,
    ROUND(AVG(metric_value), 2) as avg_size_percent
FROM dba_admin.performance_metrics
WHERE metric_name = 'disk_space_used'
    AND metric_timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY time_bucket
ORDER BY time_bucket DESC;

-- ============================================
-- SECTION 4: SECURITY & ACCESS
-- ============================================

-- Security violations last 24 hours
SELECT * FROM dba_admin.get_security_violations(24);

-- Failed login attempts
SELECT 
    user_name,
    COUNT(*) as failed_count,
    MAX(login_time) as last_attempt
FROM dba_admin.user_access_log
WHERE status = 'FAILED'
    AND login_time > CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY user_name;

-- Active users
SELECT 
    usename,
    COUNT(*) as connection_count,
    MAX(query_start) as last_query
FROM pg_stat_activity
WHERE usename IS NOT NULL
GROUP BY usename
ORDER BY connection_count DESC;

-- ============================================
-- SECTION 5: HA/DR STATUS
-- ============================================

-- Current HA/DR status
SELECT * FROM dba_admin.get_ha_dr_status();

-- Replication lag history
SELECT 
    check_time,
    replication_lag_bytes,
    ROUND(replication_lag_seconds, 2) as lag_seconds,
    replication_status
FROM dba_admin.replication_status
ORDER BY check_time DESC
LIMIT 20;

-- Recent failover events
SELECT 
    event_id,
    event_time,
    from_server,
    to_server,
    reason,
    duration_seconds,
    status
FROM dba_admin.failover_recovery_log
ORDER BY event_time DESC
LIMIT 10;

-- ============================================
-- SECTION 6: STORAGE & CAPACITY
-- ============================================

-- Table sizes
SELECT 
    schemaname,
    tablename,
    ROUND(pg_total_relation_size(schemaname || '.' || tablename) / 1024.0 / 1024.0, 2) as size_mb,
    ROUND((pg_total_relation_size(schemaname || '.' || tablename) / 
           pg_database_size(current_database())::NUMERIC) * 100, 2) as pct_of_db
FROM pg_tables
WHERE schemaname = 'Finance'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;

-- Index efficiency
SELECT 
    table_name,
    index_name,
    ROUND(index_size_mb, 2) as size_mb,
    scan_count,
    bloat_ratio,
    is_unused,
    recommendation
FROM dba_admin.index_monitoring
WHERE checked_at > CURRENT_TIMESTAMP - INTERVAL '7 days'
ORDER BY index_size_mb DESC;

-- ============================================
-- SECTION 7: TRANSACTION ANALYSIS
-- ============================================

-- Long-running transactions
SELECT 
    pid,
    usename,
    pg_blocking_pids(pid) as blocking_pids,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start))::INT as seconds_running,
    query
FROM pg_stat_activity
WHERE state != 'idle'
    AND query_start < CURRENT_TIMESTAMP - INTERVAL '5 minutes'
ORDER BY query_start;

-- Transaction ID wraparound status
SELECT 
    datname,
    ROUND((2147483647 - next_xid) / 1000000.0, 2) as mxids_until_wraparound_millions,
    CASE WHEN (2147483647 - next_xid) < 100000000 THEN 'CRITICAL' 
         WHEN (2147483647 - next_xid) < 500000000 THEN 'WARNING'
         ELSE 'HEALTHY' END as status
FROM pg_database;

-- ============================================
-- SECTION 8: ALERTS & ANOMALIES
-- ============================================

-- Active alerts
SELECT 
    metric_name,
    COUNT(*) as alert_count,
    MAX(metric_timestamp) as latest_alert
FROM dba_admin.performance_metrics
WHERE status != 'HEALTHY'
    AND metric_timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY metric_name;

-- Performance degradation detection
SELECT 
    pm.metric_name,
    pb.baseline_value,
    pm.metric_value,
    ROUND((ABS(pm.metric_value - pb.baseline_value) / pb.baseline_value) * 100, 2) as deviation_percent,
    CASE WHEN ABS(pm.metric_value - pb.baseline_value) / pb.baseline_value > 0.2 THEN 'INVESTIGATE' 
         ELSE 'NORMAL' END as action
FROM dba_admin.performance_metrics pm
LEFT JOIN dba_admin.performance_baseline pb ON pm.metric_name = pb.metric_name
WHERE pm.metric_timestamp > CURRENT_TIMESTAMP - INTERVAL '1 hour'
    AND pb.baseline_value IS NOT NULL
ORDER BY deviation_percent DESC;

-- ============================================
-- SECTION 9: MAINTENANCE TRACKING
-- ============================================

-- Last vacuum/analyze times
SELECT 
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
WHERE schemaname = 'Finance'
ORDER BY last_vacuum DESC;

-- Maintenance recommendations
SELECT 
    schemaname || '.' || tablename as table_name,
    CASE WHEN last_vacuum IS NULL THEN 'Never vacuumed - RUN VACUUM'
         WHEN last_vacuum < CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 'Vacuum > 7 days old'
         ELSE 'OK' END as vacuum_status,
    CASE WHEN last_analyze IS NULL THEN 'Never analyzed - RUN ANALYZE'
         WHEN last_analyze < CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 'Analyze > 7 days old'
         ELSE 'OK' END as analyze_status,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
WHERE schemaname = 'Finance'
ORDER BY n_dead_tup DESC;

-- ============================================
-- SECTION 10: COMPLIANCE & AUDIT
-- ============================================

-- User access summary
SELECT 
    DATE_TRUNC('day', login_time) as access_date,
    user_name,
    COUNT(*) as total_logins,
    COUNT(*) FILTER (WHERE status = 'FAILED') as failed_logins
FROM dba_admin.user_access_log
WHERE login_time > CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY access_date, user_name
ORDER BY access_date DESC, user_name;

-- Audit trail summary
SELECT 
    event_type,
    severity,
    COUNT(*) as event_count,
    MAX(event_time) as latest_event
FROM dba_admin.security_events
WHERE event_time > CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY event_type, severity
ORDER BY latest_event DESC;