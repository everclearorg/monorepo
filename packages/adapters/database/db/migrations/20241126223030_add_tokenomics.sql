-- migrate:up
DO $do$ BEGIN IF EXISTS (
  SELECT
  FROM pg_catalog.pg_roles
  WHERE rolname = 'ingestor'
) THEN RAISE NOTICE 'Role "ingestor" already exists. Skipping.';
ELSE CREATE ROLE ingestor noinherit nologin;
END IF;
END $do$;

CREATE SCHEMA IF NOT EXISTS tokenomics;
GRANT USAGE, CREATE ON SCHEMA tokenomics TO ingestor;
ALTER USER ingestor SET SEARCH_PATH TO tokenomics;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA tokenomics TO ingestor;

-- migrate:down
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA tokenomics FROM ingestor;
REVOKE USAGE, CREATE ON SCHEMA tokenomics FROM ingestor;
ALTER USER ingestor SET SEARCH_PATH TO "$user", public;
DROP SCHEMA IF EXISTS tokenomics;
DROP ROLE IF EXISTS ingestor;
