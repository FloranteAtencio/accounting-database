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
SELECT finance.partition_weekly_basis('ar_ext','finance');
SELECT finance.partition_weekly_basis('ap_ext','finance');

