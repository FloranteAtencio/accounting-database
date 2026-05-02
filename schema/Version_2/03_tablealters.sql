ALTER TABLE Finance.warehouses ADD COLUMN client_id INT REFERENCES clients (client_id);

ALTER TABLE Finance.operations ADD COLUMN client_id INT REFERENCES clients (client_id);

ALTER TABLE Finance.suppliers ADD COLUMN client_id INT REFERENCES clients (client_id);

ALTER TABLE Finance.customers ADD COLUMN client_id INT REFERENCES clients (client_id);

ALTER TABLE Finance.clients 
ADD inventory_method VARCHAR(20) CHECK (inventory_method IN ('Perpertual','Periodic')),
ADD inventor_transaction VARCHAR(20) DEFAULT 'FIFO' CHECK (inventor_transaction IN ('LIFO','FIFO','AVOC'))