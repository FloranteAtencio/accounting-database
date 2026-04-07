---========================================
--- Reconciliation 
---========================================

---========================================
-- Critical Reconciliation Journal Balance check
---========================================
SELECT 
    TransactionID,
    SUM(CASE WHEN Journal = TRUE THEN Amount ELSE 0 END) AS total_debit,
    SUM(CASE WHEN Journal = FALSE THEN Amount ELSE 0 END) AS total_credit
FROM Finance.journals
GROUP BY TransactionID
HAVING SUM(CASE WHEN Journal = TRUE THEN Amount ELSE 0 END)
     != SUM(CASE WHEN Journal = FALSE THEN Amount ELSE 0 END);

---=======================================
-- Inventory vs movement check
---=======================================

SELECT
    ProductID,
    SUM(CASE
        WHEN ActionType IN ('Purchase','Sales Return') THEN Quantity
        WHEN ActionType IN ('Sales', 'Purchase Return') THEN -Quantity
        ELSE 0
    END ) AS calculated_stock
FROM Finance.inventoryaudits
GROUP BY ProductID;
---=======================================
--- Cash vs Transaction Check
---=======================================

SELECT 
    SUM(CASE WHEN c.Account = 'Cash/Bank' AND j.Journal = TRUE THEN j.Amount ELSE 0 END) -
    SUM(CASE WHEN c.Account = 'Cash/Bank' AND j.Journal = FALSE THEN j.Amount ELSE 0 END)
    AS cash_balance
FROM Finance.journals j
JOIN Finance.charts c ON j.ChartID = c.ChartID;
---=======================================
--- simple tax report
---=======================================
SELECT
    SUM(CASE WHEN c.Type = 'Revenue' THEN j.Amount ELSE 0 END) AS total_revenue,
    SUM(CASE WHEN c.Type = 'Expense' THEN j.Amount ELSE 0 END) AS total_expense,
    SUM(CASE WHEN c.Type = 'Revenue' THEN j.Amount ELSE 0 END) -
    SUM(CASE WHEN c.Type = 'Expense' THEN j.Amount ELSE 0 END) AS net_income
FROM Finance.journals j
JOIN Finance.charts c ON j.ChartID = c.ChartID
WHERE j.Date BETWEEN '2026-01-01' AND '2026-12-31';

---========================================
-- Functions 
---========================================

-- v_tax := v_price * p_quantity * 0.12;
-- v_base := v_price * p_quantity;

-- -- store tax
-- INSERT INTO Finance.tax_entries
-- (TransactionID, TaxType, TaxRate, TaxAmount, BaseAmount)
-- VALUES
-- (v_transaction_id, 'VAT_OUTPUT', 12, v_tax, v_base);

