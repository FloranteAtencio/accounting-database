BEGIN;
-- ============================================
-- 1. CLIENTS TABLE
-- ============================================
DROP TABLE IF EXISTS Finance.clients CASCADE;
CREATE TABLE IF NOT EXISTS Finance.clients (
    clientId SERIAL PRIMARY KEY,
    info JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2. COA TEMPLATES (for reference/defaults)
-- ============================================
DROP TABLE IF EXISTS Finance.coa_templates CASCADE;
CREATE TABLE IF NOT EXISTS Finance.coa_templates (
    template_id SERIAL PRIMARY KEY,
    template_name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2.1 COA TEMPLATES (for reference/defaults)
-- ============================================
DROP TABLE IF EXISTS Finance.coa_templa_teaccounts CASCADE;
CREATE TABLE IF NOT EXISTS Finance.coa_template_accounts (
    template_account_Id BIGSERIAL PRIMARY KEY,
    template_id INT NOT NULL REFERENCES Finance.coa_templates(template_id) ON DELETE ,
    account_code INT NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL,
    UNIQUE(template_id, account_code)
);


-- ============================================
-- 3. CHART OF ACCOUNTS (client-specific)
-- ============================================
DROP TABLE IF EXISTS Finance.charts CASCADE;
CREATE TABLE IF NOT EXISTS Finance.charts (
    chart_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    account VARCHAR(100) NOT NULL,
    account_code INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(client_Id, account_code)
);

-- ============================================
-- 4. ACCOUNT ROLES (flexible, multiple roles per account)
-- ============================================
DROP TABLE IF EXISTS Finance.account_roles CASCADE;
CREATE TABLE IF NOT EXISTS Finance.account_roles (
    role_id SERIAL PRIMARY KEY,
    chart_id INT NOT NULL REFERENCES Finance.charts(chart_id) ON DELETE NO ACTION,
    role_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(chart_id, role_name)
);

-- ============================================
-- 5. ACCOUNT PROPERTIES
-- ============================================
DROP TABLE IF EXISTS Finance.account_properties CASCADE;
CREATE TABLE IF NOT EXISTS Finance.account_properties (
    property_id SERIAL PRIMARY KEY,
    chart_id INT NOT NULL REFERENCES Finance.charts(chart_id) ON DELETE NO ACTION,
    is_payable BOOLEAN,
    is_debt BOOLEAN,
    is_bank_account BOOLEAN,
    is_credit_card BOOLEAN,
    requires_reconciliation BOOLEAN,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. TRANSACTIONS
-- ============================================
DROP TABLE IF EXISTS Finance.transactions CASCADE;
CREATE TABLE IF NOT EXISTS Finance.transactions (
    transaction_id BIGSERIAL PRIMARY KEY,
    description TEXT NOT NULL,
    idempotency_key TEXT UNIQUE NOT NULL,
    client_id INT REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 7. JOURNALS
-- ============================================
DROP TABLE IF EXISTS Finance.journals CASCADE;
CREATE TABLE IF NOT EXISTS Finance.journals (
    journal_id BIGSERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES Finance.transactions(Transaction_id) ON DELETE NO ACTION,
    chart_id INT NOT NULL REFERENCES Finance.charts(chart_id) ON DELETE NO ACTION,
    date DATE NOT NULL,
    journal BOOLEAN NOT NULL CHECK (journal IN (TRUE,FALSE)),
    amount DECIMAL(15,2) NOT NULL CHECK  (Amount >= 0)
  --  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    --PRIMARY KEY (JournalID,Date)
);--PARTITION BY RANGE(Date);

-- ============================================
-- 8. CUSTOMERS
-- ============================================
    DROP TABLE IF EXISTS Finance.customers CASCADE;
    CREATE TABLE Finance.customers (
        customer_id SERIAL PRIMARY KEY,
        customer_name VARCHAR(255) NOT NULL,
        contact_Info VARCHAR(25) NOT NULL,
        email VARCHAR(50) NOT NULL,
        address VARCHAR(100) NOT NULL
    );

-- ============================================
-- 9. SUPPLIER
-- ============================================
    DROP TABLE IF EXISTS Finance.suppliers CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.suppliers (
        supplier_id SERIAL PRIMARY KEY,
        supplier_name VARCHAR(255) NOT NULL,
        contact_info VARCHAR(25) NOT NULL,
        email VARCHAR(50) NOT NULL,
        address VARCHAR(100) NOT NULL
    );

-- ============================================
-- 10. PRODUCT
-- ============================================
    DROP TABLE IF EXISTS Finance.products CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.products (
        product_id SERIAL PRIMARY KEY,
        product_name VARCHAR(255) NOT NULL,
        description VARCHAR(200),
        product_unit VARCHAR(20) NOT NULL,
        product_cost DECIMAL(15, 2) NOT NULL CHECK (product_cost >= 0),
        product_price DECIMAL(15, 2) NOT NULL CHECK (product_price >= 0)
    );

-- ============================================
-- 11. WAREHOUSES
-- ============================================
    DROP TABLE IF EXISTS Finance.warehouses CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.warehouses (
        warehouse_id SERIAL PRIMARY KEY,
        warehouse_name VARCHAR(255) NOT NULL,
        location VARCHAR(100) NOT NULL
    );


-- ============================================
-- 12. ACCOUNTS RECEIVABLE
-- ============================================
DROP TABLE IF EXISTS Finance.accountreceivables CASCADE;
CREATE TABLE IF NOT EXISTS Finance.accountreceivables (
    receivable_id SERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES Finance.transactions(Transaction_id) ON DELETE NO ACTION,
    customer_id INT NOT NULL REFERENCES Finance.customers(Customer_id) ON DELETE NO ACTION
   -- created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 13. AR EXTENSION
-- ============================================
DROP TABLE IF EXISTS Finance.ar_ext CASCADE;
CREATE TABLE IF NOT EXISTS Finance.ar_ext (
    ar_ext_id BIGSERIAL PRIMARY KEY,
    amount DECIMAL(15,2) NOT NULL,
    due_date DATE NOT NULL,
    invoice_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    receivable_id INT NOT NULL REFERENCES Finance.accountreceivables(receivable_id) ON DELETE NO ACTION
   -- created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    --PRIMARY KEY (ar_ext_id,InvoiceDate)
);  --PARTITION BY RANGE(InvoiceDate);

-- ============================================
-- 14. ACCOUNTS PAYABLE
-- ============================================
DROP TABLE IF EXISTS Finance.account_payables CASCADE;
CREATE TABLE IF NOT EXISTS Finance.account_payables (
    payable_id SERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES Finance.transactions(transaction_id) ON DELETE NO ACTION,
    supplier_id INT NOT NULL REFERENCES Finance.suppliers(supplier_id) ON DELETE NO ACTION
    --created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 15. AP EXTENSION
-- ============================================
DROP TABLE IF EXISTS Finance.ap_ext CASCADE;
CREATE TABLE IF NOT EXISTS Finance.ap_ext (
    ap_ext_id BIGSERIAL PRIMARY KEY,
    amount DECIMAL(15,2) NOT NULL CHECK (amount >= 0),
    due_date DATE NOT NULL,
    invoice_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    payable_id INT NOT NULL REFERENCES Finance.accountpayables(payable_id) ON DELETE NO ACTION
    --created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    --PRIMARY KEY (ap_ext_id,InvoiceDate)
);    
    
-- ============================================
-- 16. INVENTORY AUDIT
-- ============================================
    DROP TABLE IF EXISTS Finance.inventory_audits CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.inventory_audits (
        management_id SERIAL PRIMARY KEY, 
        product_id INT NOT NULL,
        warehouse_id INT NOT NULL,
        transaction_id INT NOT NULL,
        action_type VARCHAR(50) NOT NULL, 
        quantity INT NOT NULL CHECK (quantity > 0),
        movement_date DATE NOT NULL,
        FOREIGN KEY (product_id) REFERENCES Finance.products(Product_id) ON DELETE NO ACTION,
        FOREIGN KEY (warehouse_id) REFERENCES Finance.warehouses(Warehouse_id) ON DELETE NO ACTION,
        FOREIGN KEY (transaction_id) REFERENCES Finance.transactions(Transaction_id) ON DELETE NO ACTION
        --PRIMARY KEY (ManagementID,MovementDate)
    ); --PARTITION BY RANGE(MovementDate);

-- ============================================
-- 17. PURCHASE RETURNS
-- ============================================
    DROP TABLE IF EXISTS Finance.purchase_returns CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.purchase_returns  (
        return_id SERIAL PRIMARY KEY,
        payable_id INT NOT NULL,
        return_amount DECIMAL(15, 2) NOT NULL CHECK (returnAmount >= 0),
        return_date DATE NOT NULL,
	FOREIGN KEY (payable_id) REFERENCES Finance.accountpayables(payable_id) ON DELETE NO ACTION
        );
	
-- ============================================
-- 18. SALES  RETURNS
-- ============================================
    DROP TABLE IF EXISTS Finance.sale_returns CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.sale_returns  (
        returnId SERIAL PRIMARY KEY,
        receivable_id INT NOT NULL,
        return_amount DECIMAL(15, 2) NOT NULL CHECK (returnAmount >= 0),
        return_date DATE NOT NULL,
        FOREIGN KEY (receivable_id) REFERENCES Finance.accountreceivables(receivable_id) ON DELETE NO ACTION
        );

-- ============================================
-- 19. INVENTORY TRANSFER
-- ============================================
    DROP TABLE IF EXISTS Finance.inventory_transfers CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.inventory_transfers (
        transfer_id SERIAL PRIMARY KEY,
        from_location_id INT NOT NULL,
        to_location_id INT NOT NULL,
        product_id INT NOT NULL,
        quantity INT NOT NULL CHECK (quantity > 0),
        transfer_date DATE NOT NULL DEFAULT CURRENT_DATE,
        Notes TEXT,
        FOREIGN KEY (from_location_idocationID) REFERENCES Finance.warehouses(warehouse_id) ON DELETE NO ACTION,
        FOREIGN KEY (to_location_id) REFERENCES Finance.warehouses(warehouse_id) ON DELETE NO ACTION,
        FOREIGN KEY (product_id) REFERENCES Finance.products(product_id) ON DELETE NO ACTION
    );

-- ============================================
-- 20. AUDIT LOGS
-- ============================================
    DROP TABLE IF EXISTS Finance.audit_logs CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.audit_logs (
        audit_id SERIAL PRIMARY KEY,
        table_name VARCHAR(255) NOT NULL,
        rec_transact TEXT NOT NULL,
        operation VARCHAR(20) NOT NULL, 
        log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        changed_by VARCHAR(50) NOT NULL,
        prev_hash TEXT,
        row_hash TEXT
    );

-- ============================================
-- 21. EVENT LOG
-- ============================================    
DROP TABLE IF  EXISTS Finance.event_log CASCADE;
CREATE TABLE IF NOT EXISTS Finance.event_log (
    event_id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    idempotency_key TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP
);    
COMMIT;