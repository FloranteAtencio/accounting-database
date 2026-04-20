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
DROP TABLE IF EXISTS Finance.coatemplates CASCADE;
CREATE TABLE IF NOT EXISTS Finance.coatemplates (
    templateId SERIAL PRIMARY KEY,
    templateName VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2.1 COA TEMPLATES (for reference/defaults)
-- ============================================
DROP TABLE IF EXISTS Finance.coatemplateaccounts CASCADE;
CREATE TABLE IF NOT EXISTS Finance.coatemplateaccounts (
    templateAccountId BIGSERIAL PRIMARY KEY,
    templateId INT NOT NULL REFERENCES Finance.coatemplates(templateid) ON DELETE CASCADE,
    accountCode INT NOT NULL,
    accountName VARCHAR(100) NOT NULL,
    accountType VARCHAR(50) NOT NULL,
    UNIQUE(templateid, accountcode)
);


-- ============================================
-- 3. CHART OF ACCOUNTS (client-specific)
-- ============================================
DROP TABLE IF EXISTS Finance.charts CASCADE;
CREATE TABLE IF NOT EXISTS Finance.charts (
    chartId BIGSERIAL PRIMARY KEY,
    clientId INT NOT NULL REFERENCES Finance.clients(clientId) ON DELETE CASCADE,
    account VARCHAR(100) NOT NULL,
    accountCode INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(clientId, accountCode)
);

-- ============================================
-- 4. ACCOUNT ROLES (flexible, multiple roles per account)
-- ============================================
DROP TABLE IF EXISTS Finance.accountroles CASCADE;
CREATE TABLE IF NOT EXISTS Finance.accountroles (
    roleId SERIAL PRIMARY KEY,
    chartId INT NOT NULL REFERENCES Finance.charts(chartId) ON DELETE CASCADE,
    roleName VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(chartId, roleName)
);

-- ============================================
-- 5. ACCOUNT PROPERTIES
-- ============================================
DROP TABLE IF EXISTS Finance.accountproperties CASCADE;
CREATE TABLE IF NOT EXISTS Finance.accountproperties (
    propertyId SERIAL PRIMARY KEY,
    chartId INT NOT NULL REFERENCES Finance.charts(chartId) ON DELETE CASCADE,
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
    transactionID BIGSERIAL PRIMARY KEY,
    description TEXT NOT NULL,
    idempotencyKey TEXT UNIQUE NOT NULL,
    clientId INT REFERENCES Finance.clients(clientId) ON DELETE NO ACTION,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 7. JOURNALS
-- ============================================
DROP TABLE IF EXISTS Finance.journals CASCADE;
CREATE TABLE IF NOT EXISTS Finance.journals (
    journalID BIGSERIAL PRIMARY KEY,
    transactionID INT NOT NULL REFERENCES Finance.transactions(TransactionID) ON DELETE CASCADE,
    chartID INT NOT NULL REFERENCES Finance.charts(chartId) ON DELETE CASCADE,
    date DATE NOT NULL,
    journal BOOLEAN NOT NULL CHECK (journal IN (TRUE,FALSE)),  -- TRUE = Debit, FALSE = Credit
    amount DECIMAL(12,2) NOT NULL CHECK  (Amount >= 0)
  --  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    --PRIMARY KEY (JournalID,Date)
);--PARTITION BY RANGE(Date);

-- ============================================
-- 8. CUSTOMERS
-- ============================================
    DROP TABLE IF EXISTS Finance.customers CASCADE;
    CREATE TABLE Finance.customers (
        customerID SERIAL PRIMARY KEY,
        customerName VARCHAR(50) NOT NULL,
        contactInfo VARCHAR(15) NOT NULL,
        email VARCHAR(50) NOT NULL CHECK, --  LIKE '%@%'),
        address VARCHAR(100) NOT NULL
    );

-- ============================================
-- 9. SUPPLIER
-- ============================================
    DROP TABLE IF EXISTS Finance.suppliers CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.suppliers (
        supplierID SERIAL PRIMARY KEY,
        supplierName VARCHAR(50) NOT NULL,
        contactInfo VARCHAR(15) NOT NULL,
        email VARCHAR(50) NOT NULL CHECK, --  LIKE '%@%'),
        address VARCHAR(100) NOT NULL
    );

-- ============================================
-- 10. PRODUCT
-- ============================================
    DROP TABLE IF EXISTS Finance.products CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.products (
        productId SERIAL PRIMARY KEY,
        productName VARCHAR(50) NOT NULL,
        description VARCHAR(200),
        productUnit VARCHAR(20) NOT NULL,
        productCost DECIMAL(10, 2) NOT NULL CHECK (productCost >= 0),
        productPrice DECIMAL(10, 2) NOT NULL CHECK (productPrice >= 0)
    );

-- ============================================
-- 11. WAREHOUSES
-- ============================================
    DROP TABLE IF EXISTS Finance.warehouses CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.warehouses (
        warehouseId SERIAL PRIMARY KEY,
        warehouseName VARCHAR(50) NOT NULL,
        location VARCHAR(100) NOT NULL
    );


