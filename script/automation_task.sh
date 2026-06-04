#!/bin/bash
# ============================================
# 05_DATABASE_AUTOMATION_TASKS.SH
# Purpose: Automated DBA tasks via cron
# ============================================

# Configuration
DB_NAME="accounting_db"
DB_USER="postgres"
BACKUP_DIR="/backups/accounting_db"
BACKUP_RETENTION_DAYS=30
LOG_DIR="/var/log/dba_admin"
ALERT_EMAIL="dba_accounting2023@gmail.com"

# Create directories
mkdir -p $BACKUP_DIR $LOG_DIR

# ============================================
# 1. DAILY FULL BACKUP (2:00 AM)
# ============================================
# Add to crontab: 0 2 * * * /opt/dba_scripts/backup_full.sh

perform_full_backup() {
    BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_full_$(date +%Y%m%d_%H%M%S).dump"
    LOG_FILE="$LOG_DIR/backup_$(date +%Y%m%d).log"
    
    echo "$(date): Starting full backup to $BACKUP_FILE" >> $LOG_FILE
    
    if pg_dump -Fc -d $DB_NAME > $BACKUP_FILE 2>> $LOG_FILE; then
        BACKUP_SIZE=$(du -sh $BACKUP_FILE | cut -f1)
        echo "$(date): Backup successful. Size: $BACKUP_SIZE" >> $LOG_FILE
        
        # Log to database
        psql -U $DB_USER -d $DB_NAME << EOF
            INSERT INTO dba_admin.backup_history (backup_type, backup_path, database_name, backup_size_mb, status)
            VALUES ('FULL', '$BACKUP_FILE', '$DB_NAME', $(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE") / 1024 / 1024, 'SUCCESS');
EOF
    else
        echo "$(date): Backup FAILED" >> $LOG_FILE
        echo "Database backup failed on $(hostname)" | mail -s "ALERT: DB Backup Failed" $ALERT_EMAIL
    fi
}

# ============================================
# 2. INCREMENTAL BACKUP (Every 6 hours)
# ============================================
# Add to crontab: 0 */6 * * * /opt/dba_scripts/backup_incremental.sh

perform_incremental_backup() {
    BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_incremental_$(date +%Y%m%d_%H%M%S).dump"
    LOG_FILE="$LOG_DIR/backup_$(date +%Y%m%d).log"
    
    echo "$(date): Starting incremental backup" >> $LOG_FILE
    
    # In production, use WAL-based incremental backups
    pg_dump -Fc -d $DB_NAME --exclude-table=audit_logs > $BACKUP_FILE 2>> $LOG_FILE
}

# ============================================
# 3. BACKUP CLEANUP (Daily - 3:00 AM)
# ============================================
# Add to crontab: 0 3 * * * /opt/dba_scripts/cleanup_backups.sh

cleanup_old_backups() {
    LOG_FILE="$LOG_DIR/cleanup_$(date +%Y%m%d).log"
    
    echo "$(date): Starting backup cleanup" >> $LOG_FILE
    
    # Delete backups older than retention period
    find $BACKUP_DIR -name "*.dump" -mtime +$BACKUP_RETENTION_DAYS -delete
    
    # Log to database
    psql -U $DB_USER -d $DB_NAME << EOF
        SELECT dba_admin.cleanup_old_backups($BACKUP_RETENTION_DAYS);
EOF
    
    echo "$(date): Cleanup completed" >> $LOG_FILE
}

# ============================================
# 4. PERFORMANCE METRICS COLLECTION (Every hour)
# ============================================
# Add to crontab: 0 * * * * /opt/dba_scripts/collect_metrics.sh

collect_performance_metrics() {
    LOG_FILE="$LOG_DIR/metrics_$(date +%Y%m%d).log"
    
    psql -U $DB_USER -d $DB_NAME >> $LOG_FILE 2>&1 << EOF
        SELECT dba_admin.collect_performance_metrics();
        SELECT dba_admin.analyze_index_usage();
EOF
}

# ============================================
# 5. TABLE & INDEX OPTIMIZATION (Weekly - Sunday 1:00 AM)
# ============================================
# Add to crontab: 0 1 * * 0 /opt/dba_scripts/optimize_tables.sh

optimize_all_tables() {
    LOG_FILE="$LOG_DIR/optimize_$(date +%Y%m%d).log"
    
    echo "$(date): Starting table optimization" >> $LOG_FILE
    
    psql -U $DB_USER -d $DB_NAME >> $LOG_FILE 2>&1 << EOF
        SELECT dba_admin.optimize_all_tables();
        REINDEX DATABASE $DB_NAME;
EOF
    
    echo "$(date): Optimization completed" >> $LOG_FILE
}

# ============================================
# 6. BACKUP RESTORE TEST (Monthly - 1st Sunday)
# ============================================
# Add to crontab: 0 4 * * 0 /opt/dba_scripts/test_restore.sh (first Sunday of month)

test_backup_restore() {
    LOG_FILE="$LOG_DIR/restore_test_$(date +%Y%m%d).log"
    TEST_DB="${DB_NAME}_restore_test"
    
    echo "$(date): Starting backup restore test" >> $LOG_FILE
    
    # Get latest backup
    LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.dump | head -1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        echo "$(date): No backup found" >> $LOG_FILE
        return
    fi
    
    # Drop test database if exists
    dropdb -U $DB_USER $TEST_DB 2>/dev/null
    
    # Restore to test database
    createdb -U $DB_USER $TEST_DB
    pg_restore -U $DB_USER -d $TEST_DB $LATEST_BACKUP >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
        echo "$(date): Restore test SUCCESSFUL" >> $LOG_FILE
        psql -U $DB_USER -d $DB_NAME << EOF
            UPDATE dba_admin.backup_history
            SET restored_at = CURRENT_TIMESTAMP,
                restore_status = 'SUCCESS'
            WHERE backup_path = '$LATEST_BACKUP'
            LIMIT 1;
EOF
        # Clean up test database
        dropdb -U $DB_USER $TEST_DB
    else
        echo "$(date): Restore test FAILED" >> $LOG_FILE
        echo "Backup restore test failed. Check $LOG_FILE" | mail -s "ALERT: Restore Test Failed" $ALERT_EMAIL
    fi
}

# ============================================
# 7. SECURITY AUDIT (Daily - 4:00 AM)
# ============================================
# Add to crontab: 0 4 * * * /opt/dba_scripts/security_audit.sh

run_security_audit() {
    LOG_FILE="$LOG_DIR/security_$(date +%Y%m%d).log"
    
    psql -U $DB_USER -d $DB_NAME >> $LOG_FILE 2>&1 << EOF
        -- Check for failed logins
        SELECT * FROM dba_admin.get_security_violations(24);
        
        -- Check user permissions
        SELECT usename, usesuper, usecreatedb FROM pg_user;
        
        -- Check for unusual activity
        SELECT COUNT(*) as failed_logins 
        FROM dba_admin.user_access_log 
        WHERE status = 'FAILED' 
        AND login_time > CURRENT_TIMESTAMP - INTERVAL '1 hour';
EOF
}

# ============================================
# 8. REPLICATION HEALTH CHECK (Every 15 minutes)
# ============================================
# Add to crontab: */15 * * * * /opt/dba_scripts/check_replication.sh

check_replication_health() {
    LOG_FILE="$LOG_DIR/replication_$(date +%Y%m%d).log"
    
    psql -U $DB_USER -d $DB_NAME >> $LOG_FILE 2>&1 << EOF
        SELECT dba_admin.check_replication_health();
        
        -- Alert if lag > 1 minute
        SELECT CASE 
            WHEN replication_lag_seconds > 60 THEN 
                'WARNING: Replication lag exceeds 1 minute: ' || replication_lag_seconds::TEXT
            ELSE 'Replication healthy'
        END
        FROM dba_admin.replication_status
        ORDER BY check_time DESC LIMIT 1;
EOF
}

# ============================================
# 9. MONTHLY FULL HEALTH CHECK (1st of month - 5:00 AM)
# ============================================
# Add to crontab: 0 5 1 * * /opt/dba_scripts/monthly_health_check.sh

monthly_health_check() {
    LOG_FILE="$LOG_DIR/monthly_health_$(date +%Y%m%d).log"
    REPORT_FILE="$LOG_DIR/monthly_report_$(date +%Y%m).txt"
    
    echo "=== MONTHLY DATABASE HEALTH REPORT ===" > $REPORT_FILE
    echo "Date: $(date)" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    
    psql -U $DB_USER -d $DB_NAME >> $REPORT_FILE 2>&1 << EOF
        -- Database size
        SELECT 'Database Size', pg_size_pretty(pg_database_size('$DB_NAME'));
        
        -- Performance health
        SELECT * FROM dba_admin.get_performance_health_status();
        
        -- Backup status
        SELECT * FROM dba_admin.get_backup_recovery_status();
        
        -- HA/DR status
        SELECT * FROM dba_admin.get_ha_dr_status();
        
        -- Security violations
        SELECT * FROM dba_admin.get_security_violations(720);  -- Last 30 days
        
        -- Slow queries
        SELECT * FROM dba_admin.find_slow_queries(5000);
        
        -- Unused indexes
        SELECT * FROM dba_admin.index_monitoring WHERE is_unused = TRUE;
EOF
    
    # Email report
    mail -s "Monthly Database Health Report" $ALERT_EMAIL < $REPORT_FILE
}

# ============================================
# 10. ARCHIVE WAL LOGS (Every 5 minutes)
# ============================================
# Add to crontab: */5 * * * * /opt/dba_scripts/archive_wal.sh

archive_wal_logs() {
    # Set in postgresql.conf:
    # archive_mode = on
    # archive_command = '/opt/dba_scripts/archive_wal.sh %p %f'
    
    LOG_DIR="/var/log/postgresql/wal_archive"
    mkdir -p $LOG_DIR
    
    # Copy to archive directory
    cp "$1" "/archive/wal_logs/$2"
    
    # Optional: Copy to remote location
    # scp "$1" backup_server:/backups/wal_archive/
    
    exit 0
}

# ============================================
# CRONTAB SCHEDULE REFERENCE
# ============================================
# 
# 0 2 * * *   /opt/dba_scripts/backup_full.sh              (Daily 2:00 AM)
# 0 */6 * * * /opt/dba_scripts/backup_incremental.sh       (Every 6 hours)
# 0 3 * * *   /opt/dba_scripts/cleanup_backups.sh          (Daily 3:00 AM)
# 0 * * * *   /opt/dba_scripts/collect_metrics.sh          (Hourly)
# 0 1 * * 0   /opt/dba_scripts/optimize_tables.sh          (Weekly Sunday 1:00 AM)
# 0 4 * * 0   /opt/dba_scripts/test_restore.sh             (Weekly Sunday 4:00 AM)
# 0 4 * * *   /opt/dba_scripts/security_audit.sh           (Daily 4:00 AM)
# */15 * * *  /opt/dba_scripts/check_replication.sh        (Every 15 minutes)
# 0 5 1 * *   /opt/dba_scripts/monthly_health_check.sh    (Monthly 1st, 5:00 AM)

# Execute based on script name
SCRIPT_NAME=$(basename "$0")
case $SCRIPT_NAME in
    backup_full.sh) perform_full_backup ;;
    backup_incremental.sh) perform_incremental_backup ;;
    cleanup_backups.sh) cleanup_old_backups ;;
    collect_metrics.sh) collect_performance_metrics ;;
    optimize_tables.sh) optimize_all_tables ;;
    test_restore.sh) test_backup_restore ;;
    security_audit.sh) run_security_audit ;;
    check_replication.sh) check_replication_health ;;
    monthly_health_check.sh) monthly_health_check ;;
    *) echo "Unknown script"; exit 1 ;;
esac