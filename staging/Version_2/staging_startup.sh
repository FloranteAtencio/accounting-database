#!/bin/bash

set -e

SCRIPT_DIR="./tmp"
SCRIPT_DIR_SCHEMA="./schema/Version_2"
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
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_SCHEMA/10_update_procedure_businesslogic.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Sample Data SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Sample Data SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/data_sample.sql"
if [ $? -eq 0 ]; then
	echo "[$(date)] Sample Data SQL alright! " >> "$LOG_FILE"
else
	echo "[$(date)] Sample Data SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR/data_testing.sql"
if [ $? -eq 0 ]; then
	echo "[$(date)] Sample Data SQL alright! " >> "$LOG_FILE"
else
	echo "[$(date)] Sample Data SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_STAGING/reconcile/features_reconciliation.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Reconciliation Table SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Reconciliation Table SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_STAGING/reconcile/features_reconciliation_procedure.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Recon procedure SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Recon procedure SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_STAGING/reconcile/features_recon_sample_data.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Recon Sample data SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Recon sample data SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_STAGING/recurring/features_recurring.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Recurring Table SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Recurring table SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_STAGING/recurring/features_recurring_procedure.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Recurring procedure SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Recurring procedure SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_STAGING/taxation/features_tax.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Tax Table SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Tax Table SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_STAGING/taxation/features_tax_sample_data.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Tax Data SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Tax Data SQL failed! " >> "$LOG_FILE"
        exit 1
fi

docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$SCRIPT_DIR_STAGING/payroll/features_payroll.sql"
if [ $? -eq 0 ]; then
        echo "[$(date)] Payroll tables SQL alright! " >> "$LOG_FILE"
else
        echo "[$(date)] Payroll tables SQL failed! " >> "$LOG_FILE"
        exit 1
fi

echo "[$(date)] Successful Feature" >> "$LOG_FILE"
#docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "SELECT 'Successful Query for Feature';"