--- SQL script to create tables for Inventory Management System
--- First part is Journal and Charts, second part is Inventory
-------------- 1️⃣ Schema Tables ------------------
-- CREATE OR REPLACE PROCEDURE Finance.schema_tables(

-- ) LANGUAGE plpgsql AS $$
BEGIN;
    DROP TABLE IF EXISTS Finance.charts CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.charts (
        ChartID SERIAL PRIMARY KEY,
        Account VARCHAR(100) NOT NULL,
        Type VARCHAR(50) NOT NULL -- CHECK (Type IN ('Asset', 'Liability', 'Equity', 'Revenue', 'Expense','Contra Revenue','Contra Asset','Contra Liability','Contra Equity','Contra Expense'))  
    );

    DROP TABLE IF EXISTS Finance.transactions CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.transactions (
        TransactionID SERIAL PRIMARY KEY,
        Description VARCHAR(100) NOT NULL
    );

    DROP TABLE IF EXISTS Finance.journals CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.journals (
        JournalID SERIAL,
        TransactionID INT NOT NULL,
        ChartID INT NOT NULL,
        Date DATE NOT NULL,
        Journal BOOLEAN NOT NULL CHECK (Journal IN (TRUE, FALSE)),
        Amount DECIMAL(10, 2) NOT NULL CHECK (Amount >= 0),
        FOREIGN KEY (TransactionID) REFERENCES Finance.transactions(TransactionID) ON DELETE NO ACTION,
        FOREIGN KEY (ChartID) REFERENCES Finance.charts(ChartID) ON DELETE NO ACTION,
        PRIMARY KEY(JournalID, Date)
    ) PARTITION BY RANGE (Date);   

    DROP TABLE IF EXISTS Finance.customers CASCADE;
    CREATE TABLE Finance.customers (
        CustomerID SERIAL PRIMARY KEY,
        CustomerName VARCHAR(50) NOT NULL,
        ContactInfo VARCHAR(15) NOT NULL,
        Email VARCHAR(50) NOT NULL CHECK (Email LIKE '%@%'),
        Address VARCHAR(100) NOT NULL
    );

    DROP TABLE IF EXISTS Finance.suppliers CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.suppliers (
        SupplierID SERIAL PRIMARY KEY,
        SupplierName VARCHAR(50) NOT NULL,
        ContactInfo VARCHAR(15) NOT NULL,
        Email VARCHAR(50) NOT NULL CHECK (Email LIKE '%@%'),
        Address VARCHAR(100) NOT NULL
    );

    DROP TABLE IF EXISTS Finance.products CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.products (
        ProductID SERIAL PRIMARY KEY,
        ProductName VARCHAR(50) NOT NULL,
        Description VARCHAR(200),
        ProductUnit VARCHAR(20) NOT NULL,
        ProductCost DECIMAL(10, 2) NOT NULL CHECK (Productcost >= 0),
        ProductPrice DECIMAL(10, 2) NOT NULL CHECK (Productprice >= 0)
    );

    DROP TABLE IF EXISTS Finance.warehouses CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.warehouses (
        WarehouseID SERIAL PRIMARY KEY,
        WarehouseName VARCHAR(50) NOT NULL,
        Location VARCHAR(100) NOT NULL
    );

    DROP TABLE IF EXISTS Finance.inventoryaudits CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.inventoryaudits (
        ManagementID SERIAL, 
        ProductID INT NOT NULL,
        WarehouseID INT NOT NULL,
        TransactionID INT NOT NULL,
        ActionType VARCHAR(50) NOT NULL, -- CHECK (ActionType IN ('Purchase', 'Sale', 'Sale Return', 'Purchase Return', 'Transfer')),
        Quantity INT NOT NULL CHECK (Quantity > 0),
        MovementDate DATE NOT NULL,
        FOREIGN KEY (ProductID) REFERENCES Finance.products(ProductID) ON DELETE NO ACTION,
        FOREIGN KEY (WarehouseID) REFERENCES Finance.warehouses(WarehouseID) ON DELETE NO ACTION,
        FOREIGN KEY (TransactionID) REFERENCES Finance.transactions(TransactionID) ON DELETE NO ACTION,
        PRIMARY KEY (ManagementID,MovementDate)
    )PARTITION BY RANGE(MovementDate);

   DROP TABLE IF EXISTS Finance.accountpayables CASCADE;
   CREATE TABLE IF NOT EXISTS Finance.accountpayables (
	PayableID SERIAL,
        SupplierID INT NOT NULL,
        TransactionID INT NOT NULL,
	FOREIGN KEY (SupplierID) REFERENCES Finance.suppliers(SupplierID) ON DELETE NO ACTION,
        FOREIGN KEY (TransactionID) REFERENCES Finance.transactions(TransactionID) ON DELETE NO ACTION,
        PRIMARY KEY(PayableID)
    	);
	
   DROP TABLE IF EXISTS Finance.ap_ext CASCADE;
   CREATE TABLE IF NOT EXISTS Finance.ap_ext (
        AP_ID SERIAL,
	Amount DECIMAL(10, 2) NOT NULL CHECK (Amount >= 0),
        DueDate DATE NOT NULL,
        BillDate DATE NOT NULL,
        Status VARCHAR(20) NOT NULL, -- CHECK (Status IN ('Pend>
	PayableID INT NOT NULL,
	FOREIGN KEY (PayableID) REFERENCES Finance.accountpayables(PayableID) ON DELETE NO ACTION,
	PRIMARY KEY (AP_ID,BillDate)
	)PARTITION BY RANGE(BillDate);
	
    DROP TABLE IF EXISTS Finance.purchasereturns CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.purchasereturns  (
        ReturnID SERIAL PRIMARY KEY,
        PayableID INT NOT NULL,
        ReturnAmount DECIMAL(10, 2) NOT NULL CHECK (ReturnAmount >= 0),
        ReturnDate DATE NOT NULL,
	FOREIGN KEY (PayableID) REFERENCES Finance.accountpayables(PayableID) ON DELETE NO ACTION
        );
	
    DROP TABLE IF EXISTS Finance.accountreceivables CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.accountreceivables (
        ReceivableID SERIAL,
        CustomerID INT NOT NULL,
        TransactionID INT NOT NULL,
        FOREIGN KEY (CustomerID) REFERENCES Finance.customers(CustomerID) ON DELETE NO ACTION,
        FOREIGN KEY (TransactionID) REFERENCES Finance.transactions(TransactionID) ON DELETE NO ACTION,
        PRIMARY KEY (ReceivableID)
    );


    DROP TABLE IF EXISTS Finance.ar_ext CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.ar_ext (
	AR_ID SERIAL,
	Amount DECIMAL(10, 2) NOT NULL CHECK (Amount >= 0),
        DueDate DATE NOT NULL,
        InvoiceDate DATE NOT NULL,
        Status VARCHAR(20) NOT NULL, -- CHECK (Status IN ('Pend>
	ReceivableID INT NOT NULL,
	FOREIGN KEY (ReceivableID) REFERENCES Finance.accountreceivables(ReceivableID) ON DELETE NO ACTION,
	PRIMARY KEY (AR_ID,InvoiceDate)
    )PARTITION BY RANGE(InvoiceDate);

    DROP TABLE IF EXISTS Finance.salereturns CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.salereturns  (
        ReturnID SERIAL PRIMARY KEY,
        ReceivableID INT NOT NULL,
        ReturnAmount DECIMAL(10, 2) NOT NULL CHECK (ReturnAmount >= 0),
        ReturnDate DATE NOT NULL,
        FOREIGN KEY (ReceivableID) REFERENCES Finance.accountreceivables(ReceivableID) ON DELETE NO ACTION
        );

    DROP TABLE IF EXISTS Finance.inventorytransfers CASCADE;
    CREATE TABLE Finance.inventorytransfers (
        TransferID SERIAL PRIMARY KEY,
        FromLocationID INT NOT NULL,
        ToLocationID INT NOT NULL,
        ProductID INT NOT NULL,
        Quantity INT NOT NULL CHECK (Quantity > 0),
        TransferDate DATE NOT NULL DEFAULT CURRENT_DATE,
        Notes TEXT,
        FOREIGN KEY (FromLocationID) REFERENCES Finance.warehouses(WarehouseID) ON DELETE NO ACTION,
        FOREIGN KEY (ToLocationID) REFERENCES Finance.warehouses(WarehouseID) ON DELETE NO ACTION,
        FOREIGN KEY (ProductID) REFERENCES Finance.products(ProductID) ON DELETE NO ACTION
    );

    DROP TABLE IF EXISTS Finance.auditlogs CASCADE;
    CREATE TABLE IF NOT EXISTS Finance.auditlogs (
        AuditID SERIAL PRIMARY KEY,
        TableName VARCHAR(50) NOT NULL,
        RecTransact TEXT NOT NULL,
        Operation VARCHAR(20) NOT NULL,  -- CHECK (Operation IN ('INSERT', 'UPDATE', 'DELETE')),
        LogTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        ChangedBy VARCHAR(50) NOT NULL
    );    
--     EXCEPTION
--         WHEN OTHERS THEN
--             RAISE EXCEPTION 'Tables failed: %', SQLERRM;
            

-- -- END;        
-- -- $$;

-- -- BEGIN;
-- CALL Finance.schema_tables();
COMMIT;
