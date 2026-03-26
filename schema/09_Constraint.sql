BEGIN;
    ALTER TABLE Finance.charts ADD CONSTRAINT charts_chk_type CHECK (Type IN ('Asset', 'Liability', 'Equity', 'Revenue', 'Expense','Contra Revenue','Contra Asset','Contra Liability','Contra Equity','Contra Expense'));

    ALTER TABLE Finance.inventoryaudits ADD CONSTRAINT inventoryaudits_chk_actiontype CHECK (ActionType IN ('Purchase', 'Sale', 'Sale Return', 'Purchase Return', 'Transfer'));

    ALTER TABLE Finance.accountpayables ADD CONSTRAINT accountpayable_chk_status CHECK (Status IN ('Pending', 'Paid', 'Overdue','Returned','Partially Returned','Partially Paid'));

    ALTER TABLE Finance.accountreceivables ADD CONSTRAINT accountreceivables_chk_status CHECK (Status IN ('Pending', 'Paid', 'Overdue','Returned','Partially Returned','Partially Paid'));

    ALTER TABLE Finance.auditlogs ADD CONSTRAINT auditlogs_chk_status CHECK (Operation IN ('INSERT', 'UPDATE', 'DELETE'));
COMMIT;
