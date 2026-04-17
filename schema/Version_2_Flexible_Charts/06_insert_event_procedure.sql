CREATE OR REPLACE PROCEDURE Finance.process_events()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    retry_count INT := 0;
BEGIN
  FOR rec IN 
    SELECT *
    FROM Finance.event_log
    WHERE Status = 'PENDING'
    ORDER BY EventID
    FOR UPDATE SKIP LOCKED
    LOOP
        BEGIN
            -- route based on event type
            IF rec.EventType = 'SALE' THEN
                CALL Finance.handle_sale(rec.Payload);

            ELSIF rec.EventType = 'PURCHASE' THEN
                CALL Finance.handle_purchase(rec.Payload);

            ELSIF rec.EventType = 'RETURN' THEN
                CALL Finance.handle_return(rec.Payload);

            ELSIF rec.EventType = 'RECEIVABLE' THEN
                CALL Finance.handle_receivable(rec.Payload);
            
            ELSIF rec.EventType = 'PAYABLE' THEN
                CALL Finance.handle_payable(rec.Payload);
            
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
                SET RetryCount = RetryCount + 1
                WHERE EventID = rec.EventID
                RETURNING RetryCount INTO retry_count;

                IF retry_count >= 3 THEN
                    UPDATE Finance.event_log
                    SET Status = 'FAILED'
                    WHERE EventID = rec.EventID;
                ELSE
                    UPDATE Finance.event_log
                    SET Status = 'PENDING'
                    WHERE EventID = rec.EventID;
                END IF;
                RAISE EXCEPTION 'Stop immediately %', SQLERRM;
        END;
    END LOOP;
END;
$$;

---========================================
--- Handle Transaction Sale
--=========================================

