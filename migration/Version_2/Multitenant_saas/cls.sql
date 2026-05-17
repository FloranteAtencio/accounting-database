-- ============================================
-- COLUMN LEVEL SECURITY (CLS)
-- Version: 2.0
-- Purpose: Mask sensitive columns based on user role
-- ============================================

BEGIN;

-- ============================================
-- 1. ADD SENSITIVE DATA COLUMNS
-- ============================================

-- Add encryption support for customer/vendor info
ALTER TABLE finance.customers 
    ADD COLUMN IF NOT EXISTS ssn_encrypted TEXT,
    ADD COLUMN IF NOT EXISTS tax_id_encrypted TEXT;

ALTER TABLE finance.vendors 
    ADD COLUMN IF NOT EXISTS tax_id_encrypted TEXT,
    ADD COLUMN IF NOT EXISTS bank_account_encrypted TEXT;

ALTER TABLE finance.transactions
    ADD COLUMN IF NOT EXISTS reference_number TEXT,
    ADD COLUMN IF NOT EXISTS internal_notes TEXT;

-- ============================================
-- 2. ENCRYPTION/DECRYPTION FUNCTIONS
-- ============================================

-- NOTE: PostgreSQL requires pgcrypto extension
-- Run: CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION finance.encrypt_sensitive(text_value TEXT, secret_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(
        encrypt(
            CAST(text_value AS bytea),
            CAST(secret_key AS bytea),
            'aes'
        ),
        'base64'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION finance.decrypt_sensitive(encrypted_text TEXT, secret_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN convert_from(
        decrypt(
            decode(encrypted_text, 'base64'),
            CAST(secret_key AS bytea),
            'aes'
        ),
        'utf8'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 3. COLUMN MASKING FUNCTIONS
-- ============================================

-- Mask SSN: Show only last 4 digits
CREATE OR REPLACE FUNCTION finance.mask_ssn(ssn_value TEXT)
RETURNS TEXT AS $$
BEGIN
    IF ssn_value IS NULL THEN RETURN NULL; END IF;
    RETURN '***-**-' || SUBSTRING(ssn_value, 8, 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Mask Email
CREATE OR REPLACE FUNCTION finance.mask_email(email_value TEXT)
RETURNS TEXT AS $$
DECLARE
    local_part TEXT;
    domain TEXT;
BEGIN
    IF email_value IS NULL THEN RETURN NULL; END IF;
    local_part := SPLIT_PART(email_value, '@', 1);
    domain := SPLIT_PART(email_value, '@', 2);
    RETURN SUBSTRING(local_part, 1, 1) || '***@' || domain;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Mask Phone Number: Show only last 4 digits
CREATE OR REPLACE FUNCTION finance.mask_phone(phone_value TEXT)
RETURNS TEXT AS $$
BEGIN
    IF phone_value IS NULL THEN RETURN NULL; END IF;
    RETURN '***-****' || SUBSTRING(phone_value, -4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 4. VIEWS WITH COLUMN-LEVEL SECURITY
-- ============================================

-- VIEW 1: Customers (with masked sensitive data for non-admin)
CREATE OR REPLACE VIEW finance.customers_secure AS
SELECT
    customer_id,
    customer_name,
    contact_info,
    CASE 
        WHEN current_user IN ('postgres', 'finance_admin') THEN email
        ELSE finance.mask_email(email)
    END AS email,
    address,
    CASE 
        WHEN current_user IN ('postgres', 'finance_admin') THEN ssn_encrypted
        ELSE 'REDACTED'::TEXT
    END AS ssn_encrypted
FROM finance.customers;

-- VIEW 2: Vendors (with masked sensitive data)
CREATE OR REPLACE VIEW finance.vendors_secure AS
SELECT
    vendor_id,
    supplier_name,
    contact_info,
    CASE 
        WHEN current_user IN ('postgres', 'finance_admin') THEN email
        ELSE finance.mask_email(email)
    END AS email,
    address,
    CASE 
        WHEN current_user IN ('postgres', 'finance_admin') THEN tax_id_encrypted
        ELSE 'REDACTED'::TEXT
    END AS tax_id_encrypted
FROM finance.vendors;

-- VIEW 3: Transactions with restricted access
CREATE OR REPLACE VIEW finance.transactions_secure AS
SELECT
    transaction_id,
    description,
    idempotency_key,
    client_id,
    CASE 
        WHEN current_user IN ('postgres', 'finance_admin', 'finance_accountant') THEN internal_notes
        ELSE 'REDACTED'::TEXT
    END AS internal_notes,
    created_at
FROM finance.transactions;

-- ============================================
-- 5. DENY DIRECT TABLE ACCESS
-- ============================================

-- Force users to use secure views instead of direct tables
REVOKE ALL ON finance.customers FROM finance_accountant, finance_bookkeeper, finance_auditor;
REVOKE ALL ON finance.vendors FROM finance_accountant, finance_bookkeeper, finance_auditor;

-- Grant access to secure views instead
GRANT SELECT ON finance.customers_secure TO finance_accountant, finance_bookkeeper, finance_auditor;
GRANT SELECT ON finance.vendors_secure TO finance_accountant, finance_bookkeeper, finance_auditor;
GRANT SELECT ON finance.transactions_secure TO finance_accountant, finance_bookkeeper, finance_auditor;

-- ============================================
-- 6. DYNAMIC COLUMN MASKING FUNCTION
-- ============================================

-- Generic function to check if column should be masked
CREATE OR REPLACE FUNCTION finance.should_mask_column(
    p_column_name TEXT,
    p_user_role TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    -- List of sensitive columns that require masking for non-admin roles
    IF p_user_role NOT IN ('finance_admin', 'postgres') THEN
        CASE LOWER(p_column_name)
            WHEN 'ssn_encrypted' THEN RETURN TRUE;
            WHEN 'tax_id_encrypted' THEN RETURN TRUE;
            WHEN 'bank_account_encrypted' THEN RETURN TRUE;
            WHEN 'internal_notes' THEN RETURN TRUE;
            WHEN 'email' THEN RETURN TRUE;
            WHEN 'contact_info' THEN RETURN TRUE;
            ELSE RETURN FALSE;
        END CASE;
    END IF;
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 7. AUDIT LOG SENSITIVE DATA HANDLING
-- ============================================

-- Don't log sensitive columns in audit trail
CREATE OR REPLACE FUNCTION finance.audit_log_filtered()
RETURNS TRIGGER AS $$
DECLARE
    v_new_values JSONB;
    v_old_values JSONB;
    v_key TEXT;
BEGIN
    -- Filter out sensitive columns from audit logging
    v_new_values := CASE WHEN NEW IS NOT NULL THEN to_jsonb(NEW) ELSE NULL END;
    v_old_values := CASE WHEN OLD IS NOT NULL THEN to_jsonb(OLD) ELSE NULL END;
    
    -- Remove sensitive fields
    v_new_values := v_new_values - 'ssn_encrypted' - 'tax_id_encrypted' - 'bank_account_encrypted' - 'internal_notes';
    v_old_values := v_old_values - 'ssn_encrypted' - 'tax_id_encrypted' - 'bank_account_encrypted' - 'internal_notes';
    
    -- Log operation
    INSERT INTO finance.audit_logs (
        table_name,
        rec_transact,
        operation,
        changed_by,
        prev_hash,
        row_hash
    ) VALUES (
        TG_TABLE_NAME,
        COALESCE(v_new_values::TEXT, v_old_values::TEXT),
        TG_OP,
        current_user,
        md5(v_old_values::TEXT),
        md5(v_new_values::TEXT)
    );
    
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ============================================
-- USAGE EXAMPLES
-- ============================================

/*
-- View sensitive data (admin only):
SELECT * FROM finance.customers;

-- View masked data (non-admin):
SELECT customer_id, customer_name, finance.mask_email(email) as email
FROM finance.customers
WHERE current_user != 'finance_admin';

-- Encrypt sensitive data on insert:
INSERT INTO finance.customers (customer_name, ssn_encrypted)
VALUES ('John Doe', finance.encrypt_sensitive('123-45-6789', 'secret_key'));

-- Decrypt (admin use only):
SELECT finance.decrypt_sensitive(ssn_encrypted, 'secret_key') as ssn
FROM finance.customers
WHERE customer_id = 1;
*/
