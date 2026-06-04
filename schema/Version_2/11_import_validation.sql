-- ============================================
-- 11_IMPORT_VALIDATION.SQL
-- Purpose: Validation functions for data quality
-- before importing into the database
-- ============================================

BEGIN;

-- ============================================
-- 1. DATA TYPE VALIDATORS
-- ============================================

-- Email validator
DROP FUNCTION IF EXISTS Finance.validate_email(VARCHAR) CASCADE;
CREATE FUNCTION Finance.validate_email(p_email VARCHAR)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT) AS $$
BEGIN
    IF p_email IS NULL OR p_email = '' THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Email cannot be empty'::TEXT;
    ELSIF p_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$' THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Invalid email format'::TEXT;
    ELSE
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Phone validator
DROP FUNCTION IF EXISTS Finance.validate_phone(VARCHAR) CASCADE;
CREATE FUNCTION Finance.validate_phone(p_phone VARCHAR)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT) AS $$
BEGIN
    IF p_phone IS NULL OR p_phone = '' THEN
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT;  -- Phone can be empty
    ELSIF p_phone !~ '^\+?1?\d{9,15}$' THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Invalid phone format'::TEXT;
    ELSE
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Decimal amount validator
DROP FUNCTION IF EXISTS Finance.validate_decimal_amount(VARCHAR) CASCADE;
CREATE FUNCTION Finance.validate_decimal_amount(p_amount VARCHAR)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT, parsed_value DECIMAL) AS $$
DECLARE
    v_parsed DECIMAL;
BEGIN
    BEGIN
        v_parsed := p_amount::DECIMAL;
        IF v_parsed < 0 THEN
            RETURN QUERY SELECT FALSE::BOOLEAN, 'Amount cannot be negative'::TEXT, NULL::DECIMAL;
        ELSE
            RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT, v_parsed::DECIMAL;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Invalid decimal format: ' || p_amount::TEXT, NULL::DECIMAL;
    END;
END;
$$ LANGUAGE plpgsql;

-- Integer quantity validator
DROP FUNCTION IF EXISTS Finance.validate_integer_quantity(VARCHAR) CASCADE;
CREATE FUNCTION Finance.validate_integer_quantity(p_quantity VARCHAR)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT, parsed_value INT) AS $$
DECLARE
    v_parsed INT;
BEGIN
    BEGIN
        v_parsed := p_quantity::INT;
        IF v_parsed <= 0 THEN
            RETURN QUERY SELECT FALSE::BOOLEAN, 'Quantity must be greater than 0'::TEXT, NULL::INT;
        ELSE
            RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT, v_parsed::INT;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Invalid integer format: ' || p_quantity::TEXT, NULL::INT;
    END;
END;
$$ LANGUAGE plpgsql;

-- Date validator
DROP FUNCTION IF EXISTS Finance.validate_date(VARCHAR) CASCADE;
CREATE FUNCTION Finance.validate_date(p_date VARCHAR)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT, parsed_value DATE) AS $$
DECLARE
    v_parsed DATE;
BEGIN
    BEGIN
        v_parsed := p_date::DATE;
        IF v_parsed > CURRENT_DATE THEN
            RETURN QUERY SELECT FALSE::BOOLEAN, 'Date cannot be in the future'::TEXT, NULL::DATE;
        ELSE
            RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT, v_parsed::DATE;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Invalid date format: ' || p_date::TEXT, NULL::DATE;
    END;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 2. BUSINESS LOGIC VALIDATORS
-- ============================================

-- Customer exists validator
DROP FUNCTION IF EXISTS Finance.validate_customer_exists(INT) CASCADE;
CREATE FUNCTION Finance.validate_customer_exists(p_customer_id INT)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT) AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Finance.customers WHERE customer_id = p_customer_id) THEN
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT;
    ELSE
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Customer ID does not exist: ' || p_customer_id::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Vendor exists validator
DROP FUNCTION IF EXISTS Finance.validate_vendor_exists(INT) CASCADE;
CREATE FUNCTION Finance.validate_vendor_exists(p_vendor_id INT)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT) AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Finance.vendors WHERE vendor_id = p_vendor_id) THEN
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT;
    ELSE
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Vendor ID does not exist: ' || p_vendor_id::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Product exists validator
DROP FUNCTION IF EXISTS Finance.validate_product_exists(INT) CASCADE;
CREATE FUNCTION Finance.validate_product_exists(p_product_id INT)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT) AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Finance.products WHERE product_id = p_product_id) THEN
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT;
    ELSE
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Product ID does not exist: ' || p_product_id::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Warehouse exists validator
DROP FUNCTION IF EXISTS Finance.validate_warehouse_exists(INT) CASCADE;
CREATE FUNCTION Finance.validate_warehouse_exists(p_warehouse_id INT)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT) AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Finance.warehouses WHERE warehouse_id = p_warehouse_id) THEN
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT;
    ELSE
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Warehouse ID does not exist: ' || p_warehouse_id::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Account exists validator
DROP FUNCTION IF EXISTS Finance.validate_account_exists(INT) CASCADE;
CREATE FUNCTION Finance.validate_account_exists(p_chart_id INT)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT) AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Finance.charts WHERE chart_id = p_chart_id AND is_active = TRUE) THEN
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT;
    ELSE
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Account ID does not exist or is inactive: ' || p_chart_id::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Transaction balance validator (debit = credit)
DROP FUNCTION IF EXISTS Finance.validate_transaction_balance(INT) CASCADE;
CREATE FUNCTION Finance.validate_transaction_balance(p_transaction_id INT)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT, debit_total DECIMAL, credit_total DECIMAL) AS $$
DECLARE
    v_debit DECIMAL;
    v_credit DECIMAL;