CREATE OR REPLACE PROCEDURE Finance.handle_sale(p_payload JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaction_id INT;
BEGIN
    
    -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    PERFORM 1
    FROM Finance.products
    WHERE ProductID = (p_payload->>'product_id')::INT
    FOR UPDATE;

    PERFORM 1
    FROM Finance.warehouses
    WHERE WarehouseID = (p_payload->>'warehouse_id')::INT
    FOR UPDATE;

    PERFORM 1
    FROM Finance.customers
    WHERE CustomerID = (p_payload->>'customer_id')::INT
    FOR UPDATE;

    -- create transaction
    INSERT INTO Finance.transactions (Description,idempotencyKey)
    VALUES (CONCAT('Product ID : ',p_payload->>'product_id', 'Warehouse ID:',p_payload->>'warehouse_id', 'Action Type : ',p_payload->>'action_type','Quantity : ',p_payload->>'quantity','Date : ',p_payload->>'date')
    ,(p_payload->>'idempotency_key')::TEXT)
    ON CONFLICT (idempotencyKey) DO NOTHING
    RETURNING TransactionID INTO v_transaction_id;

     IF v_transaction_id IS NULL THEN
        SELECT TransactionID INTO v_transaction_id
        FROM Finance.transactions 
        WHERE idempotencyKey = p_payload->>'idempotency_key';
                
        RETURN;
    END IF;
    -- inventory
    CALL Finance.inventory_module(
        (p_payload->>'product_id')::INT,
        (p_payload->>'warehouse_id')::INT,
        v_transaction_id,
        (p_payload->>'action_type')::TEXT,
        (p_payload->>'quantity')::INT,
        (p_payload->>'date')::DATE
    );

    -- accounting
    CALL Finance.accounting_module(
        (p_payload->>'client_id')::INT,
        v_transaction_id,
        (p_payload->>'product_id')::INT,
        (p_payload->>'action_type')::TEXT,
        (p_payload->>'quantity')::INT,
        (p_payload->>'date')::DATE,
        (p_payload->>'customer_id')::INT
    );

    -- EXIT;

EXCEPTION
    WHEN OTHERS THEN
        -- ❌ Real error → stop immediately
        RAISE EXCEPTION 'Stop immediately %', SQLERRM;
    --     WHEN serialization_failure OR deadlock_detected THEN
    --         RAISE EXCEPTION 'Transaction failed %', SQLERRM;
    --             -- ⏳ Small delay before retry (helps contention)
    --             PERFORM pg_sleep(0.1);

END;
$$;


---========================================
--- Handle Transaction Purchase
--=========================================

CREATE OR REPLACE PROCEDURE Finance.handle_purchase(p_payload JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaction_id INT;
BEGIN

    -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    PERFORM 1
    FROM Finance.products
    WHERE ProductID = (p_payload->>'product_id')::INT
    FOR UPDATE;

    PERFORM 1
    FROM Finance.warehouses
    WHERE WarehouseID = (p_payload->>'warehouse_id')::INT
    FOR UPDATE;

    PERFORM 1
    FROM Finance.suppliers
    WHERE SupplierID = (p_payload->>'supplier_id')::INT
    FOR UPDATE;
    
    -- create transaction
    INSERT INTO Finance.transactions (Description, idempotencyKey)
    VALUES (CONCAT('Product ID : ',p_payload->>'product_id', 'Warehouse ID:',p_payload->>'warehouse_id', 'Action Type : ',p_payload->>'action_type','Quantity : ',p_payload->>'quantity','Date : ',p_payload->>'date')
    ,(p_payload->>'idempotency_key')::TEXT)
    ON CONFLICT (idempotencyKey) DO NOTHING
    RETURNING TransactionID INTO v_transaction_id;

     IF v_transaction_id IS NULL THEN
        SELECT TransactionID INTO v_transaction_id
        FROM Finance.transactions 
        WHERE idempotencyKey = p_payload->>'idempotency_key';
                
        RETURN;
    END IF;
    -- inventory
    CALL Finance.inventory_module(
        (p_payload->>'product_id')::INT,
        (p_payload->>'warehouse_id')::INT,
        v_transaction_id,
        (p_payload->>'action_type')::TEXT,
        (p_payload->>'quantity')::INT,
        (p_payload->>'date')::DATE
    );

    -- accounting
    CALL Finance.accounting_module(
        (p_payload->>'client_id')::INT,
        v_transaction_id,
        (p_payload->>'product_id')::INT,
        (p_payload->>'action_type')::TEXT,
        (p_payload->>'quantity')::INT,
        (p_payload->>'date')::DATE,
        (p_payload->>'supplier_id')::INT
    );

    -- EXIT;

EXCEPTION
    WHEN OTHERS THEN
    -- ❌ Real error → stop immediately
        RAISE EXCEPTION 'Stop immediately %', SQLERRM;
    -- WHEN serialization_failure OR deadlock_detected THEN
    --  RAISE EXCEPTION 'Transaction failed %', SQLERRM;
    --  -- ⏳ Small delay before retry (helps contention)
    --  PERFORM pg_sleep(0.1);

END;
$$;

---========================================
--- Handle Transaction Purchase
--=========================================

CREATE OR REPLACE PROCEDURE Finance.handle_return(p_payload JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaction_id INT;
BEGIN

    -- SET LOCAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    PERFORM 1
    FROM Finance.products
    WHERE ProductID = (p_payload->>'product_id')::INT
    FOR UPDATE;

    PERFORM 1
    FROM Finance.warehouses
    WHERE WarehouseID = (p_payload->>'warehouse_id')::INT
    FOR UPDATE;

    -- PERFORM 1
    -- FROM Finance.customers
    -- WHERE CustomerID = (p_payload->>'customer_id')::INT
    -- FOR UPDATE;
    


    -- create transaction
    INSERT INTO Finance.transactions (Description , idempotencyKey)
    VALUES (CONCAT('Product ID : ',p_payload->>'product_id', 'Warehouse ID:',p_payload->>'warehouse_id', 'Action Type : ',p_payload->>'action_type','Quantity : ',p_payload->>'quantity','Date : ',p_payload->>'date')
    ,(p_payload->>'idempotency_key')::TEXT)
    ON CONFLICT (idempotencyKey) DO NOTHING
    RETURNING TransactionID INTO v_transaction_id;

     IF v_transaction_id IS NULL THEN
        SELECT TransactionID INTO v_transaction_id
        FROM Finance.transactions 
        WHERE idempotencyKey = p_payload->>'idempotency_key';
                
        RETURN;
    END IF;
    
    -- inventory
    CALL Finance.inventory_module(
        (p_payload->>'product_id')::INT,
        (p_payload->>'warehouse_id')::INT,
        v_transaction_id,
        (p_payload->>'action_type')::TEXT,
        (p_payload->>'quantity')::INT,
        (p_payload->>'date')::DATE
    );

    -- accounting
    CALL Finance.return_module(
        (p_payload->>'client_id')::INT,
        v_transaction_id,
        (p_payload->>'product_id')::INT,
        (p_payload->>'action_type')::TEXT,
        (p_payload->>'quantity')::INT,
        (p_payload->>'date')::DATE,
        (p_payload->>'ref_id')::INT
    );

    -- EXIT;

EXCEPTION
    WHEN OTHERS THEN
    -- ❌ Real error → stop immediately
    RAISE EXCEPTION 'Stop immediately %', SQLERRM;
    -- WHEN serialization_failure OR deadlock_detected THEN
    --     RAISE EXCEPTION 'Transaction failed %', SQLERRM;
    --         -- ⏳ Small delay before retry (helps contention)
    --     PERFORM pg_sleep(0.1);
    
END;
$$;

CREATE OR REPLACE PROCEDURE Finance.handle_receivable(p_payload JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaction_id INT;
BEGIN
    -- create transaction
    -- INSERT INTO Finance.transactions (Description)
    -- VALUES (CONCAT('Produdct ID : ',p_payload->>'product_id', 'Warehouse ID:',p_payload->>'warehouse_id', 'Action Type : ',p_payload->>'action_type','Quantity : ',p_payload->>'quantity','Date : ',p_payload->>'date'))
    -- RETURNING TransactionID INTO v_transaction_id;

    -- inventory
    CALL Finance.ap_Transaction(
        (p_payload->>'client_id')::INT,
        (p_payload->>'supplier_id')::INT,
        (p_payload->>'due_date')::DATE,
        -- v_transaction_id,
        (p_payload->>'bill_date')::DATE,
        (p_payload->>'amount')::DECIMAL,
        (p_payload->>'status')::TEXT,
        (p_payload->>'idempotency_key')::TEXT
    );
END;
$$;

CREATE OR REPLACE PROCEDURE Finance.handle_payable(p_payload JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaction_id INT;
BEGIN
    -- create transaction
    -- INSERT INTO Finance.transactions (Description)
    -- VALUES (CONCAT('Produdct ID : ',p_payload->>'product_id', 'Warehouse ID:',p_payload->>'warehouse_id', 'Action Type : ',p_payload->>'action_type','Quantity : ',p_payload->>'quantity','Date : ',p_payload->>'date'))
    -- RETURNING TransactionID INTO v_transaction_id;

    -- inventory
    CALL Finance.ap_Transaction(
        (p_payload->>'client_id')::INT,
        (p_payload->>'customer_id')::INT,
        (p_payload->>'due_date')::DATE,
        -- v_transaction_id,
        (p_payload->>'invoice_date')::DATE,
        (p_payload->>'amount')::DECIMAL,
        (p_payload->>'status')::TEXT,
        (p_payload->>'idempotency_key')::TEXT
    );
END;
$$;