-- Master initialization script
-- Runs all schema files in order

\i schema/01_Startup.sql
\i schema/02_tables.sql
\i schema/02.1_constraint.sql
\i schema/03_trigger.sql
\i schema/04_index.sql
\i schema/05_insert_function.sql
\i schema/06_update_function.sql
\i schema/07_select_function.sql

-- Verify schema created
SELECT 'Schema initialization complete!' as status;
