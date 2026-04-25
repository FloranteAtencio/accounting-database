SELECT 'TAX DATA';
BEGIN;

-- ============================================
-- SAMPLE TAX DATA
-- Philippines Example (Universal structure works for any country)
-- ============================================

-- ============================================
-- 1. TAX TYPES (Master list of all taxes)
-- ============================================
INSERT INTO Finance.tax_types 
    (client_id, tax_name, tax_code, tax_rate, is_active) 
VALUES
-- Income Tax
(1, 'Withholding Tax', 'WHT', 12.00, TRUE),
(1, 'Annual Income Tax', 'AIT', 15.00, TRUE),

-- Sales/VAT Tax
(1, 'Value Added Tax', 'VAT', 12.00, TRUE),
(1, 'Sales Tax', 'SALES_TAX', 10.00, TRUE),

-- Statutory Contributions (Philippines - Payroll)
(1, 'SSS Contribution', 'SSS', 11.00, TRUE),
(1, 'PhilHealth Premium', 'PHILHEALTH', 2.75, TRUE),
(1, 'Pag-IBIG Contribution', 'PAG_IBIG', 1.00, TRUE),

-- Business Tax
(1, 'Municipal Tax', 'MUNICIPAL_TAX', 0.50, TRUE),
(1, 'Business Permit Tax', 'BIZ_PERMIT', 2.00, TRUE);

-- ============================================
-- 2. TAX APPLICABILITY RULES
-- ============================================
INSERT INTO Finance.tax_rules 
    (tax_type_id, chart_id, applies_to, min_amount, max_amount, jurisdiction, is_active)
SELECT 
    tt.tax_type_id,
    NULL,  -- Not tied to specific chart, applies to transaction type
    CASE tt.tax_code
        WHEN 'WHT' THEN 'SALES'
        WHEN 'AIT' THEN 'ALL'
        WHEN 'VAT' THEN 'SALES'
        WHEN 'SALES_TAX' THEN 'SALES'
        WHEN 'SSS' THEN 'EXPENSES'
        WHEN 'PHILHEALTH' THEN 'EXPENSES'
        WHEN 'PAG_IBIG' THEN 'EXPENSES'
        WHEN 'MUNICIPAL_TAX' THEN 'ALL'
        WHEN 'BIZ_PERMIT' THEN 'ALL'
        ELSE 'ALL'
    END,
    0.00,  -- min_amount
    999999999.99,  -- max_amount (essentially no max)
    'Philippines',
    TRUE
FROM Finance.tax_types tt
WHERE tt.client_id = 1;

-- ============================================
-- 3. SAMPLE TAX CALCULATIONS (from transactions)
-- ============================================

-- For a $10,000 sale transaction (example)
INSERT INTO Finance.tax_calculations 
    (transaction_id, client_id, tax_type_id, base_amount, tax_rate, tax_amount, is_payable, due_date, status)
SELECT 
    t.transaction_id,
    1 as client_id,
    tt.tax_type_id,
    10000.00 as base_amount,
    tt.tax_rate,
    (10000.00 * tt.tax_rate / 100) as tax_amount,
    TRUE as is_payable,
    CURRENT_DATE + INTERVAL '30 days' as due_date,
    'PENDING' as status
FROM Finance.transactions t
CROSS JOIN Finance.tax_types tt
WHERE t.client_id = 1
AND tt.client_id = 1
AND tt.tax_code IN ('VAT', 'WHT')
AND NOT EXISTS (
    SELECT 1 FROM Finance.tax_calculations tc 
    WHERE tc.transaction_id = t.transaction_id 
    AND tc.tax_type_id = tt.tax_type_id
)
LIMIT 1;

-- ============================================
-- 4. TAX LIABILITY TRACKING (Monthly/Quarterly)
-- ============================================
INSERT INTO Finance.tax_liabilities 
    (client_id, tax_type_id, period_start, period_end, total_taxable_amount, total_tax_owed, total_tax_paid, balance_due, due_date, status)
SELECT
    1 as client_id,
    tt.tax_type_id,
    '2025-01-01'::DATE as period_start,
    '2025-01-31'::DATE as period_end,
    10000.00 as total_taxable_amount,
    (10000.00 * tt.tax_rate / 100) as total_tax_owed,
    0.00 as total_tax_paid,
    (10000.00 * tt.tax_rate / 100) as balance_due,
    '2025-02-15'::DATE as due_date,
    'OPEN' as status
FROM Finance.tax_types tt
WHERE tt.client_id = 1
AND tt.is_active = TRUE
AND NOT EXISTS (
    SELECT 1 FROM Finance.tax_liabilities tl
    WHERE tl.client_id = 1
    AND tl.tax_type_id = tt.tax_type_id
    AND tl.period_start = '2025-01-01'::DATE
    AND tl.period_end = '2025-01-31'::DATE
);

-- ============================================
-- ADDITIONAL: Sample Tax Payments (Mark as PAID)
-- ============================================
-- Assume VAT was already paid
UPDATE Finance.tax_liabilities
SET total_tax_paid = total_tax_owed,
    balance_due = 0,
    status = 'PAID'
WHERE client_id = 1
AND tax_type_id = (SELECT tax_type_id FROM Finance.tax_types WHERE tax_code = 'VAT' AND client_id = 1)
AND period_end = '2025-01-31'::DATE;

COMMIT;
SELECT 'TAX DATA COMPLETE';