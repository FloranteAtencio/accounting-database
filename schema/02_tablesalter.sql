ALTER TABLE Finance.transactions
ADD COLUMN idempotencyKey TEXT UNIQUE;

ALTER TABLE Finance.auditlogs
ADD COLUMN prev_hash TEXT,
ADD COLUMN row_hash TEXT;