BEGIN;

SELECT 'TAX TABLE';
-- ============================================
-- TAX CONFIGURATIONS
-- ============================================
CREATE TABLE Finance.tax_types (
    tax_type_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    tax_name VARCHAR(255) NOT NULL,  -- e.g., "VAT", "Sales Tax", "Income Tax"
    tax_code VARCHAR(50) NOT NULL,
    tax_rate DECIMAL(5,2) NOT NULL,   -- e.g., 12.00 for 12%
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_id, tax_code)
);


-- ============================================
-- TAX LIABILITY TRACKING
-- ============================================
CREATE TABLE Finance.tax_liabilities (
    liability_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    tax_type_id INT NOT NULL REFERENCES Finance.tax_types(tax_type_id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_taxable_amount DECIMAL(15,2) NOT NULL,
    total_tax_owed DECIMAL(15,2) NOT NULL,
    total_tax_paid DECIMAL(15,2) DEFAULT 0,
    balance_due DECIMAL(15,2) NOT NULL,
    due_date DATE,
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'PAID', 'PARTIAL', 'OVERDUE')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_id, tax_type_id, period_start, period_end)
);

SELECT 'Tax tables load complete!';
COMMIT;