CREATE OR REPLACE FUNCTION Finance.get_vat_summary(start_date DATE, end_date DATE)
RETURNS TABLE (
    TaxType VARCHAR,
    TotalTax DECIMAL
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        TaxType,
        SUM(TaxAmount)
    FROM Finance.tax_entries
    WHERE TransactionID IN (
        SELECT TransactionID 
        FROM Finance.transactions
        WHERE Description IS NOT NULL
    )
    GROUP BY TaxType;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Finance.check_journal_balance()
RETURNS TABLE (
    TransactionID INT,
    TotalDebit DECIMAL,
    TotalCredit DECIMAL,
    Difference DECIMAL
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        j.TransactionID,
        SUM(CASE WHEN j.Journal = TRUE THEN j.Amount ELSE 0 END) AS TotalDebit,
        SUM(CASE WHEN j.Journal = FALSE THEN j.Amount ELSE 0 END) AS TotalCredit,
        SUM(CASE WHEN j.Journal = TRUE THEN j.Amount ELSE 0 END) -
        SUM(CASE WHEN j.Journal = FALSE THEN j.Amount ELSE 0 END) AS Difference
    FROM Finance.journals j
    GROUP BY j.TransactionID
    HAVING 
        SUM(CASE WHEN j.Journal = TRUE THEN j.Amount ELSE 0 END) <>
        SUM(CASE WHEN j.Journal = FALSE THEN j.Amount ELSE 0 END);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Finance.reconcile_ar()
RETURNS TABLE (
    TransactionID INT,
    AR_Amount DECIMAL,
    Journal_Amount DECIMAL,
    Difference DECIMAL
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ar.TransactionID,
        ar.Amount,
        SUM(CASE 
            WHEN c.Account = 'Accounts Receivable' AND j.Journal = TRUE 
            THEN j.Amount ELSE 0 END),
        ar.Amount - SUM(CASE 
            WHEN c.Account = 'Accounts Receivable' AND j.Journal = TRUE 
            THEN j.Amount ELSE 0 END)
    FROM Finance.accountreceivables ar
    JOIN Finance.journals j ON ar.TransactionID = j.TransactionID
    JOIN Finance.charts c ON j.ChartID = c.ChartID
    GROUP BY ar.TransactionID, ar.Amount
    HAVING ar.Amount <> SUM(CASE 
        WHEN c.Account = 'Accounts Receivable' AND j.Journal = TRUE 
        THEN j.Amount ELSE 0 END);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Finance.reconcile_ap()
RETURNS TABLE (
    TransactionID INT,
    AP_Amount DECIMAL,
    Journal_Amount DECIMAL,
    Difference DECIMAL
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ap.TransactionID,
        ap.Amount,
        SUM(CASE 
            WHEN c.Account = 'Accounts Payable' AND j.Journal = FALSE 
            THEN j.Amount ELSE 0 END),
        ap.Amount - SUM(CASE 
            WHEN c.Account = 'Accounts Payable' AND j.Journal = FALSE 
            THEN j.Amount ELSE 0 END)
    FROM Finance.accountpayables ap
    JOIN Finance.journals j ON ap.TransactionID = j.TransactionID
    JOIN Finance.charts c ON j.ChartID = c.ChartID
    GROUP BY ap.TransactionID, ap.Amount
    HAVING ap.Amount <> SUM(CASE 
        WHEN c.Account = 'Accounts Payable' AND j.Journal = FALSE 
        THEN j.Amount ELSE 0 END);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Finance.reconcile_inventory()
RETURNS TABLE (
    ProductID INT,
    TotalIn INT,
    TotalOut INT,
    NetMovement INT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ProductID,
        SUM(CASE WHEN ActionType IN ('Purchase','Sale Return') THEN Quantity ELSE 0 END),
        SUM(CASE WHEN ActionType IN ('Sale','Purchase Return') THEN Quantity ELSE 0 END),
        SUM(CASE WHEN ActionType IN ('Purchase','Sale Return') THEN Quantity ELSE 0 END) -
        SUM(CASE WHEN ActionType IN ('Sale','Purchase Return') THEN Quantity ELSE 0 END)
    FROM Finance.inventoryaudits
    GROUP BY ProductID;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Finance.reconcile_tax()
RETURNS TABLE (
    TransactionID INT,
    TaxAmount DECIMAL,
    JournalTax DECIMAL,
    Difference DECIMAL
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.TransactionID,
        SUM(t.TaxAmount),
        SUM(CASE 
            WHEN c.Account ILIKE '%tax%' THEN j.Amount 
            ELSE 0 END),
        SUM(t.TaxAmount) - SUM(CASE 
            WHEN c.Account ILIKE '%tax%' THEN j.Amount 
            ELSE 0 END)
    FROM Finance.tax_entries t
    JOIN Finance.journals j ON t.TransactionID = j.TransactionID
    JOIN Finance.charts c ON j.ChartID = c.ChartID
    GROUP BY t.TransactionID
    HAVING SUM(t.TaxAmount) <> SUM(CASE 
        WHEN c.Account ILIKE '%tax%' THEN j.Amount 
        ELSE 0 END);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Finance.reconciliation_summary()
RETURNS TABLE (
    CheckType VARCHAR,
    IssuesFound INT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 'Journal Balance', COUNT(*) FROM Finance.check_journal_balance()
    UNION ALL
    SELECT 'AR Mismatch', COUNT(*) FROM Finance.reconcile_ar()
    UNION ALL
    SELECT 'AP Mismatch', COUNT(*) FROM Finance.reconcile_ap()
    UNION ALL
    SELECT 'Tax Mismatch', COUNT(*) FROM Finance.reconcile_tax();
END;
$$ LANGUAGE plpgsql;