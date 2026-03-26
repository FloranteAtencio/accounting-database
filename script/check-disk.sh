#!/bin/bash
# scripts/check-disk.sh

set -e

# Configuration
INTERNAL_DIR="/var/lib/postgresql/data"
EXTERNAL_DRIVE="/mnt/external-backup"
LOG_FILE="/var/log/erp-disk-check.log"

echo "[$(date)] Checking disk space..." >> "$LOG_FILE"

# Internal storage
INTERNAL_USAGE=$(df -h "$INTERNAL_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
EXTERNAL_USAGE=$(df -h "$EXTERNAL_DRIVE" | awk 'NR==2 {print $5}' | sed 's/%//')

echo "[$(date)] Internal storage: $INTERNAL_USAGE% used" >> "$LOG_FILE"
echo "[$(date)] External drive: $EXTERNAL_USAGE% used" >> "$LOG_FILE"

# Alert if > 80%
if [ "$INTERNAL_USAGE" -gt 80 ] || [ "$EXTERNAL_USAGE" -gt 80 ]; then
    echo "[$(date)] ⚠ Disk space critical!" >> "$LOG_FILE"
    echo "Disk space critical! Internal: $INTERNAL_USAGE%, External: $EXTERNAL_USAGE%" | mail -s "Disk Space Alert" admin@example.com
fi

echo "[$(date)] ✓ Disk check completed" >> "$LOG_FILE"
