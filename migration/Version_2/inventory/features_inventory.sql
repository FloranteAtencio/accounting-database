-- Inventory Lots Table (for FIFO/LIFO/AVCO)
CREATE TABLE inventory_lots (
    lot_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    warehouse_id INTEGER NOT NULL,
    lot_number VARCHAR(50) NOT NULL,
    quantity DECIMAL(15, 2) NOT NULL,
    unit_cost DECIMAL(15, 2) NOT NULL,
    purchase_date DATE NOT NULL,
    expiry_date DATE,
    UNIQUE(product_id, warehouse_id, lot_number),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

-- Inventory Movements Table (audit trail)
CREATE TABLE inventory_movements (
    movement_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    warehouse_id INTEGER NOT NULL,
    lot_id INTEGER,
    movement_type VARCHAR(20) NOT NULL, -- 'purchase', 'sale', 'transfer', 'return'
    quantity DECIMAL(15, 2) NOT NULL,
    reference_id INTEGER, -- Can be transaction_id or other reference
    movement_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    FOREIGN KEY (lot_id) REFERENCES inventory_lots(lot_id)
);

CREATE TABLE tax_rates (
    tax_rate_id SERIAL PRIMARY KEY,
    tax_type VARCHAR(20) NOT NULL, -- 'VAT', 'GST', 'WHT', 'INCOME_TAX'
    rate_percentage DECIMAL(5, 2) NOT NULL,
    effective_date DATE NOT NULL,
    expiry_date DATE,
    description VARCHAR(255)
--    FOREIGN KEY (tax_type) REFERENCES tax_types(tax_type) -- if you have this table
);

CREATE TABLE inventory_settings (
    setting_id SERIAL PRIMARY KEY,
    setting_name VARCHAR(50) NOT NULL,
    setting_value VARCHAR(100) NOT NULL,
    description VARCHAR(255)
);

-- Example: Set to FIFO
INSERT INTO inventory_settings (setting_name, setting_value, description) VALUES
('inventory_method', 'FIFO', 'Inventory valuation method: FIFO, LIFO, or AVCO');

-- Example: 12% VAT
INSERT INTO tax_rates (tax_type, rate_percentage, effective_date) VALUES
('VAT', 12.00, '2024-01-01');

-- Indexes for performance
CREATE INDEX idx_inventory_lots_product ON inventory_lots(product_id);
CREATE INDEX idx_inventory_lots_warehouse ON inventory_lots(warehouse_id);
CREATE INDEX idx_inventory_movements_product ON inventory_movements(product_id);
CREATE INDEX idx_inventory_movements_warehouse ON inventory_movements(warehouse_id);
-- Tax Accounts
INSERT INTO account_roles (role_name, description) VALUES
('input_vat_receivable', 'Input VAT Receivable - Asset'),
('output_vat_payable', 'Output VAT Payable - Liability'),
('net_vat_payable', 'Net VAT Payable - Liability'),
('withholding_tax_credit', 'Withholding Tax Credit - Contra Asset'),
('income_tax_expense', 'Income Tax Expense - Expense');

-- Inventory Accounts
INSERT INTO account_roles (role_name, description) VALUES
('cogs_account', 'Cost of Goods Sold - Expense'),
('inventory_account', 'Inventory Asset - Asset'),
('inventory_lots', 'Inventory Lots - Reference Table');

-- Allowances Accounts
INSERT INTO account_roles (role_name, description) VALUES
('sr_allowances', 'Sales Returns and Allowances - Contra Revenue'),
('pr_allowances', 'Purchase Returns and Allowances - Contra Expense');