BEGIN
    SELECT COALESCE(SUM(CASE WHEN journal = TRUE THEN amount ELSE 0 END), 0),
           COALESCE(SUM(CASE WHEN journal = FALSE THEN amount ELSE 0 END), 0)
    INTO v_debit, v_credit
    FROM Finance.journals
    WHERE transaction_id = p_transaction_id;
    
    IF v_debit = v_credit THEN
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT, v_debit, v_credit;
    ELSE
        RETURN QUERY SELECT FALSE::BOOLEAN, 
            'Debit/Credit imbalance. Debit: ' || v_debit::TEXT || ' Credit: ' || v_credit::TEXT,
            v_debit, v_credit;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Invoice date <= due date validator
DROP FUNCTION IF EXISTS Finance.validate_invoice_due_dates(DATE, DATE) CASCADE;
CREATE FUNCTION Finance.validate_invoice_due_dates(p_invoice_date DATE, p_due_date DATE)
RETURNS TABLE (is_valid BOOLEAN, error_msg TEXT) AS $$
BEGIN
    IF p_invoice_date > p_due_date THEN
        RETURN QUERY SELECT FALSE::BOOLEAN, 'Invoice date cannot be after due date'::TEXT;
    ELSE
        RETURN QUERY SELECT TRUE::BOOLEAN, ''::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Receivable overdue check
DROP FUNCTION IF EXISTS Finance.is_receivable_overdue(DATE) CASCADE;
CREATE FUNCTION Finance.is_receivable_overdue(p_due_date DATE)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN p_due_date < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Payable overdue check
DROP FUNCTION IF EXISTS Finance.is_payable_overdue(DATE) CASCADE;
CREATE FUNCTION Finance.is_payable_overdue(p_due_date DATE)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN p_due_date < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. BATCH VALIDATION FUNCTIONS
-- ============================================

-- Validate entire transaction
DROP FUNCTION IF EXISTS Finance.validate_transaction_import(INT, INT, DECIMAL, DATE) CASCADE;
CREATE FUNCTION Finance.validate_transaction_import(
    p_transaction_id INT,
    p_chart_id INT,
    p_amount DECIMAL,
    p_date DATE
)
RETURNS TABLE (is_valid BOOLEAN, errors TEXT) AS $$
DECLARE
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Validate amount
    IF p_amount < 0 THEN
        v_errors := array_append(v_errors, 'Amount cannot be negative');
    END IF;
    
    -- Validate date
    IF p_date > CURRENT_DATE THEN
        v_errors := array_append(v_errors, 'Transaction date cannot be in the future');
    END IF;
    
    -- Validate account exists
    IF NOT EXISTS (SELECT 1 FROM Finance.charts WHERE chart_id = p_chart_id AND is_active = TRUE) THEN
        v_errors := array_append(v_errors, 'Invalid chart/account ID');
    END IF;
    
    -- Validate transaction exists
    IF NOT EXISTS (SELECT 1 FROM Finance.transactions WHERE transaction_id = p_transaction_id) THEN
        v_errors := array_append(v_errors, 'Transaction ID does not exist');
    END IF;
    
    RETURN QUERY SELECT 
        CASE WHEN array_length(v_errors, 1) IS NULL THEN TRUE ELSE FALSE END,
        array_to_string(v_errors, '; ');
END;
$$ LANGUAGE plpgsql;

-- Validate AR import
DROP FUNCTION IF EXISTS Finance.validate_ar_import(INT, INT, DECIMAL, DATE, DATE, VARCHAR) CASCADE;
CREATE FUNCTION Finance.validate_ar_import(
    p_receivable_id INT,
    p_customer_id INT,
    p_amount DECIMAL,
    p_invoice_date DATE,
    p_due_date DATE,
    p_status VARCHAR
)
RETURNS TABLE (is_valid BOOLEAN, errors TEXT) AS $$
DECLARE
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        v_errors := array_append(v_errors, 'AR amount must be positive');
    END IF;
    
    -- Validate dates
    IF p_invoice_date > p_due_date THEN
        v_errors := array_append(v_errors, 'Invoice date cannot be after due date');
    END IF;
    
    -- Validate customer exists
    IF NOT EXISTS (SELECT 1 FROM Finance.customers WHERE customer_id = p_customer_id) THEN
        v_errors := array_append(v_errors, 'Customer ID does not exist');
    END IF;
    
    -- Validate status
    IF p_status NOT IN ('Pending', 'Partial', 'Paid', 'Overdue') THEN
        v_errors := array_append(v_errors, 'Invalid AR status');
    END IF;
    
    RETURN QUERY SELECT 
        CASE WHEN array_length(v_errors, 1) IS NULL THEN TRUE ELSE FALSE END,
        array_to_string(v_errors, '; ');
