-- migrate:up
DO $do$ BEGIN IF EXISTS (
  SELECT
  FROM pg_catalog.pg_roles
  WHERE rolname = 'api'
) THEN RAISE NOTICE 'Role "api" already exists. Skipping.';
ELSE CREATE ROLE api noinherit nologin;
END IF;
END $do$;

GRANT INSERT, UPDATE ON solana_lookup_tables TO api;
GRANT INSERT, UPDATE ON otc_sale_table TO api;

-- migrate:down
REVOKE INSERT, UPDATE ON solana_lookup_tables FROM api;
REVOKE INSERT, UPDATE ON otc_sale_table FROM api;
DROP ROLE IF EXISTS api;
