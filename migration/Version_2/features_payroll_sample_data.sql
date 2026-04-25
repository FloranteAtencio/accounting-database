SELECT 'Sample payroll data';
BEGIN;

-- ============================================
-- PROCEDURE 1: Calculate Single Employee Payroll
-- ============================================
CREATE OR REPLACE FUNCTION Finance.calculate_employee_payroll(
    p_employee_id INT,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS TABLE (
    gross_amount DECIMAL(15,2),
    total_deductions DECIMAL(15,2),
    net_amount DECIMAL(15,2),
    component_details TEXT
) AS $$
DECLARE
    v_gross DECIMAL(15,2) := 0;
    v_deductions DECIMAL(15,2) := 0;
    v_net DECIMAL(15,2);
    v_salary_amount DECIMAL(15,2);
    v_component_amount DECIMAL(15,2);
    v_component_name VARCHAR(100);
    v_component_type VARCHAR(20);
    v_component_id INT;
    v_component_details TEXT := '';
    
    -- Cursor for all salary components
    v_cursor CURSOR FOR
        SELECT 
            esd.component_id,
            sc.component_name,
            sc.component_type,
            esd.amount
        FROM Finance.employee_salary_details esd
        INNER JOIN Finance.salary_components sc 
            ON esd.component_id = sc.component_id
        WHERE esd.employee_id = p_employee_id
        AND esd.effective_date <= p_period_end
        AND (esd.end_date IS NULL OR esd.end_date >= p_period_start);
BEGIN
    -- Iterate through all components
    OPEN v_cursor;
    LOOP
        FETCH v_cursor INTO v_component_id, v_component_name, v_component_type, v_component_amount;
        EXIT WHEN NOT FOUND;
        
        -- Add to component details string
        v_component_details := v_component_details || 
            v_component_name || ': $' || v_component_amount || E'\n';
        
        -- Categorize and accumulate
        IF v_component_type IN ('SALARY', 'ALLOWANCE', 'BONUS', 'BENEFIT') THEN
            v_gross := v_gross + v_component_amount;
        ELSIF v_component_type IN ('DEDUCTION', 'TAX', 'STATUTORY') THEN
            v_deductions := v_deductions + v_component_amount;
        END IF;
    END LOOP;
    CLOSE v_cursor;
    
    v_net := v_gross - v_deductions;
    
    RETURN QUERY SELECT v_gross, v_deductions, v_net, v_component_details::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PROCEDURE 2: Generate Payroll Run
-- ============================================
CREATE OR REPLACE PROCEDURE Finance.generate_payroll_run(
    p_client_id INT,
    p_period_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_run_id INT;
    v_employee_id INT;
    v_detail_id INT;
    v_gross DECIMAL(15,2);
    v_deductions DECIMAL(15,2);
    v_net DECIMAL(15,2);
    v_total_gross DECIMAL(15,2) := 0;
    v_total_deductions DECIMAL(15,2) := 0;
    v_total_net DECIMAL(15,2) := 0;
    v_component_id INT;
    v_component_amount DECIMAL(15,2);
    v_component_type VARCHAR(20);
    v_period_start DATE;
    v_period_end DATE;
    
    v_employee_cursor CURSOR FOR
        SELECT employee_id FROM Finance.employees
        WHERE client_id = p_client_id;
    
    v_component_cursor CURSOR FOR
        SELECT 
            esd.component_id,
            esd.amount,
            sc.component_type
        FROM Finance.employee_salary_details esd
        INNER JOIN Finance.salary_components sc ON esd.component_id = sc.component_id
        WHERE esd.employee_id = v_employee_id
        AND esd.effective_date <= v_period_end
        AND (esd.end_date IS NULL OR esd.end_date >= v_period_start);
BEGIN
    -- Get period dates
    SELECT period_start, period_end INTO v_period_start, v_period_end
    FROM Finance.payroll_periods
    WHERE period_id = p_period_id;
    
    IF v_period_start IS NULL THEN
        RAISE EXCEPTION 'Payroll period % not found', p_period_id;
    END IF;
    
    -- Create payroll run
    INSERT INTO Finance.payroll_runs (period_id, client_id, status)
    VALUES (p_period_id, p_client_id, 'DRAFT')
    RETURNING run_id INTO v_run_id;
    
    RAISE NOTICE 'Created payroll run %', v_run_id;
    
    -- Process each employee
    OPEN v_employee_cursor;
    LOOP
        FETCH v_employee_cursor INTO v_employee_id;
        EXIT WHEN NOT FOUND;
        
        BEGIN
            v_gross := 0;
            v_deductions := 0;
            
            -- Create payslip header
            INSERT INTO Finance.payroll_details 
                (run_id, employee_id, salary_amount, gross_amount, total_deductions, net_amount)
            VALUES (v_run_id, v_employee_id, 0, 0, 0, 0)
            RETURNING detail_id INTO v_detail_id;
            
            -- Process all components for this employee
            OPEN v_component_cursor;
            LOOP
                FETCH v_component_cursor INTO v_component_id, v_component_amount, v_component_type;
                EXIT WHEN NOT FOUND;
                
                -- Insert component breakdown
                INSERT INTO Finance.payroll_component_details 
                    (detail_id, component_id, amount)
                VALUES (v_detail_id, v_component_id, v_component_amount);
                
                -- Categorize
                IF v_component_type IN ('SALARY', 'ALLOWANCE', 'BONUS', 'BENEFIT') THEN
                    v_gross := v_gross + v_component_amount;
                ELSIF v_component_type IN ('DEDUCTION', 'TAX', 'STATUTORY') THEN
                    v_deductions := v_deductions + v_component_amount;
                END IF;
            END LOOP;
            CLOSE v_component_cursor;
            
            v_net := v_gross - v_deductions;
            
            -- Update payslip totals
            UPDATE Finance.payroll_details
            SET gross_amount = v_gross,
                total_deductions = v_deductions,
                net_amount = v_net,
                salary_amount = v_gross
            WHERE detail_id = v_detail_id;
            
            -- Add to run totals
            v_total_gross := v_total_gross + v_gross;
            v_total_deductions := v_total_deductions + v_deductions;
            v_total_net := v_total_net + v_net;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Error processing employee %: %', v_employee_id, SQLERRM;
        END;
    END LOOP;
    CLOSE v_employee_cursor;
    
    -- Update run totals
    UPDATE Finance.payroll_runs
    SET total_gross = v_total_gross,
        total_deductions = v_total_deductions,
        total_net = v_total_net
    WHERE run_id = v_run_id;
    
    RAISE NOTICE 'Payroll run % complete. Gross: %, Deductions: %, Net: %', 
        v_run_id, v_total_gross, v_total_deductions, v_total_net;
END;
$$;

-- ============================================
-- PROCEDURE 3: Post Payroll to Account Payable
-- Creates AP + Auto-generates Journal Entries
-- ============================================
CREATE OR REPLACE PROCEDURE Finance.post_payroll_to_ap(
    p_client_id INT,
    p_run_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_payable_id INT;
    v_transaction_id INT;
    v_total_net DECIMAL(15,2);
    v_salary_expense_chart INT;
    v_salary_payable_chart INT;
    v_idempotency_key VARCHAR(255);
BEGIN
    -- Get payroll run total
    SELECT total_net INTO v_total_net
    FROM Finance.payroll_runs
    WHERE run_id = p_run_id AND client_id = p_client_id;
    
    IF v_total_net IS NULL THEN
        RAISE EXCEPTION 'Payroll run % not found', p_run_id;
    END IF;
    
    -- Find Salary Expense chart (should have role 'salary_expense')
    SELECT c.chart_id INTO v_salary_expense_chart
    FROM Finance.charts c
    INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
    WHERE c.client_id = p_client_id
    AND ar.role_name = 'salary_expense'
    AND c.is_active = TRUE LIMIT 1;
    
    -- Find Salary Payable chart (should have role 'salary_payable')
    SELECT c.chart_id INTO v_salary_payable_chart
    FROM Finance.charts c
    INNER JOIN Finance.account_roles ar ON c.chart_id = ar.chart_id
    WHERE c.client_id = p_client_id
    AND ar.role_name = 'salary_payable'
    AND c.is_active = TRUE LIMIT 1;
    
    IF v_salary_expense_chart IS NULL OR v_salary_payable_chart IS NULL THEN
        RAISE EXCEPTION 'Required accounts (salary_expense/salary_payable) not found for client %', p_client_id;
    END IF;
    
    -- Create unique idempotency key
    v_idempotency_key := 'PAYROLL-RUN-' || p_run_id || '-' || CURRENT_TIMESTAMP::TEXT;
    
    -- Create transaction
    INSERT INTO Finance.transactions (description, client_id, idempotency_key, created_at)
    VALUES (
        'Payroll Run ' || p_run_id || ' - ' || CURRENT_DATE::TEXT, 
        p_client_id, 
        v_idempotency_key,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING transaction_id INTO v_transaction_id;
    
    IF v_transaction_id IS NULL THEN
        SELECT transaction_id INTO v_transaction_id
        FROM Finance.transactions
        WHERE idempotency_key = v_idempotency_key;
        
        RAISE NOTICE 'Transaction already exists for payroll run %', p_run_id;
        RETURN;
    END IF;
    
    -- Create Account Payable for total salary
    INSERT INTO Finance.account_payables (transaction_id, supplier_id)
    VALUES (v_transaction_id, NULL)
    RETURNING payable_id INTO v_payable_id;
    
    -- Link payroll to AP
    INSERT INTO Finance.payroll_payables (run_id, payable_id, transaction_id, total_amount)
    VALUES (p_run_id, v_payable_id, v_transaction_id, v_total_net);
    
    -- Create journal entries
    -- DR: Salary Expense
    BEGIN
        INSERT INTO Finance.journals 
            (transaction_id, chart_id, date, journal, amount)
        VALUES (v_transaction_id, v_salary_expense_chart, CURRENT_DATE, TRUE, v_total_net);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Error creating debit entry: %', SQLERRM;
    END;
    
    -- CR: Salary Payable (AP)
    BEGIN
        INSERT INTO Finance.journals 
            (transaction_id, chart_id, date, journal, amount)
        VALUES (v_transaction_id, v_salary_payable_chart, CURRENT_DATE, FALSE, v_total_net);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Error creating credit entry: %', SQLERRM;
    END;
    
    -- Mark payroll as processed
    UPDATE Finance.payroll_runs
    SET status = 'PROCESSED',
        processed_date = NOW()
    WHERE run_id = p_run_id;
    
    RAISE NOTICE 'Payroll % posted to AP as Account Payable %. Total: $%. Journal entries created.', 
        p_run_id, v_payable_id, v_total_net;
END;
$$;

-- ============================================
-- PROCEDURE 4: Calculate & Post Payroll Taxes
-- ============================================
CREATE OR REPLACE PROCEDURE Finance.calculate_payroll_taxes(
    p_client_id INT,
    p_run_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_detail_id INT;
    v_gross_amount DECIMAL(15,2);
    v_tax_type_id INT;
    v_tax_rate DECIMAL(5,2);
    v_tax_amount DECIMAL(15,2);
    v_total_taxable DECIMAL(15,2);
    
    v_detail_cursor CURSOR FOR
        SELECT detail_id, gross_amount
        FROM Finance.payroll_details
        WHERE run_id = p_run_id;
    
    v_tax_cursor CURSOR FOR
        SELECT tt.tax_type_id, tt.tax_rate
        FROM Finance.tax_types tt
        WHERE tt.client_id = p_client_id
        AND tt.is_active = TRUE
        AND tt.tax_name LIKE '%Income%';  -- For income taxes
BEGIN
    OPEN v_detail_cursor;
    LOOP
        FETCH v_detail_cursor INTO v_detail_id, v_gross_amount;
        EXIT WHEN NOT FOUND;
        
        OPEN v_tax_cursor;
        LOOP
            FETCH v_tax_cursor INTO v_tax_type_id, v_tax_rate;
            EXIT WHEN NOT FOUND;
            
            -- Calculate tax
            v_tax_amount := (v_gross_amount * v_tax_rate) / 100;
            
            -- Insert tax calculation
            INSERT INTO Finance.payroll_tax_details 
                (detail_id, tax_type_id, taxable_amount, tax_amount, tax_rate)
            VALUES (v_detail_id, v_tax_type_id, v_gross_amount, v_tax_amount, v_tax_rate)
            ON CONFLICT (detail_id, tax_type_id) DO UPDATE
            SET tax_amount = v_tax_amount,
                taxable_amount = v_gross_amount;
        END LOOP;
        CLOSE v_tax_cursor;
    END LOOP;
    CLOSE v_detail_cursor;
    
    RAISE NOTICE 'Payroll taxes calculated for run %', p_run_id;
END;
$$;

-- ============================================
-- VIEW: Payslip Display
-- ============================================
CREATE OR REPLACE VIEW Finance.v_payslip_detailed AS
SELECT 
    pr.run_id,
    pp.period_name,
    pp.period_start,
    pp.period_end,
    pp.pay_date,
    e.employee_number,
    e.name AS employee_name,
    sc.component_name,
    sc.component_type,
    pcd.amount,
    pd.gross_amount,
    pd.total_deductions,
    pd.net_amount,
    pd.created_at
FROM Finance.payroll_runs pr
INNER JOIN Finance.payroll_periods pp ON pr.period_id = pp.period_id
INNER JOIN Finance.payroll_details pd ON pr.run_id = pd.run_id
INNER JOIN Finance.employees e ON pd.employee_id = e.employee_id
INNER JOIN Finance.payroll_component_details pcd ON pd.detail_id = pcd.detail_id
INNER JOIN Finance.salary_components sc ON pcd.component_id = sc.component_id
ORDER BY pr.run_id, e.employee_number, sc.component_type;

COMMIT;

SELECT 'PAYROLL SAMPLE DATA COMPLETE';