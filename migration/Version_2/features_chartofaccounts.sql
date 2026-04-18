-- Insert template header first
INSERT INTO Finance.coatemplates (templatename, description)
VALUES ('Default Accounts', 'Standard COA for small businesses')
RETURNING templateid;
-- Returns template_id = 1

-- Then insert template accounts
INSERT INTO Finance.coatemplateaccounts (templateid, accountcode, accountname, accounttype)
VALUES
-- Assets
--(1, 1000, 'Cash on Hand', 'Asset'),
(1, 1010, 'Cash on Hand', 'Asset'),
(1, 1020, 'Cash in Bank', 'Asset'),
(1, 1030, 'Petty Cash', 'Asset'),
(1, 1100, 'Accounts Receivable', 'Asset'),
(1, 1110, 'Allowance for Doubtful Accounts', 'Asset'),
(1, 1200, 'Prepaid Expenses', 'Asset'),
(1, 1210, 'Prepaid Insurance', 'Asset'),
(1, 1220, 'Prepaid Rent', 'Asset'),
(1, 1300, 'Office Supplies', 'Asset'),
(1, 1400, 'Equipment', 'Asset'),
(1, 1410, 'Accumulated Depreciation - Equipment', 'Asset'),
(1, 1500, 'Furniture & Fixtures', 'Asset'),
(1, 1510, 'Accumulated Depreciation - Furniture', 'Asset'),
(1, 1600, 'Vehicles', 'Asset'),
(1, 1610, 'Accumulated Depreciation - Vehicles', 'Asset'),
(1, 1620, 'Iventory','Asset'),
-- Liabilities
(1, 2000, 'Accounts Payable', 'Liability'),
(1, 2010, 'Accrued Expenses', 'Liability'),
(1, 2020, 'Accrued Salaries', 'Liability'),
(1, 2030, 'Accrued Interest', 'Liability'),
(1, 2100, 'VAT Payable', 'Liability'),
(1, 2110, 'Income Tax Payable', 'Liability'),
(1, 2120, 'Withholding Tax Payable', 'Liability'),
(1, 2200, 'Short Term Loans', 'Liability'),
(1, 2300, 'Long Term Loans', 'Liability'),
(1, 2310, 'Mortgage Payable', 'Liability'),
(1, 2400, 'Unearned Revenue', 'Liability'),
-- Equity
(1, 3000, 'Owner''s Capital', 'Equity'),
(1, 3010, 'Owner''s Drawing', 'Equity'),
(1, 3100, 'Retained Earnings', 'Equity'),
-- Revenue
(1, 4000, 'Sales Revenue', 'Revenue'),
(1, 4010, 'Service Revenue', 'Revenue'),
(1, 4020, 'Sales Returns & Allowances', 'Revenue'),
(1, 4030, 'Sales Discounts', 'Revenue'),
(1, 4100, 'Interest Income', 'Revenue'),
(1, 4110, 'Rental Income', 'Revenue'),
(1, 4120, 'Commission Income', 'Revenue'),
(1, 4200, 'Other Income', 'Revenue'),
(1, 4300, 'Service Revenue', 'Revenue'),
(1, 4400, 'Consulting Revenue', 'Revenue'),
(1, 4500, 'Professional Fees', 'Revenue'),
(1, 4600, 'Interest Income', 'Revenue'),
(1, 4700, 'Rental Income', 'Revenue'),
(1, 4800, 'Other Income', 'Revenue'),
(1, 4900, 'Sales Revenue', 'Revenue'),
-- Cost of Goods Sold
(1, 5000, 'Cost of Goods Sold', 'Expense'),
(1, 5010, 'Purchase Returns & Allowances', 'Expense'),
(1, 5020, 'Purchase Discounts', 'Expense'),
(1, 5030, 'Freight In', 'Expense'),
-- Expenses
(1, 6000, 'Salaries & Wages', 'Expense'),
(1, 6010, 'Employee Benefits', 'Expense'),
(1, 6020, 'SSS/PhilHealth/Pag-IBIG', 'Expense'),
(1, 6100, 'Rent Expense', 'Expense'),
(1, 6110, 'Utilities Expense', 'Expense'),
(1, 6120, 'Internet & Phone Expense', 'Expense'),
(1, 6200, 'Office Supplies Expense', 'Expense'),
(1, 6210, 'Printing & Stationery', 'Expense'),
(1, 6300, 'Depreciation Expense', 'Expense'),
(1, 6400, 'Insurance Expense', 'Expense'),
(1, 6500, 'Repairs & Maintenance', 'Expense'),
(1, 6600, 'Advertising & Marketing', 'Expense'),
(1, 6700, 'Transportation Expense', 'Expense'),
(1, 6800, 'Professional Fees - Expense', 'Expense'),
(1, 6810, 'Accounting Fees', 'Expense'),
(1, 6820, 'Legal Fees', 'Expense'),
(1, 6900, 'Bank Charges', 'Expense'),
(1, 6910, 'Interest Expense', 'Expense'),
(1, 7000, 'Bad Debts Expense', 'Expense'),
(1, 7100, 'Taxes & Licenses', 'Expense'),
(1, 7200, 'Miscellaneous Expense', 'Expense'),
(1, 7300, 'Inventory Expense','Expense');

