SELECT 'Payroll table';
BEGIN;


-- ============================================
-- 1. EMPLOYEE MANAGEMENT
-- ============================================
CREATE TABLE Finance.employees (
    employee_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    employee_number VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_id, employee_number)
);

-- ============================================
-- 1.2 EMPLOYEE ATTENDANCE/TIME TRACKING
-- ============================================
CREATE TABLE Finance.employee_time_records (
    time_record_id BIGSERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES Finance.employees(employee_id),
    time_date DATE NOT NULL,
    time_in TIMESTAMP,
    time_out TIMESTAMP,
    hours_worked DECIMAL(5,2),
    is_overtime BOOLEAN DEFAULT FALSE,
    overtime_hours DECIMAL(5,2),
    record_type VARCHAR(20) NOT NULL CHECK (record_type IN ('PRESENT', 'ABSENT', 'SICK', 'VACATION', 'LEAVE')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, time_date)
);

-- ============================================
-- 1.3 LEAVE MANAGEMENT
-- ============================================
CREATE TABLE Finance.leave_types (
    leave_type_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    leave_name VARCHAR(100) NOT NULL,
    is_paid BOOLEAN DEFAULT TRUE,
    days_per_year INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_id, leave_name)
);

CREATE TABLE Finance.employee_leaves (
    leave_id BIGSERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES Finance.employees(employee_id),
    leave_type_id INT NOT NULL REFERENCES Finance.leave_types(leave_type_id),
    leave_date DATE NOT NULL,
    days_used DECIMAL(5,2) NOT NULL,
    approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, leave_date)
);

-- ============================================
-- 2. SALARY COMPONENTS (Universal)
-- ============================================
CREATE TABLE Finance.salary_components (
    component_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    component_name VARCHAR(100) NOT NULL,
    component_type VARCHAR(20) NOT NULL 
        CHECK (component_type IN ('SALARY', 'ALLOWANCE', 'BONUS', 'DEDUCTION', 'TAX', 'STATUTORY', 'BENEFIT')),
    is_taxable BOOLEAN DEFAULT TRUE,
    is_mandatory BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_id, component_name)
);

-- ============================================
-- 2.1 EMPLOYEE SALARY DETAILS
-- Maps components to employees with amounts
-- ============================================
CREATE TABLE Finance.employee_salary_details (
    salary_detail_id BIGSERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES Finance.employees(employee_id),
    component_id INT NOT NULL REFERENCES Finance.salary_components(component_id),
    amount DECIMAL(15,2) NOT NULL,
    effective_date DATE NOT NULL,
    end_date DATE,
    is_taxable BOOLEAN,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, component_id, effective_date)
);

-- ============================================
-- 2.2 EMPLOYEE DEDUCTIONS
-- ============================================
CREATE TABLE Finance.employee_deductions (
    deduction_id BIGSERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES Finance.employees(employee_id),
    component_id INT NOT NULL REFERENCES Finance.salary_components(component_id),
    amount DECIMAL(15,2) NOT NULL,
    effective_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, component_id, effective_date)
);

-- ============================================
-- 3. PAYROLL PERIODS
-- ============================================
CREATE TABLE Finance.payroll_periods (
    period_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    period_name VARCHAR(50) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    pay_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'OPEN' 
        CHECK (status IN ('OPEN', 'CLOSED', 'PROCESSING', 'PAID')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_id, period_start, period_end)
);

-- ============================================
-- 4. PAYROLL RUNS
-- ============================================
CREATE TABLE Finance.payroll_runs (
    run_id BIGSERIAL PRIMARY KEY,
    period_id INT NOT NULL REFERENCES Finance.payroll_periods(period_id),
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    status VARCHAR(20) DEFAULT 'DRAFT' 
        CHECK (status IN ('DRAFT', 'APPROVED', 'PROCESSED', 'PAID')),
    total_gross DECIMAL(15,2) DEFAULT 0,
    total_deductions DECIMAL(15,2) DEFAULT 0,
    total_net DECIMAL(15,2) DEFAULT 0,
    processed_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 5. PAYROLL DETAILS (Individual payslips)
-- ============================================
CREATE TABLE Finance.payroll_details (
    detail_id BIGSERIAL PRIMARY KEY,
    run_id INT NOT NULL REFERENCES Finance.payroll_runs(run_id),
    employee_id INT NOT NULL REFERENCES Finance.employees(employee_id),
    salary_amount DECIMAL(15,2) NOT NULL,
    gross_amount DECIMAL(15,2) NOT NULL,
    total_deductions DECIMAL(15,2) NOT NULL,
    net_amount DECIMAL(15,2) NOT NULL,
    paid_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(run_id, employee_id)
);

-- ============================================
-- 6. PAYROLL COMPONENT BREAKDOWN
-- Line items on payslip
-- ============================================
CREATE TABLE Finance.payroll_component_details (
    comp_detail_id BIGSERIAL PRIMARY KEY,
    detail_id INT NOT NULL REFERENCES Finance.payroll_details(detail_id),
    component_id INT NOT NULL REFERENCES Finance.salary_components(component_id),
    amount DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 7. TAX DETAILS (Per payslip)
-- ============================================
CREATE TABLE Finance.payroll_tax_details (
    tax_detail_id BIGSERIAL PRIMARY KEY,
    detail_id INT NOT NULL REFERENCES Finance.payroll_details(detail_id),
    tax_type_id INT NOT NULL REFERENCES Finance.tax_types(tax_type_id),
    taxable_amount DECIMAL(15,2),
    tax_amount DECIMAL(15,2),
    tax_rate DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(detail_id, tax_type_id)
);

-- ============================================
-- 8. STATUTORY REMITTANCES
-- SSS, PhilHealth, Pag-IBIG, etc
-- ============================================
CREATE TABLE Finance.statutory_remittances (
    remittance_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    remittance_type VARCHAR(50) NOT NULL,
    remittance_period DATE NOT NULL,
    total_amount DECIMAL(15,2),
    due_date DATE,
    paid_date DATE,
    status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'PAID', 'OVERDUE')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 8.1 PAYROLL REMITTANCE DETAILS
-- Links payroll to remittances
-- ============================================
CREATE TABLE Finance.payroll_remittance_details (
    remittance_detail_id BIGSERIAL PRIMARY KEY,
    remittance_id INT NOT NULL REFERENCES Finance.statutory_remittances(remittance_id),
    payroll_detail_id INT NOT NULL REFERENCES Finance.payroll_details(detail_id),
    employee_contribution DECIMAL(15,2),
    employer_contribution DECIMAL(15,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 9. PAYROLL → ACCOUNT PAYABLE LINK
-- Links payroll to AP
-- ============================================
CREATE TABLE Finance.payroll_payables (
    payroll_payable_id BIGSERIAL PRIMARY KEY,
    run_id INT NOT NULL REFERENCES Finance.payroll_runs(run_id),
    payable_id INT NOT NULL REFERENCES Finance.account_payables(payable_id),
    transaction_id INT NOT NULL REFERENCES Finance.transactions(transaction_id),
    total_amount DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(run_id)
);

COMMIT;
SELECT 'Payroll table Complete!';