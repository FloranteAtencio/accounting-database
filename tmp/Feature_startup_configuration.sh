#!/bin/bash

set -e

SCRIPT_DIR="./tmp"
SCRIPT_DIR_SCHEMA="./schema/Version_2"
SCRIPT_DIR_FEATURE="./migration/Version_2"
DB_NAME="erp_dev"
DB_USER="dev_admin"
CONTAINER_NAME="feature_env"
LOG_FILE="/var/log/erp-staging.log"

echo "[$(date)] V2_staging_tablespace_testing" >> "$LOG_FILE"

# Run Startup SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/Feature_Startup_configuration.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature Startup SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Feature Startup SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/02_tables.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature table SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Feature tables SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/03_trigger.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature trigger SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Feature trigger SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/04_index.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature index SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Featue index SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/05_insert_procedure_businesslogic.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature insert procedure SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Featuer insert procedure SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/06_insert_event_procedure.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature event log   SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Feature event log SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/07_partitioning.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature partition tables SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Feature partition SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/08_Constraint.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature partition tables SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Feature partition SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/09_COA_role_accounts.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature partition tables SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Feature partition SQL failed!" >> "$LOG_FILE"
    exit 1
fi

# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/10_update_procedure_businesslogic.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature partition tables SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Feature partition SQL failed!" >> "$LOG_FILE"
    exit 1
fi


docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_FEATURE/features_tax.sql"
if [ $? -eq 0 ]; then
   echo "[$(date)] Sample Data Complete" >> "$LOG_FILE"
else
   echo "[$(date)] Sample Data Failed" >> "$LOG_FILE"
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_FEATURE/features_payroll.sql"
if [ $? -eq 0 ]; then
   echo "[$(date)] Sample Data Complete" >> "$LOG_FILE"
else
   echo "[$(date)] Sample Data Failed" >> "$LOG_FILE"
fi


docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/data_sample.sql"
if [ $? -eq 0 ]; then
   echo "[$(date)] Sample Data Complete" >> "$LOG_FILE"
else
   echo "[$(date)] Sample Data Failed" >> "$LOG_FILE"
fi


# Run Tables SQL
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/data_testing.sql"
if [ $? -eq 0 ]; then
    echo "[$(date)] Feature Constraint SQL alright!" >> "$LOG_FILE"
else
    echo "[$(date)] Feature Constraint SQL failed!" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Successful Feature" >> "$LOG_FILE"
#docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "SELECT 'Successful Query for Feature';"
