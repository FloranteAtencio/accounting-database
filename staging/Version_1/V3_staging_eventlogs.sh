#!/bin/bash

set -e

SCRIPT_DIR="../migration/V3_eventlogs"
DB_NAME="erp_staging"
DB_USER="staging_user"
CONTAINER_NAME="staging_env"
LOG_FILE="/var/log/erp-staging.log"

echo "[$(date)] V2_staging_tablespace_testing" >> "$LOG_FILE"

# Run Startup SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/01_tables.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging Startup SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging Startup SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/02_altertables.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging alter table SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging alter table SQL failed!" >> "$LOG_FILE"
    exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/03_sample_data.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging sample SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging sample SQL failed!" >> "$LOG_FILE"
    exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/04_procedure.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging procedure SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging procedure SQL failed!" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Successful Staging" >> "$LOG_FILE"
