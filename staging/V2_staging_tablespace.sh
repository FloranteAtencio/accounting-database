#!/bin/bash

set -e 

SCRIPT_DIR="../tmp"
DB_NAME="erp_staging"
DB_USER="staging_user"
CONTAINER_NAME="stagin_env"
LOG_FILE="/var/log/erp-V2_staging.log"

mkdir -p "$SCRIPT_DIR"
touch -p "$LOG_FILE"

echo "[$(date)] V2_staginb_tablespace testing" >> "$LOG_FILE"

docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME < $SCRIPT_DIR/01_Startup_staging.sql
if [ $? -eq 0]; then
    echo "[$(date)] Staging Startup succesful" >> "$LOG_FILE"
else
    echo "[$(date)] Staging Startup Operation failed" >> "$LOG_FILE"
    exit 1
fi

docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME < $SCRIPT_DIR/02_tables_staging.sql
if [ $? -eq 0]; then
    echo "[$(date)] Staging Startup succesful" >> "$LOG_FILE"
else
    echo "[$(date)] Staging Startup Operation failed" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] succesful staging" >> "$LOG_FILE"