END;
$$ LANGUAGE plpgsql;

-- Validate AP import
DROP FUNCTION IF EXISTS Finance.validate_ap_import(INT, INT, DECIMAL, DATE, DATE, VARCHAR) CASCADE;
CREATE FUNCTION Finance.validate_ap_import(
    p_payable_id INT,
    p_vendor_id INT,
    p_amount DECIMAL,
    p_invoice_date DATE,
    p_due_date DATE,
    p_status VARCHAR
)
RETURNS TABLE (is_valid BOOLEAN, errors TEXT) AS $$
DECLARE
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        v_errors := array_append(v_errors, 'AP amount must be positive');
    END IF;
    
    -- Validate dates
    IF p_invoice_date > p_due_date THEN
        v_errors := array_append(v_errors, 'Invoice date cannot be after due date');
    END IF;
    
    -- Validate vendor exists
    IF NOT EXISTS (SELECT 1 FROM Finance.vendors WHERE vendor_id = p_vendor_id) THEN
        v_errors := array_append(v_errors, 'Vendor ID does not exist');
    END IF;
    
    -- Validate status
    IF p_status NOT IN ('Pending', 'Partial', 'Paid', 'Overdue') THEN
        v_errors := array_append(v_errors, 'Invalid AP status');
    END IF;
    
    RETURN QUERY SELECT 
        CASE WHEN array_length(v_errors, 1) IS NULL THEN TRUE ELSE FALSE END,
        array_to_string(v_errors, '; ');
END;
$$ LANGUAGE plpgsql;

-- Validate inventory import
DROP FUNCTION IF EXISTS Finance.validate_inventory_import(INT, INT, INT, INT, VARCHAR) CASCADE;
CREATE FUNCTION Finance.validate_inventory_import(
    p_product_id INT,
    p_warehouse_id INT,
    p_quantity INT,
    p_transaction_id INT,
    p_action_type VARCHAR
)
RETURNS TABLE (is_valid BOOLEAN, errors TEXT) AS $$
DECLARE
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Validate quantity
    IF p_quantity <= 0 THEN
        v_errors := array_append(v_errors, 'Quantity must be greater than 0');
    END IF;
    
    -- Validate product exists
    IF NOT EXISTS (SELECT 1 FROM Finance.products WHERE product_id = p_product_id) THEN
        v_errors := array_append(v_errors, 'Product ID does not exist');
    END IF;
    
    -- Validate warehouse exists
    IF NOT EXISTS (SELECT 1 FROM Finance.warehouses WHERE warehouse_id = p_warehouse_id) THEN
        v_errors := array_append(v_errors, 'Warehouse ID does not exist');
    END IF;
    
    -- Validate action type
    IF p_action_type NOT IN ('Purchase', 'Sale', 'Sale Return', 'Purchase Return', 'Transfer') THEN
        v_errors := array_append(v_errors, 'Invalid inventory action type');
    END IF;
    
    -- Validate transaction exists
    IF NOT EXISTS (SELECT 1 FROM Finance.transactions WHERE transaction_id = p_transaction_id) THEN
        v_errors := array_append(v_errors, 'Transaction ID does not exist');
    END IF;
    
    RETURN QUERY SELECT 
        CASE WHEN array_length(v_errors, 1) IS NULL THEN TRUE ELSE FALSE END,
        array_to_string(v_errors, '; ');
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 4. VALIDATION REPORTING
-- ============================================

-- Get validation summary
DROP FUNCTION IF EXISTS Finance.get_validation_summary(INT) CASCADE;
CREATE FUNCTION Finance.get_validation_summary(p_session_id INT)
RETURNS TABLE (
    total_rows INT,
    valid_rows INT,
    invalid_rows INT,
    warning_rows INT,
    validation_pass_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE is_valid = TRUE)::INT,
        COUNT(*) FILTER (WHERE is_valid = FALSE)::INT,
        COUNT(*) FILTER (WHERE severity = 'WARNING')::INT,
        ROUND((COUNT(*) FILTER (WHERE is_valid = TRUE)::NUMERIC / COUNT(*) * 100), 2)
    FROM Finance.import_validation_log
    WHERE session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verification
SELECT 'Import Validation Functions Successfully Created' AS status;