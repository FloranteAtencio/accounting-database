CREATE TABLE Finance.event_log (
    EventID SERIAL PRIMARY KEY,
    EventType VARCHAR(50) NOT NULL,
    Payload JSONB NOT NULL,
    Status VARCHAR(20) DEFAULT 'PENDING',
    IdempotencyKey TEXT UNIQUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessedAt TIMESTAMP
);