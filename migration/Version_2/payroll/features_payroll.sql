BEGIN;

SELECT 'Payroll table loading';

-- ============================================
-- PAYROLL BATCHES (Import Logs Only)
-- ============================================
CREATE TABLE Finance.payroll_batches (
    batch_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    file_name VARCHAR(255),
    period_start DATE,
    period_end DATE,
    -- DONT store totals here. If you need them, make them GENERATED columns based on the journal entry
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSED', 'FAILED')),
    journal_entry_id BIGINT REFERENCES Finance.journal_entries(entry_id), -- THE SINGLE SOURCE OF TRUTH
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Note: The 'total_gross' and 'total_net' should be retrieved by summing the journal_entry linked here.

SELECT 'Payroll tabled loaded complete!';

COMMIT;