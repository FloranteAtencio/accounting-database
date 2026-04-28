BEGIN;
SELECT 'TAX DATA';
-- ============================================
-- SAMPLE TAX DATA
-- Philippines Example (Universal structure works for any country)
-- ============================================

-- ============================================
-- TAX TYPES (Master list of all taxes)
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
-- TAX LIABILITY TRACKING (Monthly/Quarterly)
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
SELECT 'TAX DATA COMPLETE';
COMMIT;