-- INSERT INTO ... SELECT (no VALUES keyword)
INSERT INTO Finance.charts (clientId, account, accountCode, type, is_active)
SELECT 
    1,                  -- clientId
    accountname,       -- account
    accountcode,       -- accountCode
    accounttype,       -- type
    TRUE                -- is_active
FROM Finance.coatemplateaccounts
WHERE templateid = 1;

CREATE OR REPLACE PROCEDURE Finance.assign_account_role(
    IN p_account_description TEXT,
    IN p_role_name TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_rows_affected INT;
BEGIN
    -- Insert roles for matching accounts
    INSERT INTO Finance.accountroles (chartId, rolename)
    SELECT
        chartId,
        p_role_name
    FROM Finance.charts
    WHERE account LIKE p_account_description || '%'  -- Concatenate % inside string
    ON CONFLICT (chartId, rolename) DO NOTHING;

    -- Get number of rows affected
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    RAISE NOTICE 'Account description "%" applied to role "%" for % accounts', 
        p_account_description, p_role_name, v_rows_affected;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to apply role: %', SQLERRM;
END;
$$;

call finance.apply_coa_template (1,1);
call finance.assign_account_role ('Cash on Hand','cash_account_ar');
call finance.assign_account_role ('Accounts Receivable','ar_account');
call finance.assign_account_role ('Accounts Payable','ap_account');
call finance.assign_account_role ('Sales Revenue','revenue_account');
call finance.assign_account_role ('Inventory Expense','expense_account');
call finance.assign_account_role ('Cash in Bank','cash_account_ap');
call finance.assign_account_role ('Inventory','inventory_account');
CALL Finance.assign_account_role ('Cost of Goods Sold','COGS');
CALL Finance.assign_account_role ('Sales Returns & Allowances','SR&Allowances');

CALL Finance.ar_transaction(
    1,                              -- clientId
    10,                            -- customerId
    '2026-06-01'::DATE,             -- dueDate
    '2026-05-01'::DATE,             -- invoiceDate
    5000.00,                        -- amount
    'Paid',                         -- status
    'txn_ar_001'                    -- idempotency_key
);

CALL Finance.ap_transaction(
    1,                              -- clientId
    15,                             -- vendorId
    '2026-06-15'::DATE,             -- dueDate
    '2026-05-15'::DATE,             -- invoiceDate
    2000.00,                        -- amount
    'Pending',                         -- status
    'txn_ap_001'                    -- idempotency_key
);

CALL Finance.expense_transaction(
    1,                              -- clientId
    500.00,                         -- amount
    '2026-05-20'::DATE,             -- expenseDate
    'Office Supplies',              -- description
    'txn_exp_001'                   -- idempotency_key
);

CALL Finance.revenue_transaction(
    1,                              -- clientId
    3000.00,                        -- amount
    '2026-05-20'::DATE,             -- revenueDate
    'Service Revenue',              -- description
    'txn_rev_001'                   -- idempotency_key
);

CALL Finance.process_inventory_transaction(
    1,
    1,  -- product_id
    1,  -- warehouse
    'Purchase', -- action type
    10, -- quantity
    CURRENT_DATE, -- date
    1,   -- supplier_id 
    'Sales-2026-01-01-Mr.Atencio' --idempotency key
);

CALL Finance.process_inventory_transaction(
    1,
    1,
    1,
    'Sale',
    5,
    CURRENT_DATE,
    1, -- customer_id
    'Sales-2026-01-01-Mr.Atencio0000'
);

CALL Finance.process_inventory_transaction(
    1,
    1,
    1,
    'Sale Return',
    2,
    CURRENT_DATE,
    1, -- receivable_id
    'Sales-2026-01-01-Mr.Atencio-0001'
);

CALL Finance.process_inventory_transaction(
    1,
    1,
    1,
    'Purchase Return',
    2,
    CURRENT_DATE,
    1, -- receivable_id
    'Sales-2026-01-01-Mr.Atencio-0002'
);
INSERT INTO Finance.event_log (EventType, Payload,idempotencyKey)
VALUES (
    'SALE',
    jsonb_build_object(
        'client_id',1,
        'product_id', 1,
        'warehouse_id', 1,
        'quantity', 5,
        'price', 100,
        'action_type','Sale',
        'customer_id', 1,
        'date', CURRENT_DATE,
        'idempotency_key','sale-2026-0001'
    )
    ,'sale-2026-0001'
);

INSERT INTO Finance.event_log (EventType, Payload,idempotencyKey)
VALUES (
    'PURCHASE',
    jsonb_build_object(
        'client_id',1,
        'product_id', 1,
        'warehouse_id', 1,
        'quantity', 20,
        'action_type','Purchase',
        'supplier_id', 1,
        'date', CURRENT_DATE,
        'idempotency_key','sale-2026-0002'
    )
    ,'sale-2026-0002'
);

INSERT INTO Finance.event_log (EventType, Payload,idempotencyKey)
VALUES (
    'RETURN',
    jsonb_build_object(
        'client_id',1,
        'product_id', 1,
        'warehouse_id', 1,
        'quantity', 20,
        'action_type','Purchase Return',
        'ref_id', 1,
        'date', CURRENT_DATE,
        'idempotency_key','sale-2026-0003'
    )
    ,'sale-2026-0003'
);
