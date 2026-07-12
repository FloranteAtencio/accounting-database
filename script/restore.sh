#!/bin/bash
# script/restore.sh

set -e

# Configuration
BACKUP_DIR="../backup"
CONTAINER_NAME="erp_postgres"
DB_USER="erp_admin"
DB_NAME="erp_db"
LOG_FILE="/var/log/erp-restore.log"

echo "[$(date)] Starting restore process..." >> "$LOG_FILE"

# Check if backup file provided
if [ -z "$1" ]; then
    echo "Usage: $0 <backup-file>"
    echo "Example: $0 erp_2026-03-20_02-00-00.sql.gz"
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/erp_*.sql.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

# Verify backup exists
if [ ! -f "$BACKUP_PATH" ]; then
    echo "[$(date)] ✗ Backup file not found: $BACKUP_PATH" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Restoring from: $BACKUP_PATH" >> "$LOG_FILE"

# Check if compressed
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo "[$(date)] De-compressing backup..." >> "$LOG_FILE"
    gunzip -c "$BACKUP_PATH" > "$BACKUP_DIR/restore_temp.sql"
    BACKUP_PATH="$BACKUP_DIR/restore_temp.sql"
fi

# Drop and recreate database
echo "[$(date)] Dropping database $DB_NAME..." >> "$LOG_FILE"
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"

echo "[$(date)] Creating database $DB_NAME..." >> "$LOG_FILE"
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"

# Restore
echo "[$(date)] Restoring database..." >> "$LOG_FILE"
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$BACKUP_PATH"

if [ $? -eq 0 ]; then
    echo "[$(date)] ✓ Restore successful" >> "$LOG_FILE"
else
    echo "[$(date)] ✗ Restore failed" >> "$LOG_FILE"
    exit 1
fi

# Clean up temp file
if [[ "$BACKUP_FILE" == *.gz ]]; then
    rm "$BACKUP_DIR/restore_temp.sql"
fi

echo "[$(date)] ✓ Restore completed successfully" >> "$LOG_FILE"