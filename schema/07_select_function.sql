--General Journal
CREATE OR REPLACE FUNCTION Finance.getgeneraljournal(startDate DATE, endDate DATE)
RETURNS TABLE (
    TransactionID INT,
    Date DATE,
    Description VARCHAR(100),
    Account VARCHAR(30),
    Debit DECIMAL(10, 2),
    Credit DECIMAL(10, 2)
) AS $$
BEGIN

    SELECT 
        t.TransactionID,
        d.Date,
        t.Description,
        c.Account,
        CASE WHEN d.Journal = 1 THEN d.Amount ELSE 0 END AS Debit,
        CASE WHEN d.Journal = 0 THEN d.Amount ELSE 0 END AS Credit
    FROM Finance.Transactions t
    JOIN Finance.Journals d ON t.TransactionID = d.TransactionID
    JOIN Finance.Charts c ON d.ChartID = c.ChartID
    WHERE d.Date BETWEEN startDate AND endDate
    ORDER BY d.Date, t.TransactionID;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

    
END;
$$ LANGUAGE plpgsql;

--General Ledger
CREATE OR REPLACE FUNCTION Finance.getgeneralledger(startdate DATE, enddate DATE) 
RETURNS TABLE (
    Account VARCHAR(30), 
    Date DATE, 
    Description VARCHAR(100), 
    Debit DECIMAL(12,2), 
    Credit DECIMAL(12,2)
    ) 
AS $$
BEGIN

    SELECT 
        c.Account,
        d.Date,
        t.Description,
        CASE WHEN d.Journal = 1 THEN d.Amount ELSE 0 END AS Debit,
        CASE WHEN d.Journal = 0 THEN d.Amount ELSE 0 END AS Credit
    FROM Finance.Charts c
    JOIN Finance.Journals d ON c.ChartID = d.ChartID
    JOIN Finance.Transactions t ON d.TransactionID = t.TransactionID
    WHERE d.Date BETWEEN startdate AND enddate
    ORDER BY c.Account, d.Date, t.TransactionID;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

    
END;
$$ LANGUAGE plpgsql;

----Trial Balance
CREATE OR REPLACE FUNCTION Finance.gettrialbalance(startdate DATE, enddate DATE)
RETURNS TABLE (
    Account VARCHAR(100),
    Type VARCHAR(100),
    TotalDebit DECIMAL(12,2),
    TotalCredit DECIMAL(12,2)
)
AS $$
BEGIN

    SELECT 
        c.Account,
        c.Type,
        SUM(CASE WHEN d.Journal = 1 THEN d.Amount ELSE 0 END) AS TotalDebit,
        SUM(CASE WHEN d.Journal = 0 THEN d.Amount ELSE 0 END) AS TotalCredit
    FROM Finance.Transactions t
    JOIN Finance.Journals d on d.TransactionID = t.TransactionID
    JOIN Finance.Charts c ON d.ChartID = c.ChartID
    WHERE d.Date BETWEEN startdate AND enddate
    GROUP BY c.Account, c.Type 
    ORDER BY c.Type, c.Account;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

END;
$$ LANGUAGE plpgsql;

---Income Statement
CREATE OR REPLACE FUNCTION Finance.getincomestatement (startdate DATE, enddate DATE)
RETURNS TABLE (
    Type VARCHAR(50),
    Account VARCHAR(50),
    NetAmount DECIMAL(12,2)
)
AS $$
BEGIN

    SELECT 
        c.Type,
        c.Account,
        SUM(CASE WHEN d.Journal = 1 THEN d.Amount ELSE 0 END) -
        SUM(CASE WHEN d.Journal = 0 THEN d.Amount ELSE 0 END) AS NetAmount
    FROM Finance.Charts c
    JOIN Finance.Journals d ON c.ChartID = d.ChartID
    JOIN Finance.Transactions t ON t.TransactionID = d.TransactionID    
    WHERE c.Type IN ('Revenue','Expense','Cost of Goods Sold') AND d.Date BETWEEN startdate AND enddate 
    GROUP BY c.Type, c.Account
    ORDER BY c.Type, c.Account;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

    
END;
$$ LANGUAGE plpgsql;

--Balance Sheet
CREATE OR REPLACE FUNCTION Finance.getbalancesheet(startdate DATE, enddate DATE) 
RETURNS TABLE (
    Type VARCHAR(100),
    Account VARCHAR(100),
    Balance DECIMAL(12,2)
)
AS $$
BEGIN

    SELECT 
        c.Type,
        c.Account,
        SUM(CASE WHEN d.Journal = 1 THEN d.Amount ELSE 0 END) -
        SUM(CASE WHEN d.Journal = 0 THEN d.Amount ELSE 0 END) AS Balance
    FROM Finance.Charts c
    JOIN Finance.Journals d ON c.ChartID = d.ChartID    
    JOIN Finance.Transactions t ON t.TransactionID = d.TransactionID
    WHERE c.Type IN ('Asset','Liability','Equity') AND t.Date BETWEEN startdate AND enddate
    GROUP BY c.Type, c.Account
    ORDER BY c.Type, c.Account;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Transaction failed: %', SQLERRM;

    
END;
$$ LANGUAGE plpgsql;


