BEGIN;

SELECT 'Payroll Tables loading';

CREATE TABLE Finance.payroll_imports (
    import_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    period_start DATE,
    period_end DATE,
    file_name VARCHAR(255),
    total_gross DECIMAL(15,2),
    total_net DECIMAL(15,2),
    status VARCHAR(20) DEFAULT 'UPLOADED', -- UPLOADED, PROCESSED, FAILED
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT 'Payroll tables loaded complete!';

COMMIT;