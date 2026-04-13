-- Master initialization script
-- Runs all schema files in order

--\i schema/01_Startup.sql
--\i schema/02_tables.sql
--\i schema/02.1_constraint.sql
--\i schema/03_trigger.sql
--\i schema/04_index.sql
--\i schema/05_insert_function.sql
--\i schema/06_update_function.sql
--\i schema/07_select_function.sql

-- Verify schema created
SELECT finance.partition_weekly_basis('journals','finance');
SELECT finance.partition_monthly_basis('inventoryaudits','finance');
SELECT finance.partition_weekly_basis('ar_ext','finance');
SELECT finance.partition_weekly_basis('ap_ext','finance');

BEGIN;
INSERT INTO Finance.products (Productname, Description, Productunit, Productcost, Productprice)
VALUES  ('Laptop', 'High-performance laptop', 'Unit', 800.00, 1200.00),
('Smartphone', 'Latest model smartphone', 'Unit', 500.00, 800.00),
('Headphones', 'Noise-cancelling headphones', 'Unit', 150.00, 250.00),
('Monitor', '24-inch LED monitor', 'Unit', 200.00, 350.00),
('Keyboard', 'Mechanical keyboard', 'Unit', 100.00, 150.00);
COMMIT;
BEGIN;
INSERT INTO Finance.warehouses (WarehouseName, Location)
VALUES ('Main Warehouse', '123 Main St, Cityville'),
('Secondary Warehouse', '456 Side St, Townsville');
COMMIT;
BEGIN;
INSERT INTO Finance.charts (Account, Type)
VALUES ('Cash/Bank', 'Asset'),
('Accounts Receivable', 'Asset'),
('Inventory', 'Asset'),
('Accounts Payable', 'Liability'),
('Revenue', 'Revenue'),
('Cost of Goods Sold', 'Expense'),
('Sales Returns and Allowances', 'Contra Revenue'),
('Purchase Returns and Allowances', 'Contra Expense');
COMMIT;
BEGIN;
INSERT INTO Finance.customers (CustomerName, ContactInfo, Email, Address)
VALUES ('John Doe', '555-1234', 'john.doe@example.com', '123 Main St, Cityville');
COMMIT;
BEGIN;
INSERT INTO Finance.suppliers (SupplierName, ContactInfo, Email, Address)
VALUES ('Tech Supplies Inc.', '555-5678', 'info@techsupplies.com', '789 Tech Blvd, Techville');
COMMIT;
