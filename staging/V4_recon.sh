#!/bin/bash

set -e

SCRIPT_DIR="../migration/V4_recon"
DB_NAME="erp_staging"
DB_USER="staging_user"
CONTAINER_NAME="staging_env"
LOG_FILE="/var/log/erp-staging.log"

echo "[$(date)] V2_staging_tablespace_testing" >> "$LOG_FILE"

# Run Startup SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/Reconcilliation.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging Recon QL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging Recon SQL failed!" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Successful Staging" >> "$LOG_FILE"
