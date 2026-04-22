#!/bin/bash
# script/back_up_alert.sh

LOG_FILE="/var/log/erp-backup.log"
BACKUP_STATUS=$(tail -1 "$LOG_FILE" | grep -c "✓ Backup completed")

if [ "$BACKUP_STATUS" -eq 0 ]; then
    echo "❌ ALERT: Last backup failed!" | mail -s "ERP Backup Alert" Administrator@beekkeepers.com
    exit 1
else
    echo "✅ Backup successful at $(date)" | mail -s "ERP Backup Confirmed" Administrator@beekkeepers.com
fi