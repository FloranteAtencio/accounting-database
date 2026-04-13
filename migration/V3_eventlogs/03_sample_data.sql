INSERT INTO Finance.event_log (EventType, Payload,idempotencyKey)
VALUES (
    'SALE',
    jsonb_build_object(
        'product_id', 1,
        'warehouse_id', 1,
        'quantity', 5,
        'price', 100,
        'action_type','Sale',
        'customer_id', 1,
        'date', CURRENT_DATE,
        'idempotency_key','sale-2026-0001'
    )
    ,'sale-2026-0001'
);

INSERT INTO Finance.event_log (EventType, Payload,idempotencyKey)
VALUES (
    'PURCHASE',
    jsonb_build_object(
        'product_id', 1,
        'warehouse_id', 1,
        'quantity', 20,
        'action_type','Purchase',
        'customer_id', 1,
        'date', CURRENT_DATE,
        'idempotency_key','sale-2026-0002'
    )
    ,'sale-2026-0002'
);