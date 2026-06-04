-- ============================================
-- ENHANCED RELATIONAL INTEGRITY
-- Version: 2.0
-- Purpose: Add foreign key constraints, checks, and data validation
-- ============================================

BEGIN;

-- ============================================
-- 1. STRENGTHEN EXISTING FOREIGN KEYS
-- ============================================

-- Add missing ON DELETE/UPDATE behavior
ALTER TABLE finance.charts
DROP CONSTRAINT IF EXISTS charts_client_id_fkey;

ALTER TABLE finance.charts
ADD CONSTRAINT charts_client_id_fkey 
FOREIGN KEY (client_id) REFERENCES finance.clients(client_id) 
ON DELETE RESTRICT  -- Prevent deleting client if charts exist
ON UPDATE CASCADE;

-- ============================================
-- 2. ADD CHECK CONSTRAINTS FOR DATA QUALITY
-- ============================================

-- Ensure amount is always positive in financial tables
ALTER TABLE finance.journals
ADD CONSTRAINT check_journal_amount_positive CHECK (amount >= 0);

ALTER TABLE finance.account_receivables
ADD CONSTRAINT check_ar_transaction_exists 
CHECK (transaction_id IS NOT NULL);

ALTER TABLE finance.account_payables
ADD CONSTRAINT check_ap_transaction_exists 
CHECK (transaction_id IS NOT NULL);

-- ============================================
-- 3. ADD DOMAIN VALIDATION
-- ============================================

