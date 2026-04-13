#!/bin/bash

set -e

SCRIPT_DIR="."
DB_NAME="erp_postgres"
DB_USER="erp_admin"
CONTAINER_NAME="erp_db"
LOG_FILE="/var/log/erp-production.log"

echo "[$(date)] V2_staging_tablespace_testing" >> "$LOG_FILE"

# Run Startup SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/Reconcilliation.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Production Version 4 Recons SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Production Version 4 Recons SQL failed!" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Successful Staging" >> "$LOG_FILE"
