BEGIN;
-- Email domain
DROP DOMAIN IF EXISTS email_type CASCADE;
CREATE DOMAIN email_type AS VARCHAR(255)
    CONSTRAINT valid_email CHECK (VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$');

-- Phone domain
DROP DOMAIN IF EXISTS phone_type CASCADE;
CREATE DOMAIN phone_type AS VARCHAR(20)
    CONSTRAINT valid_phone CHECK (VALUE ~ '^\+?1?\d{9,15}$' OR VALUE = '');

-- Amount domain (non-negative)
DROP DOMAIN IF EXISTS amount_type CASCADE;
CREATE DOMAIN amount_type AS DECIMAL(15,2)
    CONSTRAINT positive_amount CHECK (VALUE >= 0);

-- Quantity domain (positive integer)
DROP DOMAIN IF EXISTS quantity_type CASCADE;
CREATE DOMAIN quantity_type AS INT
    CONSTRAINT positive_quantity CHECK (VALUE > 0);

-- Account code domain
DROP DOMAIN IF EXISTS account_code_type CASCADE;
CREATE DOMAIN account_code_type AS INT
    CONSTRAINT valid_account_code CHECK (VALUE > 0);

DROP DOMAIN IF EXIST charts_typing CASCADE;
CREATE DOMAIN charts_typing AS VARCHAR(50)
    CONSTRAINT valid_charts_typing CHECK ( VALUE IN ('Asset', 'Liability', 'Equity', 'Revenue', 'Expense','Contra Revenue','Contra Asset','Contra Liability','Contra Equity','Contra Expense'));

DROP DOMAIN IF EXIST action_typing  CASCADE;
CREATE DOMAIN action_typing as  VARCHAR(50)
    CONSTRAINT valid_action_typing CHECK (VALUE IN ('Purchase', 'Sale', 'Sale Return', 'Purchase Return', 'Transfer'));

DROP DOMAIN IF EXIST status_typing CASCADE;
CREATE DOMAIN status_typing as VARCHAR(50)
    CONSTRAINT valid_status_typing CHECK (VALUE IN ('Pending', 'Paid', 'Overdue','Returned','Partially Returned','Partially Paid'));

DROP DOMAIN IF EXIST audit_log_typing CASCADE;
CREATE DOMAIN audit_log_typing as VARCHAR(50)
    CONSTRAINT valid_audit_log_typing CHECK (VALUE IN ('INSERT', 'UPDATE', 'DELETE'));

COMMIT;