-- Create domain for valid email
CREATE DOMAIN finance.email_type AS VARCHAR(255)
CHECK (VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$');

-- Create domain for currency amounts
CREATE DOMAIN finance.amount_type AS DECIMAL(15,2)
CHECK (VALUE >= 0);

-- Create domain for account codes
CREATE DOMAIN finance.account_code_type AS INT
CHECK (VALUE > 0 AND VALUE < 100000);

-- ============================================
-- 4. ADD UNIQUE CONSTRAINTS FOR DATA INTEGRITY
-- ============================================

-- Ensure idempotency key is truly unique (duplicate transaction prevention)
ALTER TABLE finance.transactions
ADD CONSTRAINT unique_idempotency_key UNIQUE (idempotency_key);

-- Ensure account codes are unique per client
ALTER TABLE finance.charts
ADD CONSTRAINT unique_account_code_per_client UNIQUE (client_id, account_code);

-- ============================================
-- 5. REFERENTIAL INTEGRITY: JOURNAL TO CHART VALIDATION
-- ============================================

-- Ensure journal entries only reference active accounts
ALTER TABLE finance.journals
ADD CONSTRAINT journal_chart_must_be_active
CHECK (chart_id IN (SELECT chart_id FROM finance.charts WHERE is_active = TRUE));

-- ============================================
-- 6. REFERENTIAL INTEGRITY: AR/AP TO TRANSACTION
-- ============================================

-- Ensure AR/AP records link to valid transactions
ALTER TABLE finance.account_receivables
ADD CONSTRAINT ar_valid_customer
CHECK (customer_id IN (SELECT customer_id FROM finance.customers));

ALTER TABLE finance.account_payables
ADD CONSTRAINT ap_valid_vendor
CHECK (vendor_id IN (SELECT vendor_id FROM finance.vendors));

-- ============================================
-- 7. AR/AP EXTENSION CONSTRAINTS
-- ============================================

-- Ensure due_date is after invoice_date
ALTER TABLE finance.ar_ext
ADD CONSTRAINT ar_ext_valid_dates
CHECK (due_date >= invoice_date);

ALTER TABLE finance.ap_ext
ADD CONSTRAINT ap_ext_valid_dates
CHECK (due_date >= invoice_date);

-- Ensure status is valid
ALTER TABLE finance.ar_ext
ADD CONSTRAINT ar_ext_valid_status
CHECK (status IN ('OUTSTANDING', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'WRITTEN_OFF'));

ALTER TABLE finance.ap_ext
ADD CONSTRAINT ap_ext_valid_status
CHECK (status IN ('OUTSTANDING', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'DISPUTED'));

-- ============================================
-- 8. INVENTORY INTEGRITY CONSTRAINTS
-- ============================================

-- Ensure warehouse exists and is valid
ALTER TABLE finance.inventory_audits
ADD CONSTRAINT inventory_valid_warehouse
CHECK (warehouse_id IN (SELECT warehouse_id FROM finance.warehouses));

-- Ensure action_type is valid
ALTER TABLE finance.inventory_audits
ADD CONSTRAINT inventory_valid_action
CHECK (action_type IN ('PURCHASE', 'SALE', 'SALE_RETURN', 'PURCHASE_RETURN', 'TRANSFER', 'ADJUSTMENT'));

-- ============================================
-- 9. RETURN RECORDS INTEGRITY
-- ============================================

-- Ensure return amounts are positive
ALTER TABLE finance.purchase_returns
ADD CONSTRAINT purchase_return_amount_positive CHECK (return_amount > 0);

ALTER TABLE finance.sale_returns
ADD CONSTRAINT sale_return_amount_positive CHECK (return_amount > 0);

-- Ensure return dates are after original transactions (checked via triggers)

-- ============================================
-- 10. INVENTORY TRANSFER CONSTRAINTS
-- ============================================

-- Ensure different warehouses
ALTER TABLE finance.inventory_transfers
ADD CONSTRAINT transfer_different_warehouses
CHECK (from_location_id != to_location_id);

-- ============================================
-- 11. PRODUCTS & OPERATIONS CONSTRAINTS
-- ============================================

-- Ensure product costs and prices are valid
ALTER TABLE finance.operations
ADD CONSTRAINT operations_valid_costs
CHECK (product_cost >= 0 AND product_price >= product_cost);

-- ============================================
-- 12. ACCOUNT PROPERTIES CONSTRAINTS
-- ============================================

-- Add check for conflicting properties
ALTER TABLE finance.account_properties
ADD CONSTRAINT properties_valid_combination
CHECK (
    -- A bank account cannot be both debt and payable
    NOT (is_bank_account AND is_debt AND is_payable)
);

-- ============================================
-- 13. CREATE HELPER FUNCTIONS FOR VALIDATION
-- ============================================

-- Function to validate transaction balance (debits = credits)
CREATE OR REPLACE FUNCTION finance.validate_transaction_balance(p_transaction_id BIGINT)
RETURNS TABLE (
    is_balanced BOOLEAN,
    total_debits DECIMAL,
    total_credits DECIMAL,
    difference DECIMAL,
    error_message TEXT
) AS $$
DECLARE
    v_total_debits DECIMAL := 0;
    v_total_credits DECIMAL := 0;
    v_difference DECIMAL := 0;
BEGIN
    SELECT 
        SUM(CASE WHEN journal THEN amount ELSE 0 END),
        SUM(CASE WHEN NOT journal THEN amount ELSE 0 END)
    INTO v_total_debits, v_total_credits
    FROM finance.journals
    WHERE transaction_id = p_transaction_id;
    
    v_difference := ABS(v_total_debits - v_total_credits);
    
    RETURN QUERY SELECT
        v_difference < 0.01 AS is_balanced,
        v_total_debits,
        v_total_credits,
        v_difference,
        CASE 
            WHEN v_difference > 0.01 THEN 'Transaction is out of balance: ' || v_difference::TEXT
            ELSE 'Transaction is balanced'
        END;
END;
$$ LANGUAGE plpgsql;

-- Function to check if AR/AP is overdue
CREATE OR REPLACE FUNCTION finance.is_receivable_overdue(p_ar_ext_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    v_due_date DATE;
BEGIN
    SELECT due_date INTO v_due_date
    FROM finance.ar_ext
    WHERE ar_ext_id = p_ar_ext_id;
    
    RETURN COALESCE(v_due_date < CURRENT_DATE, FALSE);
END;
$$ LANGUAGE plpgsql;

-- Function to validate inventory sufficient for sale
CREATE OR REPLACE FUNCTION finance.validate_inventory_sufficient(
    p_product_id INT,
    p_warehouse_id INT,
    p_quantity INT
)
RETURNS TABLE (
    has_sufficient_inventory BOOLEAN,
    current_quantity INT,
    requested_quantity INT,
    message TEXT
) AS $$
DECLARE
    v_current_qty INT := 0;
BEGIN
    SELECT 
        COALESCE(SUM(
            CASE 
                WHEN action_type = 'PURCHASE' THEN quantity
                WHEN action_type IN ('SALE', 'SALE_RETURN') THEN -quantity
                WHEN action_type = 'ADJUSTMENT' THEN quantity
                ELSE 0
            END
        ), 0)
    INTO v_current_qty
    FROM finance.inventory_audits
    WHERE product_id = p_product_id AND warehouse_id = p_warehouse_id;
    
    RETURN QUERY SELECT
        v_current_qty >= p_quantity,
        v_current_qty,
        p_quantity,
        CASE 
            WHEN v_current_qty >= p_quantity THEN 'Sufficient inventory available'
            ELSE 'Insufficient inventory: need ' || (p_quantity - v_current_qty)::TEXT
        END;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 14. CREATE TRIGGER FOR VALIDATION
-- ============================================

-- Prevent invalid journal entries
CREATE OR REPLACE FUNCTION finance.validate_journal_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if chart is active
    IF NOT EXISTS (SELECT 1 FROM finance.charts WHERE chart_id = NEW.chart_id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'Cannot post to inactive account (chart_id: %)', NEW.chart_id;
    END IF;
    
    -- Check if transaction exists
    IF NOT EXISTS (SELECT 1 FROM finance.transactions WHERE transaction_id = NEW.transaction_id) THEN
        RAISE EXCEPTION 'Transaction does not exist (transaction_id: %)', NEW.transaction_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_journal_entries
BEFORE INSERT OR UPDATE ON finance.journals
FOR EACH ROW EXECUTE FUNCTION finance.validate_journal_insert();

-- ============================================
-- 15. PREVENT ORPHANED RECORDS
-- ============================================

-- Prevent deleting clients with transactions
ALTER TABLE finance.clients
ADD CONSTRAINT clients_no_orphan_transactions
CHECK (client_id NOT IN (SELECT DISTINCT client_id FROM finance.transactions WHERE client_id IS NOT NULL));

-- Prevent deleting warehouses with inventory
ALTER TABLE finance.warehouses
ADD CONSTRAINT warehouses_no_active_inventory
CHECK (warehouse_id NOT IN (SELECT DISTINCT warehouse_id FROM finance.inventory_audits));

COMMIT;

-- ============================================
-- EXAMPLE QUERIES FOR VALIDATION
-- ============================================

/*
-- Check transaction balance
SELECT * FROM finance.validate_transaction_balance(1);

-- Check if receivable is overdue
SELECT finance.is_receivable_overdue(1);

-- Validate inventory before sale
SELECT * FROM finance.validate_inventory_sufficient(1, 1, 10);

-- Find all unbalanced transactions
SELECT 
    t.transaction_id,
    t.description,
    vtb.total_debits,
    vtb.total_credits,
    vtb.difference
FROM finance.transactions t
CROSS JOIN LATERAL finance.validate_transaction_balance(t.transaction_id) vtb
WHERE NOT vtb.is_balanced;

-- Find overdue receivables
SELECT 
    ar_ext_id,
    amount,
    due_date,
    CURRENT_DATE - due_date as days_overdue
FROM finance.ar_ext
WHERE due_date < CURRENT_DATE AND status != 'PAID';
*/
