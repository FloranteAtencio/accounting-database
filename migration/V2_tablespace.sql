
CREATE TABLESPACE hotspace LOCATION '/mnt/ssd_hot';
CREATE TABLESPACE coldspace LOCATION '/mnt/hdd_cold';
 
BEGIN;
CREATE OR REPLACE FUNCTION alter_tables_space_weekly_basis(
    schemaselect text,
    tableselected text
)
RETURNS void AS $$
DECLARE
    start_date date := current_date - interval '7 days';
    part_name text;
BEGIN
    -- Example: journals_2026_03_wk11
    part_name := tableselected || '_' ||

                 to_char(start_date, 'YYYY_MM') || '_wk' ||
                 extract(week from start_date);

    EXECUTE format(
        'ALTER TABLE %I.%I SET TABLESPACE coldspace;',
        schemaselect,
        part_name
    );
END;
$$ LANGUAGE plpgsql;
COMMIT;


BEGIN;
CREATE OR REPLACE FUNCTION alter_tables_space_monthly_basis(
    schemaselect text,
    tableselected text
)
RETURNS void AS $$
DECLARE
    start_date date := current_date - interval '30 days';
    part_name text;
BEGIN
    -- Example: journals_2026_03_wk11
    part_name := tableselected || '_' ||

                 to_char(start_date, 'YYYY_MM') || '_wk' ||
                 extract(month from start_date);

    EXECUTE format(
        'ALTER TABLE %I.%I SET TABLESPACE coldspace;',
        schemaselect,
        part_name
    );
END;
$$ LANGUAGE plpgsql;
COMMIT;

BEGIN;
CREATE OR REPLACE FUNCTION partion_weekly_basis (tableselected text, schemaselected text)
RETURNS void AS $$
DECLARE

    s_date := date_trunc('week', current_date);
    e_date := s_date + interval '7 days';
    part_name text;
    
BEGIN

    part_name := shemaselected || '.' || tableselected || '_' || to_char(s_date, 'YYYY_MM') || 'wk' || extract(week from s_date);

    EXECUTE format(
        'CREATE TABLE %I PARTITION OF %I.%I 
        FOR VALUES FROM (%L) TO (%L)
        TABLESPACE hotspace;',
        part_name,schemaselected,tableselected,s_date,e_date
    );

END;
$$ LANGUAGE plpgsql;
COMMIT;

BEGIN;
CREATE OR REPLACE FUNCTION partion_monthly_basis (tableselected text, schemaselected text)
RETURNS void AS $$
DECLARE

    s_date := date_trunc('month', current_date);
    e_date := s_date + interval '30 days';
    part_name text;
    
BEGIN

    part_name := shemaselected || '.' || tableselected || '_' || to_char(s_date, 'YYYY_MM') || 'wk' || extract(month from s_date);

    EXECUTE format(
        'CREATE TABLE %I PARTITION OF %I.%I 
        FOR VALUES FROM (%L) TO (%L)
        TABLESPACE hotspace;',
        part_name,schemaselected,tableselected,s_date,e_date
    );

END;
$$ LANGUAGE plpgsql;
COMMIT;

-- 0 2 * * 0 docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select alter_tables_space_weekly_basis('Finance','journals');"
-- 0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select alter_tables_space_monthly_basis('Finance','accountpayables');"
-- 0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select alter_tables_space_monthly_basis('Finance','accountreceivables');"
-- 0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select alter_tables_space_monthly_basis('Finance','inventoryaudits');"

-- 0 2 * * 0 docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select partion_monthly_basis('Finance','journals');"
-- 0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select partion_monthly_basis('Finance','accountpayables');"
-- 0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select partion_monthly_basis('Finance','accountreceivables');"
-- 0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select partion_monthly_basis('Finance','inventoryaudits');"

-- CREATE OR REPLACE FUNCTION alter_tables_space_weekly_basis_counting_base_on_month(
--     schemaselect text,
--     tableselected text
-- )
-- RETURNS void AS $$
-- DECLARE
--     start_date date := current_date - interval '7 days';
--     month_start date := date_trunc('month', start_date);
--     week_number int;
--     part_name text;
-- BEGIN
--     -- Calculate week number relative to the month
--     week_number := ((extract(day from start_date) - 1) / 7)::int + 1;

--     -- Build partition name like journals_2026_03_wk1
--     part_name := tableselected || '_' ||
--                  to_char(start_date, 'YYYY_MM') || '_wk' ||
--                  week_number;

--     -- Move partition to coldspace
--     EXECUTE format(
--         'ALTER TABLE %I.%I SET TABLESPACE coldspace;',
--         schemaselect,
--         part_name
--     );
-- END;
-- $$ LANGUAGE plpgsql;
