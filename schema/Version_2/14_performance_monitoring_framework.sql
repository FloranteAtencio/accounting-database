-- ============================================
-- 02_PERFORMANCE_MONITORING_FRAMEWORK.SQL
-- Purpose: Comprehensive performance monitoring
-- ============================================

BEGIN;

-- ============================================
-- 1. PERFORMANCE BASELINE TABLES
-- ============================================

DROP TABLE IF EXISTS dba_admin.performance_baseline CASCADE;
CREATE TABLE dba_admin.performance_baseline (
    metric_id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL UNIQUE,
    baseline_value NUMERIC NOT NULL,
    alert_threshold NUMERIC NOT NULL,
    warning_threshold NUMERIC,
    measurement_unit VARCHAR(50),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- Insert baseline metrics
INSERT INTO dba_admin.performance_baseline (
    metric_name, baseline_value, alert_threshold, warning_threshold, measurement_unit, notes
) VALUES
    ('avg_query_time', 100, 5000, 1000, 'milliseconds', 'Average query execution time'),
    ('cache_hit_ratio', 99, 90, 95, 'percent', 'Buffer cache hit ratio'),
    ('active_connections', 10, 50, 30, 'count', 'Active database connections'),
    ('disk_space_used', 50, 80, 70, 'percent', 'Disk space usage percentage'),
    ('table_bloat', 10, 50, 30, 'percent', 'Table bloat ratio'),
    ('index_bloat', 10, 50, 30, 'percent', 'Index bloat ratio'),
    ('checkpoint_duration', 100, 10000, 5000, 'milliseconds', 'Checkpoint duration');

-- ============================================
-- 2. REAL-TIME MONITORING TABLE
-- ============================================

DROP TABLE IF EXISTS dba_admin.performance_metrics CASCADE;
CREATE TABLE dba_admin.performance_metrics (
    metric_id BIGSERIAL PRIMARY KEY,
    metric_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metric_name VARCHAR(100) NOT NULL,
    metric_value NUMERIC NOT NULL,
    measurement_unit VARCHAR(50),
    status VARCHAR(20) CHECK (status IN ('HEALTHY', 'WARNING', 'ALERT')),
    baseline_value NUMERIC,
    deviation_percent NUMERIC
);

CREATE INDEX idx_performance_timestamp ON dba_admin.performance_metrics(metric_timestamp DESC);
CREATE INDEX idx_performance_metric_name ON dba_admin.performance_metrics(metric_name);
CREATE INDEX idx_performance_status ON dba_admin.performance_metrics(status);

-- ============================================
-- 3. SLOW QUERY LOG TABLE
-- ============================================

DROP TABLE IF EXISTS dba_admin.slow_query_log CASCADE;
CREATE TABLE dba_admin.slow_query_log (
    query_id BIGSERIAL PRIMARY KEY,
    query_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    query_text TEXT NOT NULL,
    execution_time_ms INT NOT NULL,
    rows_affected INT,
    rows_scanned INT,
    user_name VARCHAR(100),
    database_name VARCHAR(100),
    plans_explained TEXT,
    optimization_notes TEXT
);

CREATE INDEX idx_slow_query_time ON dba_admin.slow_query_log(execution_time_ms DESC);
CREATE INDEX idx_slow_query_timestamp ON dba_admin.slow_query_log(query_timestamp DESC);

-- ============================================
-- 4. INDEX MONITORING TABLE
-- ============================================

DROP TABLE IF EXISTS dba_admin.index_monitoring CASCADE;
CREATE TABLE dba_admin.index_monitoring (
    index_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    index_name VARCHAR(100) NOT NULL,
    index_size_mb NUMERIC,
    scan_count INT DEFAULT 0,
    bloat_ratio NUMERIC,
    last_analyzed TIMESTAMP,
    is_unused BOOLEAN DEFAULT FALSE,
    recommendation VARCHAR(255),
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_index_monitoring_table ON dba_admin.index_monitoring(table_name);
CREATE INDEX idx_index_monitoring_unused ON dba_admin.index_monitoring(is_unused);

-- ============================================
-- 5. PERFORMANCE MONITORING FUNCTIONS
-- ============================================

-- Collect current performance metrics
DROP FUNCTION IF EXISTS dba_admin.collect_performance_metrics() CASCADE;
CREATE FUNCTION dba_admin.collect_performance_metrics()
RETURNS TABLE(metrics_collected INT, status TEXT) AS $$
DECLARE
    v_count INT := 0;
    v_cache_hit NUMERIC;
    v_connections INT;
    v_disk_usage NUMERIC;
BEGIN
    -- Cache hit ratio
    SELECT 
        ROUND((1.0 - (SUM(heap_blks_read)::NUMERIC / 
        (SUM(heap_blks_read) + SUM(heap_blks_hit)))) * 100, 2)
    INTO v_cache_hit
    FROM pg_statio_user_tables;
    
    INSERT INTO dba_admin.performance_metrics (metric_name, metric_value, measurement_unit, status)
    VALUES ('cache_hit_ratio', COALESCE(v_cache_hit, 100), 'percent', 
            CASE WHEN COALESCE(v_cache_hit, 100) < 90 THEN 'ALERT' 
                 WHEN COALESCE(v_cache_hit, 100) < 95 THEN 'WARNING' 
                 ELSE 'HEALTHY' END);
    v_count := v_count + 1;
    
    -- Active connections
    SELECT COUNT(*) INTO v_connections FROM pg_stat_activity;
    INSERT INTO dba_admin.performance_metrics (metric_name, metric_value, measurement_unit, status)
    VALUES ('active_connections', v_connections, 'count',
            CASE WHEN v_connections > 50 THEN 'ALERT'
                 WHEN v_connections > 30 THEN 'WARNING'
                 ELSE 'HEALTHY' END);
    v_count := v_count + 1;
    
    -- Disk usage
    SELECT 
        ROUND((pg_database_size('accounting_db')::NUMERIC / 
        (SELECT pg_total_relation_size('accounting_db'::regclass) * 1.2)) * 100, 2)
    INTO v_disk_usage;
    INSERT INTO dba_admin.performance_metrics (metric_name, metric_value, measurement_unit, status)
    VALUES ('disk_space_used', COALESCE(v_disk_usage, 0), 'percent',
            CASE WHEN COALESCE(v_disk_usage, 0) > 80 THEN 'ALERT'
                 WHEN COALESCE(v_disk_usage, 0) > 70 THEN 'WARNING'
                 ELSE 'HEALTHY' END);
    v_count := v_count + 1;
    
    RETURN QUERY SELECT v_count, 'Metrics collected successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Analyze index usage and identify unused indexes
DROP FUNCTION IF EXISTS dba_admin.analyze_index_usage() CASCADE;
CREATE FUNCTION dba_admin.analyze_index_usage()
RETURNS TABLE(unused_count INT, bloated_count INT, recommendations_made INT) AS $$
DECLARE
    v_unused INT := 0;
    v_bloated INT := 0;
BEGIN
    -- Identify unused indexes
    INSERT INTO dba_admin.index_monitoring (
        table_name, index_name, index_size_mb, scan_count, 
        is_unused, recommendation
    )
    SELECT 
        t.relname,
        i.relname,
        ROUND(pg_relation_size(i.oid)::NUMERIC / 1024 / 1024, 2),
        COALESCE(x.idx_scan, 0),
        COALESCE(x.idx_scan, 0) = 0,
        CASE WHEN COALESCE(x.idx_scan, 0) = 0 THEN 'Consider dropping unused index' 
             ELSE 'Index is actively used' END
    FROM pg_class t
    JOIN pg_index ix ON t.oid = ix.indrelid
    JOIN pg_class i ON i.oid = ix.indexrelid
    LEFT JOIN pg_stat_user_indexes x ON i.oid = x.indexrelid
    WHERE t.relkind = 'r' AND i.relkind = 'i'
    AND t.schemaname = 'Finance';
    
    GET DIAGNOSTICS v_unused = ROW_COUNT;
    
    RETURN QUERY SELECT v_unused, v_bloated, v_unused;
END;
$$ LANGUAGE plpgsql;

-- Get performance health status
DROP FUNCTION IF EXISTS dba_admin.get_performance_health_status() CASCADE;
CREATE FUNCTION dba_admin.get_performance_health_status()
RETURNS TABLE(
    metric_name VARCHAR,
    current_value NUMERIC,
    baseline_value NUMERIC,
    threshold NUMERIC,
    status VARCHAR,
    last_updated TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pm.metric_name,
        pm.metric_value,
        pb.baseline_value,
        pb.alert_threshold,
        pm.status,
        pm.metric_timestamp
    FROM dba_admin.performance_metrics pm
    LEFT JOIN dba_admin.performance_baseline pb ON pm.metric_name = pb.metric_name
    WHERE pm.metric_timestamp > CURRENT_TIMESTAMP - INTERVAL '1 hour'
    ORDER BY pm.metric_timestamp DESC;
END;
$$ LANGUAGE plpgsql;

-- Find slow queries (uses pg_stat_activity - no extension required)
DROP FUNCTION IF EXISTS dba_admin.find_slow_queries(INT) CASCADE;
CREATE FUNCTION dba_admin.find_slow_queries(p_threshold_ms INT DEFAULT 1000)
RETURNS TABLE(
    query_text TEXT,
    total_time_ms BIGINT,
    calls INT,
    avg_time_ms NUMERIC,
    max_time_ms BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(query, 'N/A')::TEXT,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start))::BIGINT,
        1::INT,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start))::NUMERIC,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start))::BIGINT
    FROM pg_stat_activity
    WHERE query_start IS NOT NULL
        AND state = 'active'
        AND EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start)) * 1000 > p_threshold_ms
    ORDER BY query_start ASC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- Analyze query execution plan
