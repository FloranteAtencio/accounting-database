-- ============================================
-- 5. AUTO LINEAGE TRIGGER
-- ============================================
CREATE OR REPLACE FUNCTION Finance.auto_lineage_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN
        INSERT INTO Finance.record_lineage (
            table_name, record_id, client_id, source_type, 
            source_file, import_session_id, created_by
        ) VALUES (
            TG_TABLE_NAME, 
            NEW.id, 
            NEW.client_code, 
            'SPREADSHEET_IMPORT',
            current_setting('app.import_source_file', TRUE),
            current_setting('app.import_session_id')::INT,
            current_user
        );
    ELSE
        INSERT INTO Finance.record_lineage (
            table_name, record_id, client_id, source_type, created_by
        ) VALUES (
            TG_TABLE_NAME, NEW.id, NEW.client_code, 'MANUAL_ENTRY', current_user
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_lineage ON Staging.stg_ar_imports;
CREATE TRIGGER trg_auto_lineage
AFTER INSERT ON Staging.stg_ar_imports
FOR EACH ROW EXECUTE FUNCTION Finance.auto_lineage_trigger();
