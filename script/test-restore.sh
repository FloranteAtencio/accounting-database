#!/bin/bash
# scripts/test-restore.sh

set -e

# Configuration
BACKUP_DIR="/backup"
CONTAINER_NAME="erp_postgres"
DB_USER="erp_admin"
TEST_DB="test_restore"
LOG_FILE="/var/log/erp-test-restore.log"

echo "[$(date)] Starting test restore..." >> "$LOG_FILE"

# Get latest backup
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/erp_*.sql.gz 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "[$(date)] ✗ No backups found" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Using backup: $LATEST_BACKUP" >> "$LOG_FILE"

# Create test database
echo "[$(date)] Creating test database $TEST_DB..." >> "$LOG_FILE"
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -c "DROP DATABASE IF EXISTS $TEST_DB;"
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -c "CREATE DATABASE $TEST_DB;"

# Restore to test database
echo "[$(date)] Restoring to test database..." >> "$LOG_FILE"
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$TEST_DB" -f <(gunzip -c "$LATEST_BACKUP")

if [ $? -eq 0 ]; then
    echo "[$(date)] ✓ Test restore successful" >> "$LOG_FILE"
else
    echo "[$(date)] ✗ Test restore failed" >> "$LOG_FILE"
    exit 1
fi

# Verify data
echo "[$(date)] Verifying data..." >> "$LOG_FILE"
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$TEST_DB" -c "SELECT COUNT(*) FROM users LIMIT 1;"

echo "[$(date)] ✓ Test restore completed successfully" >> "$LOG_FILE"
