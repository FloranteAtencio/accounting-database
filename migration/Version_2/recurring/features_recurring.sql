BEGIN;

SELECT 'Recurring table loading..';

-- ============================================
-- RECURRING EXECUTIONS
-- ============================================
CREATE TABLE Finance.recurring_executions (
    execution_id BIGSERIAL PRIMARY KEY,
    template_id INT NOT NULL REFERENCES Finance.recurring_templates(template_id),
    journal_entry_id BIGINT REFERENCES Finance.journal_entries(entry_id), -- Renamed for clarity
    scheduled_date DATE NOT NULL,
    executed_date TIMESTAMP,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'EXECUTED', 'FAILED', 'SKIPPED')),
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT 'Recurring table loaded';

COMMIT;