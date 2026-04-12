#!/bin/bash

set -e

SCRIPT_DIR="../tmp"
DB_NAME="erp_staging"
DB_USER="staging_user"
CONTAINER_NAME="staging_env"
LOG_FILE="/var/log/erp-V2-staging.log"

echo "[$(date)] V2_staging_tablespace_testing" >> "$LOG_FILE"

# Run Startup SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/01_Startup_staging.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging Startup SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging Startup SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/02_tables_staging.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging tables SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging tables SQL failed!" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Successful Staging" >> "$LOG_FILE"
