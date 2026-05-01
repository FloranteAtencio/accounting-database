BEGIN;

SELECT '';

-- ============================================
-- TAX TYPES (Just a lookup for GL mapping)
-- ============================================
CREATE TABLE Finance.tax_types (
    tax_type_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    chart_id INT NOT NULL REFERENCES Finance.charts(chart_id), -- The Liability Account (e.g., "VAT Payable")
    tax_name VARCHAR(100) NOT NULL,
    tax_code VARCHAR(50) NOT NULL, -- e.g., "VAT_OUT", "VAT_IN"
    tax_rate DECIMAL(5,4) NOT NULL, -- Just a reference rate, not used for calculation logic
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(client_id, tax_code)
);

-- DROP the tax_liabilities table. 
-- The "Liability" is simply: 
-- SELECT SUM(credit) - SUM(debit) FROM journal_lines WHERE chart_id = (SELECT chart_id FROM tax_types WHERE tax_code = 'VAT_OUT');