-- migrate:up
DO $do$ BEGIN IF EXISTS (
  SELECT
  FROM pg_catalog.pg_roles
  WHERE rolname = 'shadower'
) THEN RAISE NOTICE 'Role "shadower" already exists. Skipping.';
ELSE CREATE ROLE shadower noinherit nologin;
END IF;
END $do$;

CREATE SCHEMA IF NOT EXISTS shadow;
GRANT USAGE, CREATE ON SCHEMA shadow TO shadower;
ALTER USER shadower SET SEARCH_PATH TO shadow;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA shadow TO shadower;

-- migrate:down
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA shadow FROM shadower;
REVOKE USAGE, CREATE ON SCHEMA shadow FROM shadower;
ALTER USER shadower SET SEARCH_PATH TO "$user", public;
DROP SCHEMA IF EXISTS shadow;
DROP ROLE IF EXISTS shadower;
