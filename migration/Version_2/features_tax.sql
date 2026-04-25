BEGIN;

SELECT 'TAX TABLE';
-- ============================================
-- 1. TAX CONFIGURATIONS
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
-- 2. TAX APPLICABILITY RULES
-- ============================================
CREATE TABLE Finance.tax_rules (
    rule_id BIGSERIAL PRIMARY KEY,
    tax_type_id INT NOT NULL REFERENCES Finance.tax_types(tax_type_id),
    chart_id INT REFERENCES Finance.charts(chart_id),  -- Applied to which account?
    applies_to VARCHAR(50) NOT NULL CHECK (applies_to IN ('SALES', 'PURCHASES', 'EXPENSES', 'ALL')),
    min_amount DECIMAL(15,2) DEFAULT 0,
    max_amount DECIMAL(15,2),
    jurisdiction VARCHAR(100),  -- e.g., "Philippines", "USA-California"
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 3. TAX CALCULATIONS (Audit trail)
-- ============================================
CREATE TABLE Finance.tax_calculations (
    calc_id BIGSERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES Finance.transactions(transaction_id),
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    tax_type_id INT NOT NULL REFERENCES Finance.tax_types(tax_type_id),
    base_amount DECIMAL(15,2) NOT NULL,    -- Amount before tax
    tax_rate DECIMAL(5,2) NOT NULL,        -- Rate applied
    tax_amount DECIMAL(15,2) NOT NULL,     -- Calculated tax
    is_payable BOOLEAN NOT NULL,           -- Is it owed or is it paid?
    due_date DATE,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'OVERDUE', 'REVERSED')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_date TIMESTAMP
);

-- ============================================
-- 4. TAX LIABILITY TRACKING
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
SELECT 'TAX TABLE COMPLETE';

COMMIT;