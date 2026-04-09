CREATE OR REPLACE FUNCTION partion_weekly_basis (tableselected text, schemaselected text)
RETURNS void AS $$
DECLARE

    s_date := date_trunc('week', current_date);
    e_date := s_date + interval '7 days';
    part_name text;
    
BEGIN

    part_name := schemaselected || '.' || tableselected || '_' || to_char(s_date, 'YYYY_MM') || 'wk' || extract(week from s_date);

    EXECUTE format(
        'CREATE TABLE %I PARTITION OF %I.%I 
        FOR VALUES FROM (%L) TO (%L);',
        part_name,schemaselected,tableselected,s_date,e_date
    );

END;
$$ LANGUAGE plgsql;

CREATE OR REPLACE FUNCTION partion_monthly_basis (tableselected text, schemaselected text)
RETURNS void AS $$
DECLARE

    s_date := date_trunc('month', current_date);
    e_date := s_date + interval '30 days';
    part_name text;
    
BEGIN

    part_name := schemaselected || '.' || tableselected || '_' || to_char(s_date, 'YYYY_MM') || 'wk' || extract(week from s_date);

    EXECUTE format(
        'CREATE TABLE %I PARTITION OF %I.%I 
        FOR VALUES FROM (%L) TO (%L);',
        part_name,schemaselected,tableselected,s_date,e_date
    );

END;
$$ LANGUAGE plpgsql;

-- 0 2 * * 0 docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select partion_monthly_basis('Finance','journals');"
-- 0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select partion_monthly_basis('Finance','accountpayables');"
-- 0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select partion_monthly_basis('Finance','accountreceivables');"
-- 0 2 1 * * docker exec -it erp_postgres psql -U erp_admin -d erp_db -c \ "Select partion_monthly_basis('Finance','inventoryaudits');"
