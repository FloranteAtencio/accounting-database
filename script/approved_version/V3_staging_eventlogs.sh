#!/bin/bash

set -e

SCRIPT_DIR="../../migration/V3_eventlogs"
DB_NAME="erp_db"
DB_USER="erp_admin"
CONTAINER_NAME="erp_postgres"
LOG_FILE="/var/log/erp-production.log"

echo "[$(date)] V2_staging_tablespace_testing" >> "$LOG_FILE"

# Run Startup SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/01_table.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Production Version 2 tables SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Production Version 2 tables SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/02_altertable.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Production Version 2 alter tables SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Production Version 2 alter tables SQL failed!" >> "$LOG_FILE"
    exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/03_sample_data.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Production Version 2 sample data SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Production Version 2 sample data SQL failed!" >> "$LOG_FILE"
    exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/04_procedure.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Production Version 2 procedure SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Production Version 2 procedure SQL failed!" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Successful Staging" >> "$LOG_FILE"
