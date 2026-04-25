-- New tables to add

-- ============================================
-- 1. RECURRING TRANSACTION TEMPLATES
-- ============================================
CREATE TABLE Finance.recurring_templates (
    template_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    template_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    UNIQUE(client_id, template_name)
);

-- ============================================
-- 2. RECURRING TRANSACTION RULES
-- ============================================
CREATE TABLE Finance.recurring_rules (
    rule_id BIGSERIAL PRIMARY KEY,
    template_id INT NOT NULL REFERENCES Finance.recurring_templates(template_id) ON DELETE CASCADE,
    frequency VARCHAR(20) NOT NULL CHECK (frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUAL')),
    day_of_month INT CHECK (day_of_month BETWEEN 1 AND 31),
    day_of_week INT CHECK (day_of_week BETWEEN 0 AND 6),  -- 0=Sunday
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 3. RECURRING TRANSACTION DETAILS
-- ============================================
CREATE TABLE Finance.recurring_details (
    detail_id BIGSERIAL PRIMARY KEY,
    template_id INT NOT NULL REFERENCES Finance.recurring_templates(template_id) ON DELETE CASCADE,
    chart_id INT NOT NULL REFERENCES Finance.charts(chart_id),
    amount DECIMAL(15,2) NOT NULL,
    is_debit BOOLEAN NOT NULL,
    description TEXT,
    sequence_order INT
);

-- ============================================
-- 4. RECURRING EXECUTION HISTORY
-- ============================================
CREATE TABLE Finance.recurring_executions (
    execution_id BIGSERIAL PRIMARY KEY,
    template_id INT NOT NULL REFERENCES Finance.recurring_templates(template_id),
    transaction_id INT REFERENCES Finance.transactions(transaction_id),
    scheduled_date DATE NOT NULL,
    executed_date TIMESTAMP,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'EXECUTED', 'FAILED', 'SKIPPED')),
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);