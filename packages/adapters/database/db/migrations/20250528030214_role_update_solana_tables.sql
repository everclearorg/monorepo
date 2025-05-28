-- migrate:up
GRANT INSERT, UPDATE ON solana_lookup_tables TO query;
GRANT INSERT, UPDATE ON otc_sale_table TO query;

-- migrate:down
REVOKE INSERT, UPDATE ON solana_lookup_tables FROM query;
REVOKE INSERT, UPDATE ON otc_sale_table FROM query;