-- ============================================
-- 12. ACCOUNTS RECEIVABLE
-- ============================================
DROP TABLE IF EXISTS Finance.accountreceivables CASCADE;
CREATE TABLE IF NOT EXISTS Finance.accountreceivables (
    receivableId SERIAL PRIMARY KEY,
    transactionId INT NOT NULL REFERENCES Finance.transactions(TransactionID) ON DELETE CASCADE,
    customerId INT NOT NULL REFERENCES Finance.customers(CustomerID) ON DELETE CASCADE
   -- created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 13. AR EXTENSION
-- ============================================
DROP TABLE IF EXISTS Finance.ar_ext CASCADE;
CREATE TABLE IF NOT EXISTS Finance.ar_ext (
    ar_ext_id SERIAL PRIMARY KEY,
    amount DECIMAL(12,2) NOT NULL,
    dueDate DATE NOT NULL,
    invoiceDate DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    receivableId INT NOT NULL REFERENCES Finance.accountreceivables(ReceivableID) ON DELETE CASCADE
   -- created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    --PRIMARY KEY (ar_ext_id,InvoiceDate)
);  --PARTITION BY RANGE(InvoiceDate);

-- ============================================
-- 14. ACCOUNTS PAYABLE
-- ============================================
DROP TABLE IF EXISTS Finance.accountpayables CASCADE;
CREATE TABLE IF NOT EXISTS Finance.accountpayables (
    payableId SERIAL PRIMARY KEY,
    transactionId INT NOT NULL REFERENCES Finance.transactions(TransactionID) ON DELETE CASCADE,
    supplierId INT NOT NULL REFERENCES Finance.suppliers(SupplierID) ON DELETE CASCADE
    --created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 15. AP EXTENSION
-- ============================================
DROP TABLE IF EXISTS Finance.ap_ext CASCADE;
CREATE TABLE IF NOT EXISTS Finance.ap_ext (
    ap_ext_id SERIAL PRIMARY KEY,
    amount DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
    dueDate DATE NOT NULL,
    invoiceDate DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    payableId INT NOT NULL REFERENCES Finance.accountpayables(PayableID) ON DELETE CASCADE
    --created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    --PRIMARY KEY (ap_ext_id,InvoiceDate)
);    
    
-- ============================================
-- 16. INVENTORY AUDIT
-- ============================================
    DROP TABLE IF EXISTS Finance.inventoryaudits CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.inventoryaudits (
        managementId SERIAL PRIMARY KEY, 
        productId INT NOT NULL,
        warehouseId INT NOT NULL,
        transactionId INT NOT NULL,
        actionType VARCHAR(50) NOT NULL, -- CHECK (ActionType IN ('Purchase', 'Sale', 'Sale Return', 'Purchase Return', 'Transfer')),
        quantity INT NOT NULL CHECK (quantity > 0),
        movementDate DATE NOT NULL,
        FOREIGN KEY (ProductID) REFERENCES Finance.products(ProductID) ON DELETE CASCADE,
        FOREIGN KEY (WarehouseID) REFERENCES Finance.warehouses(WarehouseID) ON DELETE CASCADE,
        FOREIGN KEY (TransactionID) REFERENCES Finance.transactions(TransactionID) ON DELETE CASCADE
        --PRIMARY KEY (ManagementID,MovementDate)
    ); --PARTITION BY RANGE(MovementDate);

-- ============================================
-- 17. PURCHASE RETURNS
-- ============================================
    DROP TABLE IF EXISTS Finance.purchasereturns CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.purchasereturns  (
        returnId SERIAL PRIMARY KEY,
        payableId INT NOT NULL,
        returnAmount DECIMAL(10, 2) NOT NULL CHECK (returnAmount >= 0),
        returnDate DATE NOT NULL,
	FOREIGN KEY (PayableID) REFERENCES Finance.accountpayables(PayableID) ON DELETE CASCADE
        );
	
-- ============================================
-- 18. SALES  RETURNS
-- ============================================
    DROP TABLE IF EXISTS Finance.salereturns CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.salereturns  (
        returnId SERIAL PRIMARY KEY,
        receivableId INT NOT NULL,
        returnAmount DECIMAL(10, 2) NOT NULL CHECK (returnAmount >= 0),
        returnDate DATE NOT NULL,
        FOREIGN KEY (ReceivableID) REFERENCES Finance.accountreceivables(ReceivableID) ON DELETE CASCADE
        );

-- ============================================
-- 19. INVENTORY TRANSFER
-- ============================================
    DROP TABLE IF EXISTS Finance.inventorytransfers CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.inventorytransfers (
        transferId SERIAL PRIMARY KEY,
        fromLocationId INT NOT NULL,
        toLocationId INT NOT NULL,
        productId INT NOT NULL,
        quantity INT NOT NULL CHECK (quantity > 0),
        transferDate DATE NOT NULL DEFAULT CURRENT_DATE,
        Notes TEXT,
        FOREIGN KEY (FromLocationID) REFERENCES Finance.warehouses(WarehouseID) ON DELETE CASCADE,
        FOREIGN KEY (ToLocationID) REFERENCES Finance.warehouses(WarehouseID) ON DELETE CASCADE,
        FOREIGN KEY (ProductID) REFERENCES Finance.products(ProductID) ON DELETE CASCADE
    );

-- ============================================
-- 20. AUDIT LOGS
-- ============================================
    DROP TABLE IF EXISTS Finance.auditlogs CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.auditlogs (
        auditId SERIAL PRIMARY KEY,
        tableName VARCHAR(50) NOT NULL,
        recTransact TEXT NOT NULL,
        operation VARCHAR(20) NOT NULL,  -- CHECK (Operation IN ('INSERT', 'UPDATE', 'DELETE')),
        logTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        changedBy VARCHAR(50) NOT NULL,
        prev_hash TEXT,
        row_hash TEXT
    );

-- ============================================
-- 21. EVENT LOG
-- ============================================    
DROP TABLE IF  EXISTS Finance.event_log CASCADE;
CREATE TABLE IF NOT EXISTS Finance.event_log (
    eventId SERIAL PRIMARY KEY,
    eventType VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    idempotencyKey TEXT UNIQUE NOT NULL,
    createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processedAt TIMESTAMP
);    
COMMIT;