docker exec -i staging_env psql -U staging_user -d erp_staging < ../tmp/01_Startup_staging.sql
docker exec -i staging_env psql -U staging_user -d erp_staing  < ../tmp/02_tables_staging.sql
