#!/bin/bash

set -e

SCRIPT_DIR="./tmp"
SCRIPT_DIR_SCHEMA="./schema/Version_2_Flexible_Charts"
SCRIPT_DIR_STAGING="./migration/Version_2"
DB_NAME="erp_staging"
DB_USER="staging_user"
CONTAINER_NAME="staging_env"
LOG_FILE="/var/log/erp-staging.log"

echo "[$(date)] V2_staging_tablespace_testing" >> "$LOG_FILE"

# Run Startup SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/Staging_Startup_configuration.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging Startup SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging Startup SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/02_tables.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging table SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging tables SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/03_trigger.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging trigger SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging trigger SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/04_index.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging index SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging index SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/05_insert_procedure_businesslogic.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging insert procedure SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging insert procedure SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/06_insert_event_procedure.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging event log   SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging event log SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/07_partitioning.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging partition tables SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging partition SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/08_Constraint.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Staging Constraint SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Staging Constraint SQL failed!" >> "$LOG_FILE"
    exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/09_COA_role_accounts.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Sample Data SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Sample Data SQL failed! " >> "$LOG_FILE"
fi


docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/10_update_procedure_businesslogic.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Sample Data SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Sample Data SQL failed! " >> "$LOG_FILE"
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/sample_data.sql"
if [ $? -eq 0 ]; then
	echo "[$(date)] Sample Data SQL alright! " >> "$LOG_FILE"
else
	echo "[$(date)] Sample Data SQL failed! " >> "$LOG_FILE"
fi


docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/data_testing.sql"
if [ $? -eq 0 ]; then
	echo "[$(date)] Sample Data SQL alright! " >> "$LOG_FILE"
else
	echo "[$(date)] Sample Data SQL failed! " >> "$LOG_FILE"
fi


echo "[$(date)] Successful Feature" >> "$LOG_FILE"
#docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "SELECT 'Successful Query for Feature';"