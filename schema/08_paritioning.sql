CREATE OR REPLACE FUNCTION Finance.partion_weekly_basis (tableselected text, schemaselected text)
RETURNS void AS $$
DECLARE
    s_date date := date_trunc('week', current_date);
    e_date date := s_date + interval '7 days';
    part_name text;    
BEGIN

    part_name := schemaselected || '.' || tableselected || '_' || to_char(s_date, 'YYYY_MM') || 'wk' || extract(week from s_date);

    EXECUTE format(
        'CREATE TABLE %I PARTITION OF %I.%I 
        FOR VALUES FROM (%L) TO (%L);',
        part_name,schemaselected,tableselected,s_date,e_date
    );

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Finance.partion_monthly_basis (tableselected text, schemaselected text)
RETURNS void AS $$
DECLARE

    s_date date := date_trunc('month', current_date);
    e_date date := s_date + interval '30 days';
    part_name text;
    
BEGIN
    BEGIN
    part_name := schemaselected || '.' || tableselected || '_' || to_char(s_date, 'YYYY_MM') || 'wk' || extract(week from s_date);

    EXECUTE format(
        'CREATE TABLE %I PARTITION OF %I.%I 
        FOR VALUES FROM (%L) TO (%L);',
        part_name,schemaselected,tableselected,s_date,e_date
    );
    
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
