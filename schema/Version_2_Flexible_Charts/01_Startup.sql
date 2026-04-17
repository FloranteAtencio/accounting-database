--CREATE DATABASE erp_db;

CREATE SCHEMA Finance;

-- Finance team: read-only access
CREATE ROLE finance_readonly;

-- Developers: full access to schema
CREATE ROLE dev_role;

-- Admins: elevated privileges
CREATE ROLE admin_role;

-- Finance analyst
CREATE USER analyst WITH PASSWORD 'finance123';

-- Developer
CREATE USER dev_user WITH PASSWORD 'devpass123';

-- Admin
CREATE USER admin_user WITH PASSWORD 'adminpass123';

GRANT finance_readonly TO analyst;
GRANT dev_role TO dev_user;
GRANT admin_role TO admin_user;

-- Developers: full privileges on 
---Database
GRANT CONNECT ON DATABASE erp_db TO dev_role;
--Schema privileges
GRANT USAGE, CREATE ON SCHEMA Finance TO dev_role;
--Table privileges
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA Finance TO dev_role;

-- Finance team: can only read data
--database privileges
GRANT CONNECT ON DATABASE erp_db TO finance_readonly;
--schema privileges
GRANT USAGE ON SCHEMA Finance TO finance_readonly;
--table privileges
GRANT SELECT ON ALL TABLES IN SCHEMA Finance TO finance_readonly;


-- Admins: manage everything
--database privileges
GRANT CONNECT ON DATABASE erp_db TO admin_role;
GRANT ALL PRIVILEGES ON DATABASE erp_db TO admin_role;
--schema privileges
GRANT ALL PRIVILEGES ON SCHEMA Finance TO admin_role;
GRANT ALL PRIVILEGES ON SCHEMA public TO admin_role;
--table privileges
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA Finance TO admin_role;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_role;
--sequence privileges
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Finance TO admin_role;

\c erp_db

-- CREATE TABLESPACE hotspace LOCATION '/mnt/ssd_hot';
-- CREATE TABLESPACE coldspace LOCATION '/mnt/hdd_cold';