#!/bin/bash

set -e

SCRIPT_DIR="./migration/V2_tablespace"
DB_NAME="erp_db"
DB_USER="erp_admin"
CONTAINER_NAME="erp_postgres"
LOG_FILE="/var/log/erp-production.log"

echo "[$(date)] V2_staging_tablespace_testing" >> "$LOG_FILE"

# Run Startup SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/01_location.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Production Version 2 locations SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Production Version 2 locations SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/02_function.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Production Version 2 function SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Production Version 2 function SQL failed!" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Successful Staging" >> "$LOG_FILE"
