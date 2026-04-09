INSERT INTO Finance.event_log (EventType, Payload,idempotencyKey)
VALUES (
    'SALE',
    jsonb_build_object(
        'product_id', 1,
        'warehouse_id', 1,
        'quantity', 5,
        'price', 100,
        'customer_id', 10,
        'date', CURRENT_DATE,
        'idempotency_key','sale-2026-0001'
    )
    ,'sale-2026-0001'
);