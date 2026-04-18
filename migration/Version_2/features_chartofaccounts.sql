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
(1, 4000, 'Service Revenue', 'Revenue'),
(1, 4010, 'Consulting Revenue', 'Revenue'),
(1, 4020, 'Professional Fees', 'Revenue'),
(1, 4030, 'Interest Income', 'Revenue'),
(1, 4040, 'Rental Income', 'Revenue'),
(1, 4050, 'Other Income', 'Revenue'),
(1, 4060, 'Sales Revenue', 'Revenue'),
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
(1, 7200, 'Miscellaneous Expense', 'Expense');
