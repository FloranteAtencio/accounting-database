---========================================
--- FINANCE EVENT LOG
--=========================================

---========================================
--- Finance Table
--=========================================

CREATE TABLE Finance.event_log (
    EventID SERIAL PRIMARY KEY,
    EventType VARCHAR(50) NOT NULL,
    Payload JSONB NOT NULL,
    Status VARCHAR(20) DEFAULT 'PENDING',
    IdempotencyKey TEXT UNIQUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ProcessedAt TIMESTAMP
);


---========================================
--- Insert into and parametarized
--=========================================

CREATE OR REPLACE PROCEDURE Finance.process_inventory_transaction(...)
AS $$
BEGIN
    INSERT INTO Finance.event_log (
        EventType,
        Payload,
        IdempotencyKey
    )
    VALUES (
        'INVENTORY',
        jsonb_build_object(
            'product_id', p_product_id,
            'warehouse_id', p_warehouse_id,
            'action_type', p_action_type,
            'quantity', p_quantity,
            'date', p_date,
            'reference_id', p_reference_id
        ),
        p_idempotency_key
    )
    ON CONFLICT (IdempotencyKey) DO NOTHING;
END;
$$;

INSERT INTO Finance.event_log (EventType, Payload, IdempotencyKey)
VALUES (
    'SALE',
    jsonb_build_object(
        'product_id', 1,
        'warehouse_id', 1,
        'quantity', 5,
        'price', 100,
        'customer_id', 10,
        'date', CURRENT_DATE
    ),
    'sale-2026-0001'
)
ON CONFLICT (IdempotencyKey) DO NOTHING;


---========================================
--- Automate process
--=========================================

CREATE OR REPLACE PROCEDURE Finance.process_events()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT * FROM Finance.event_log
        WHERE Status = 'PENDING'
        ORDER BY EventID
    LOOP
        BEGIN
            -- route based on event type
            IF rec.EventType = 'SALE' THEN
                CALL Finance.handle_sale(rec.Payload);

            ELSIF rec.EventType = 'PURCHASE' THEN
                CALL Finance.handle_purchase(rec.Payload);

            ELSIF rec.EventType = 'RETURN' THEN
                CALL Finance.handle_return(rec.Payload);

            ELSE
                RAISE EXCEPTION 'Unknown event type';
            END IF;

            -- mark success
            UPDATE Finance.event_log
            SET Status = 'PROCESSED',
                ProcessedAt = CURRENT_TIMESTAMP
            WHERE EventID = rec.EventID;

        EXCEPTION
            WHEN OTHERS THEN
                UPDATE Finance.event_log
                SET Status = 'FAILED'
                WHERE EventID = rec.EventID;
        END;
    END LOOP;
END;
$$;

---========================================
--- Handle Transaction
--=========================================

CREATE OR REPLACE PROCEDURE Finance.handle_sale(p_payload JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaction_id INT;
BEGIN
    -- create transaction
    INSERT INTO Finance.transactions (Description)
    VALUES ('Sale event')
    RETURNING TransactionID INTO v_transaction_id;

    -- inventory
    CALL Finance.inventory_module(
        (p_payload->>'product_id')::INT,
        (p_payload->>'warehouse_id')::INT,
        v_transaction_id,
        'Sale',
        (p_payload->>'quantity')::INT,
        (p_payload->>'date')::DATE
    );

    -- accounting
    CALL Finance.accounting_module(
        v_transaction_id,
        (p_payload->>'product_id')::INT,
        'Sale',
        (p_payload->>'quantity')::INT,
        (p_payload->>'date')::DATE,
        (p_payload->>'customer_id')::INT
    );

END;
$$;



