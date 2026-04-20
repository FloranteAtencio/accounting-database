BEGIN;
    ALTER TABLE Finance.charts 
    ADD CONSTRAINT charts_chk_type CHECK (Type IN ('Asset', 'Liability', 'Equity', 'Revenue', 'Expense','Contra Revenue','Contra Asset','Contra Liability','Contra Equity','Contra Expense'));

    ALTER TABLE Finance.inventoryaudits 
    ADD CONSTRAINT inventoryaudits_chk_actiontype CHECK (ActionType IN ('Purchase', 'Sale', 'Sale Return', 'Purchase Return', 'Transfer'));

    ALTER TABLE Finance.ap_ext 
    ADD CONSTRAINT accountpayable_chk_status CHECK (Status IN ('Pending', 'Paid', 'Overdue','Returned','Partially Returned','Partially Paid'));

    ALTER TABLE Finance.ar_ext
    ADD CONSTRAINT accountreceivables_chk_status CHECK (Status IN ('Pending', 'Paid', 'Overdue','Returned','Partially Returned','Partially Paid'));

    ALTER TABLE Finance.auditlogs 
    ADD CONSTRAINT auditlogs_chk_status CHECK (Operation IN ('INSERT', 'UPDATE', 'DELETE'));

    ALTER TABLE Finance.suppliers
    ADD CONSTRAINT chk_valid_email_supplier CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

    ALTER TABLE Finance.customers
    ADD CONSTRAINT chk_valid_email_customers CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

COMMIT;
