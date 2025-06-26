-- migrate:up
GRANT SELECT, DELETE ON public.solana_lookup_tables TO api;
GRANT SELECT, DELETE ON public.otc_sale_table TO api;

-- migrate:down
REVOKE SELECT, DELETE ON public.solana_lookup_tables TO api;
REVOKE SELECT, DELETE ON public.otc_sale_table TO api;
