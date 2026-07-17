-- ======================
-- 04 Table alters
-- 
-- ======================

BEGIN;

ALTER TABLE Finance.warehouses ADD COLUMN client_id INT REFERENCES Finance.clients (client_id);

ALTER TABLE Finance.operations ADD COLUMN client_id INT REFERENCES Finance.clients (client_id);

ALTER TABLE Finance.vendors ADD COLUMN client_id INT REFERENCES Finance.clients (client_id);

ALTER TABLE Finance.customers ADD COLUMN client_id INT REFERENCES Finance.clients (client_id);

ALTER TABLE Finance.inventory_audits ADD COLUMN client_id INT REFERENCES Finance.clients (client_id);

ALTER TABLE Finance.product ADD COLUMN client_id INT REFERENCES Finance.clients (client_id);

ALTER TABLE Finance.clients 
    ADD inventory_method VARCHAR(20) CHECK ( inventory_method IN ('PERPETUAL','PERIODIC')),
    ADD inventory_cost_method VARCHAR(20) CHECK ( inventory_cost_method IN ('FIFO','LIFO','AVCO'));
COMMIT;

SELECT 'Table alter Loaded complete ' as Status;