#!/bin/bash
# scripts/backup.sh

set -e  # Exit on error

# Configuration
BACKUP_DIR="/backup"
EXTERNAL_DRIVE="/mnt/external-backup"
CONTAINER_NAME="erp_postgres"
DB_USER="erp_admin"
DB_NAME="erp_db"
RETENTION_DAYS=30
LOG_FILE="/var/log/erp-backup.log"

# Create directories if they don't exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$EXTERNAL_DRIVE"

# Timestamp
TIMESTAMP=$(date +%F_%H-%M-%S)
BACKUP_FILE="erp_${TIMESTAMP}.sql"

echo "[$(date)] Starting backup..." >> "$LOG_FILE"

# 1. Backup to internal storage
echo "[$(date)] Backing up to internal storage: $BACKUP_DIR/$BACKUP_FILE" >> "$LOG_FILE"
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "[$(date)] ✓ Internal backup successful" >> "$LOG_FILE"
else
    echo "[$(date)] ✗ Internal backup failed" >> "$LOG_FILE"
    exit 1
fi

# 2. Compress backup
echo "[$(date)] Compressing backup..." >> "$LOG_FILE"
gzip "$BACKUP_DIR/$BACKUP_FILE"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

# 3. Copy to external drive
if [ -d "$EXTERNAL_DRIVE" ]; then
    echo "[$(date)] Copying to external drive: $EXTERNAL_DRIVE/$COMPRESSED_FILE" >> "$LOG_FILE"
    cp "$BACKUP_DIR/${COMPRESSED_FILE}" "$EXTERNAL_DRIVE/${COMPRESSED_FILE}"
    
    if [ $? -eq 0 ]; then
        echo "[$(date)] ✓ External backup successful" >> "$LOG_FILE"
    else
        echo "[$(date)] ✗ External backup failed" >> "$LOG_FILE"
    fi
else
    echo "[$(date)] ⚠ External drive not mounted" >> "$LOG_FILE"
fi

# 4. Cleanup old backups (keep last 30 days)
echo "[$(date)] Cleaning up old backups (older than $RETENTION_DAYS days)..." >> "$LOG_FILE"
find "$BACKUP_DIR" -name "erp_*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$EXTERNAL_DRIVE" -name "erp_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "[$(date)] ✓ Backup completed successfully" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"
