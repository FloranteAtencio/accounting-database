CREATE OR REPLACE PROCEDURE Finance.employee_payslip_hourly(
    p_client_id INT,
    p_period_id INT
)
LANGUAGE plpgsql AS $$
DECLARE

    v_employee_id INT;
    v_hour_rate DECIMAL;
    v_period_start DATE;
    v_period_end DATE;
    v_employee_total_hour DECIMAL;
    
    v_employee_cursor CURSOR FOR  
        SELECT employee_id
        FROM Finance.employees
        WHERE client_id = p_client_id;
BEGIN
        SELECT period_start , period_end INTO v_period_start, v_period_end
        FROM Finance.payroll_periods
        WHERE period_id = p_period_id

        OPEN v_employee_cursor;
        LOOP
            FETCH v_employee_cursor INTO v_employee_id;
            EXIT WHEN NOT FOUND;

            SELECT rate into v_hour_rate
            FROM Finance.employee_hourly_rate
            WHERE employee_id = v_employee_id
            AND effective_date <= v_period_end;

            SELECT operation INTO v_employee_total_hour
            FROM Finance.employee_day_or_time
            WHERE employee_id = p_employee_id 
            AND period_id = p_period_id;
            AND operation_type = 'HOUR'

        INSERT INTO Finance.employee_salary_details (employee_id, component_id, amount, effective_date, is_taxable) 
        SELECT 
        e.employee_id,
        sc.component_id,
        CASE sc.component_name
            WHEN 'Basic Salary' THEN v_hour_rate * v_employee_total_hour 
            WHEN 'Rice Allowance' THEN sc.component_rate
            WHEN 'Transportation Allowance' THEN sc.component_rate
            WHEN 'Communication Allowance' THEN sc.component_rate
            WHEN 'SSS Contribution' THEN sc.component_rate
            WHEN 'PhilHealth Premium' THEN sc.component_rate
            WHEN 'Pag-IBIG Contribution' THEN sc.component_rate
            WHEN 'Withholding Tax' THEN sc.component_rate
            WHEN 'Personal Loan Deduction' THEN sc.component_rate
            ELSE 0.00
        END,
        '2025-01-01'::DATE,
        TRUE
        FROM Finance.employees e
        CROSS JOIN Finance.salary_components sc
        WHERE e.employee_number = v_employee_id
        AND sc.client_id = p_client_id
        AND sc.component_name IN (
        'Basic Salary', 'Rice Allowance', 'Transportation Allowance', 
        'Communication Allowance', 'SSS Contribution', 'PhilHealth Premium',
        'Pag-IBIG Contribution', 'Withholding Tax', 'Personal Loan Deduction'
        );

