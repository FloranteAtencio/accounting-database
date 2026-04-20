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
    templateid SERIAL PRIMARY KEY,
    templatename VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2.1 COA TEMPLATES (for reference/defaults)
-- ============================================
DROP TABLE IF EXISTS Finance.coatemplateaccounts CASCADE;
CREATE TABLE IF NOT EXISTS Finance.coatemplateaccounts (
    templateaccountid SERIAL PRIMARY KEY,
    templateid INT NOT NULL REFERENCES Finance.coatemplates(templateid) ON DELETE CASCADE,
    accountcode INT NOT NULL,
    accountname VARCHAR(100) NOT NULL,
    accounttype VARCHAR(50) NOT NULL,
    UNIQUE(templateid, accountcode)
);


-- ============================================
-- 3. CHART OF ACCOUNTS (client-specific)
-- ============================================
DROP TABLE IF EXISTS Finance.charts CASCADE;
CREATE TABLE IF NOT EXISTS Finance.charts (
    chartId SERIAL PRIMARY KEY,
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
    TransactionID SERIAL PRIMARY KEY,
    Description TEXT NOT NULL,
    idempotencyKey VARCHAR(255) UNIQUE NOT NULL,
    clientId INT REFERENCES Finance.clients(clientId) ON DELETE NO ACTION,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 7. JOURNALS
-- ============================================
DROP TABLE IF EXISTS Finance.journals CASCADE;
CREATE TABLE IF NOT EXISTS Finance.journals (
    JournalID SERIAL PRIMARY KEY,
    TransactionID INT NOT NULL REFERENCES Finance.transactions(TransactionID) ON DELETE CASCADE,
    ChartID INT NOT NULL REFERENCES Finance.charts(chartId) ON DELETE CASCADE,
    Date DATE NOT NULL,
    Journal BOOLEAN NOT NULL CHECK (Journal IN (TRUE,FALSE)),  -- TRUE = Debit, FALSE = Credit
    Amount DECIMAL(12,2) NOT NULL CHECK  (Amount >= 0)
  --  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    --PRIMARY KEY (JournalID,Date)
);--PARTITION BY RANGE(Date);

-- ============================================
-- 8. CUSTOMERS
-- ============================================
    DROP TABLE IF EXISTS Finance.customers CASCADE;
    CREATE TABLE Finance.customers (
        CustomerID SERIAL PRIMARY KEY,
        CustomerName VARCHAR(50) NOT NULL,
        ContactInfo VARCHAR(15) NOT NULL,
        Email VARCHAR(50) NOT NULL CHECK (Email LIKE '%@%'),
        Address VARCHAR(100) NOT NULL
    );

-- ============================================
-- 9. SUPPLIER
-- ============================================
    DROP TABLE IF EXISTS Finance.suppliers CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.suppliers (
        SupplierID SERIAL PRIMARY KEY,
        SupplierName VARCHAR(50) NOT NULL,
        ContactInfo VARCHAR(15) NOT NULL,
        Email VARCHAR(50) NOT NULL CHECK (Email LIKE '%@%'),
        Address VARCHAR(100) NOT NULL
    );

-- ============================================
-- 10. PRODUCT
-- ============================================
    DROP TABLE IF EXISTS Finance.products CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.products (
        ProductID SERIAL PRIMARY KEY,
        ProductName VARCHAR(50) NOT NULL,
        Description VARCHAR(200),
        ProductUnit VARCHAR(20) NOT NULL,
        ProductCost DECIMAL(10, 2) NOT NULL CHECK (Productcost >= 0),
        ProductPrice DECIMAL(10, 2) NOT NULL CHECK (Productprice >= 0)
    );

-- ============================================
-- 11. WAREHOUSES
-- ============================================
    DROP TABLE IF EXISTS Finance.warehouses CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.warehouses (
        WarehouseID SERIAL PRIMARY KEY,
        WarehouseName VARCHAR(50) NOT NULL,
        Location VARCHAR(100) NOT NULL
    );


-- ============================================
-- 12. ACCOUNTS RECEIVABLE
-- ============================================
DROP TABLE IF EXISTS Finance.accountreceivables CASCADE;
CREATE TABLE IF NOT EXISTS Finance.accountreceivables (
    ReceivableID SERIAL PRIMARY KEY,
    TransactionID INT NOT NULL REFERENCES Finance.transactions(TransactionID) ON DELETE CASCADE,
    CustomerID INT NOT NULL REFERENCES Finance.customers(CustomerID) ON DELETE CASCADE
   -- created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 13. AR EXTENSION
-- ============================================
DROP TABLE IF EXISTS Finance.ar_ext CASCADE;
CREATE TABLE IF NOT EXISTS Finance.ar_ext (
    ar_ext_id SERIAL PRIMARY KEY,
    Amount DECIMAL(12,2) NOT NULL,
    DueDate DATE NOT NULL,
    InvoiceDate DATE NOT NULL,
    Status VARCHAR(20) NOT NULL,
    ReceivableID INT NOT NULL REFERENCES Finance.accountreceivables(ReceivableID) ON DELETE CASCADE
   -- created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    --PRIMARY KEY (ar_ext_id,InvoiceDate)
);  --PARTITION BY RANGE(InvoiceDate);

-- ============================================
-- 14. ACCOUNTS PAYABLE
-- ============================================
DROP TABLE IF EXISTS Finance.accountpayables CASCADE;
CREATE TABLE IF NOT EXISTS Finance.accountpayables (
    PayableID SERIAL PRIMARY KEY,
    TransactionID INT NOT NULL REFERENCES Finance.transactions(TransactionID) ON DELETE CASCADE,
    supplierID INT NOT NULL REFERENCES Finance.suppliers(SupplierID) ON DELETE CASCADE
    --created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 15. AP EXTENSION
-- ============================================
DROP TABLE IF EXISTS Finance.ap_ext CASCADE;
CREATE TABLE IF NOT EXISTS Finance.ap_ext (
    ap_ext_id SERIAL PRIMARY KEY,
    Amount DECIMAL(12,2) NOT NULL CHECK (Amount >= 0),
    DueDate DATE NOT NULL,
    InvoiceDate DATE NOT NULL,
    Status VARCHAR(20) NOT NULL,
    PayableID INT NOT NULL REFERENCES Finance.accountpayables(PayableID) ON DELETE CASCADE
    --created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    --PRIMARY KEY (ap_ext_id,InvoiceDate)
);    
    
-- ============================================
-- 16. INVENTORY AUDIT
-- ============================================
    DROP TABLE IF EXISTS Finance.inventoryaudits CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.inventoryaudits (
        ManagementID SERIAL PRIMARY KEY, 
        ProductID INT NOT NULL,
        WarehouseID INT NOT NULL,
        TransactionID INT NOT NULL,
        ActionType VARCHAR(50) NOT NULL, -- CHECK (ActionType IN ('Purchase', 'Sale', 'Sale Return', 'Purchase Return', 'Transfer')),
        Quantity INT NOT NULL CHECK (Quantity > 0),
        MovementDate DATE NOT NULL,
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
        ReturnID SERIAL PRIMARY KEY,
        PayableID INT NOT NULL,
        ReturnAmount DECIMAL(10, 2) NOT NULL CHECK (ReturnAmount >= 0),
        ReturnDate DATE NOT NULL,
	FOREIGN KEY (PayableID) REFERENCES Finance.accountpayables(PayableID) ON DELETE CASCADE
        );
	
-- ============================================
-- 18. SALES  RETURNS
-- ============================================
    DROP TABLE IF EXISTS Finance.salereturns CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.salereturns  (
        ReturnID SERIAL PRIMARY KEY,
        ReceivableID INT NOT NULL,
        ReturnAmount DECIMAL(10, 2) NOT NULL CHECK (ReturnAmount >= 0),
        ReturnDate DATE NOT NULL,
        FOREIGN KEY (ReceivableID) REFERENCES Finance.accountreceivables(ReceivableID) ON DELETE CASCADE
        );

-- ============================================
-- 19. INVENTORY TRANSFER
-- ============================================
    DROP TABLE IF EXISTS Finance.inventorytransfers CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.inventorytransfers (
        TransferID SERIAL PRIMARY KEY,
        FromLocationID INT NOT NULL,
        ToLocationID INT NOT NULL,
        ProductID INT NOT NULL,
        Quantity INT NOT NULL CHECK (Quantity > 0),
        TransferDate DATE NOT NULL DEFAULT CURRENT_DATE,
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
        AuditID SERIAL PRIMARY KEY,
        TableName VARCHAR(50) NOT NULL,
        RecTransact TEXT NOT NULL,
        Operation VARCHAR(20) NOT NULL,  -- CHECK (Operation IN ('INSERT', 'UPDATE', 'DELETE')),
        LogTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        ChangedBy VARCHAR(50) NOT NULL,
        prev_hash TEXT,
        row_hash TEXT
    );

-- ============================================
-- 21. EVENT LOG
-- ============================================    
DROP TABLE IF  EXISTS Finance.event_log CASCADE;
CREATE TABLE IF NOT EXISTS Finance.event_log (
    EventID SERIAL PRIMARY KEY,
    EventType VARCHAR(50) NOT NULL,
    Payload JSONB NOT NULL,
    Status VARCHAR(20) DEFAULT 'PENDING',
    IdempotencyKey TEXT UNIQUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessedAt TIMESTAMP
);    
COMMIT;