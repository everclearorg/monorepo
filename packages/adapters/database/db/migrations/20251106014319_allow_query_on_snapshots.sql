-- migrate:up

GRANT SELECT, INSERT, UPDATE, DELETE ON public.swap_inventory_snapshots TO query;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.swap_inventory_snapshots TO api;

-- migrate:down

REVOKE SELECT, INSERT, UPDATE, DELETE ON public.swap_inventory_snapshots FROM query;
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.swap_inventory_snapshots FROM api;
