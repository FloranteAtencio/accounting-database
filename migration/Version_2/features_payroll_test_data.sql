BEGIN;

-- ============================================
-- SAMPLE DATA FOR PAYROLL TESTING
-- ============================================

-- 1. Create sample leave types
INSERT INTO Finance.leave_types (client_id, leave_name, is_paid, days_per_year) VALUES
(1, 'Sick Leave', TRUE, 10),
(1, 'Vacation', TRUE, 15),
(1, 'Unpaid Leave', FALSE, 0),
(1, 'Maternity Leave', TRUE, 60);

-- 2. Create sample employees
INSERT INTO Finance.employees (client_id, employee_number, name, created_at) VALUES
(1, 'EMP001', 'John Doe', CURRENT_TIMESTAMP),
(1, 'EMP002', 'Jane Smith', CURRENT_TIMESTAMP),
(1, 'EMP003', 'Robert Johnson', CURRENT_TIMESTAMP);

-- 3. Create salary components (UNIVERSAL - works for any country)
INSERT INTO Finance.salary_components 
    (client_id, component_name, component_type, is_taxable, is_mandatory) VALUES

-- EARNINGS
(1, 'Basic Salary', 'SALARY', TRUE, TRUE),
(1, 'Rice Allowance', 'ALLOWANCE', FALSE, FALSE),
(1, 'Transportation Allowance', 'ALLOWANCE', FALSE, FALSE),
(1, 'Communication Allowance', 'ALLOWANCE', FALSE, FALSE),
(1, 'Overtime Pay', 'ALLOWANCE', TRUE, FALSE),
(1, '13th Month Bonus', 'BONUS', TRUE, FALSE),

-- DEDUCTIONS (Statutory - Philippines example)
(1, 'SSS Contribution', 'STATUTORY', FALSE, TRUE),
(1, 'PhilHealth Premium', 'STATUTORY', FALSE, TRUE),
(1, 'Pag-IBIG Contribution', 'STATUTORY', FALSE, TRUE),

-- TAXES
(1, 'Withholding Tax', 'TAX', TRUE, TRUE),
(1, 'Income Tax', 'TAX', TRUE, FALSE),

-- OTHER DEDUCTIONS
(1, 'Personal Loan Deduction', 'DEDUCTION', FALSE, FALSE),
(1, 'Salary Loan Deduction', 'DEDUCTION', FALSE, FALSE),
(1, 'Employee Assistance Program', 'BENEFIT', FALSE, FALSE);

-- 4. Setup John Doe's salary components
INSERT INTO Finance.employee_salary_details 
    (employee_id, component_id, amount, effective_date, is_taxable) 
SELECT 
    e.employee_id,
    sc.component_id,
    CASE sc.component_name
        WHEN 'Basic Salary' THEN 30000.00
        WHEN 'Rice Allowance' THEN 1500.00
        WHEN 'Transportation Allowance' THEN 2000.00
        WHEN 'Communication Allowance' THEN 500.00
        WHEN 'SSS Contribution' THEN 1350.00
        WHEN 'PhilHealth Premium' THEN 500.00
        WHEN 'Pag-IBIG Contribution' THEN 200.00
        WHEN 'Withholding Tax' THEN 2000.00
        ELSE 0.00
    END,
    '2025-01-01'::DATE,
    TRUE
FROM Finance.employees e
CROSS JOIN Finance.salary_components sc
WHERE e.employee_number = 'EMP001'
AND sc.client_id = 1
AND sc.component_name IN (
    'Basic Salary', 'Rice Allowance', 'Transportation Allowance', 
    'Communication Allowance', 'SSS Contribution', 'PhilHealth Premium',
    'Pag-IBIG Contribution', 'Withholding Tax'
);

-- 5. Setup Jane Smith's salary components
INSERT INTO Finance.employee_salary_details 
    (employee_id, component_id, amount, effective_date, is_taxable) 
SELECT 
    e.employee_id,
    sc.component_id,
    CASE sc.component_name
        WHEN 'Basic Salary' THEN 35000.00
        WHEN 'Rice Allowance' THEN 1500.00
        WHEN 'Transportation Allowance' THEN 2000.00
        WHEN 'Communication Allowance' THEN 500.00
        WHEN 'SSS Contribution' THEN 1575.00
        WHEN 'PhilHealth Premium' THEN 500.00
        WHEN 'Pag-IBIG Contribution' THEN 200.00
        WHEN 'Withholding Tax' THEN 2500.00
        ELSE 0.00
    END,
    '2025-01-01'::DATE,
    TRUE
FROM Finance.employees e
CROSS JOIN Finance.salary_components sc
WHERE e.employee_number = 'EMP002'
AND sc.client_id = 1
AND sc.component_name IN (
    'Basic Salary', 'Rice Allowance', 'Transportation Allowance', 
    'Communication Allowance', 'SSS Contribution', 'PhilHealth Premium',
    'Pag-IBIG Contribution', 'Withholding Tax'
);

-- 6. Setup Robert Johnson's salary components
INSERT INTO Finance.employee_salary_details 
    (employee_id, component_id, amount, effective_date, is_taxable) 
SELECT 
    e.employee_id,
    sc.component_id,
    CASE sc.component_name
        WHEN 'Basic Salary' THEN 40000.00
        WHEN 'Rice Allowance' THEN 1500.00
        WHEN 'Transportation Allowance' THEN 2000.00
        WHEN 'Communication Allowance' THEN 1000.00
        WHEN 'SSS Contribution' THEN 1800.00
        WHEN 'PhilHealth Premium' THEN 500.00
        WHEN 'Pag-IBIG Contribution' THEN 200.00
        WHEN 'Withholding Tax' THEN 3000.00
        WHEN 'Personal Loan Deduction' THEN 500.00
        ELSE 0.00
    END,
    '2025-01-01'::DATE,
    TRUE
FROM Finance.employees e
CROSS JOIN Finance.salary_components sc
WHERE e.employee_number = 'EMP003'
AND sc.client_id = 1
AND sc.component_name IN (
    'Basic Salary', 'Rice Allowance', 'Transportation Allowance', 
    'Communication Allowance', 'SSS Contribution', 'PhilHealth Premium',
    'Pag-IBIG Contribution', 'Withholding Tax', 'Personal Loan Deduction'
);

-- 7. Create payroll period for January 2025
INSERT INTO Finance.payroll_periods 
    (client_id, period_name, period_start, period_end, pay_date, status) 
VALUES
(1, 'January 2025', '2025-01-01'::DATE, '2025-01-31'::DATE, '2025-02-05'::DATE, 'OPEN');

-- 8. Sample time records (optional - if tracking hours)
INSERT INTO Finance.employee_time_records 
    (employee_id, time_date, time_in, time_out, hours_worked, record_type) 
VALUES
(1, '2025-01-02'::DATE, '2025-01-02 08:00:00'::TIMESTAMP, '2025-01-02 17:00:00'::TIMESTAMP, 8.00, 'PRESENT'),
(1, '2025-01-03'::DATE, '2025-01-03 08:00:00'::TIMESTAMP, '2025-01-03 17:00:00'::TIMESTAMP, 8.00, 'PRESENT'),
(2, '2025-01-02'::DATE, '2025-01-02 08:30:00'::TIMESTAMP, '2025-01-02 17:30:00'::TIMESTAMP, 8.00, 'PRESENT'),
(2, '2025-01-03'::DATE, '2025-01-03 08:30:00'::TIMESTAMP, '2025-01-03 17:30:00'::TIMESTAMP, 8.00, 'PRESENT');

COMMIT;