DROP FUNCTION IF EXISTS dba_admin.analyze_query_plan(TEXT) CASCADE;
CREATE FUNCTION dba_admin.analyze_query_plan(p_query TEXT)
RETURNS TABLE(plan_line TEXT) AS $$
BEGIN
    RETURN QUERY
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS) ' || p_query;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. AUTOMATIC TABLE & INDEX ANALYSIS
-- ============================================

-- Vacuum and analyze all tables
DROP FUNCTION IF EXISTS dba_admin.optimize_all_tables() CASCADE;
CREATE FUNCTION dba_admin.optimize_all_tables()
RETURNS TABLE(table_name VARCHAR, status VARCHAR, duration_seconds INT) AS $$
DECLARE
    v_table RECORD;
    v_start_time TIMESTAMP;
    v_duration INT;
BEGIN
    FOR v_table IN 
        SELECT tablename FROM pg_tables WHERE schemaname = 'Finance'
    LOOP
        v_start_time := CURRENT_TIMESTAMP;
        
        EXECUTE 'VACUUM ANALYZE ' || quote_ident(v_table.tablename);
        
        v_duration := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time))::INT;
        
        RETURN QUERY SELECT 
            v_table.tablename::VARCHAR,
            'OPTIMIZED'::VARCHAR,
            v_duration;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verification
SELECT 'Performance Monitoring Framework Successfully Installed' AS status;
