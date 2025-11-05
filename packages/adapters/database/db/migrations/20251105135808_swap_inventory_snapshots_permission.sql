-- migrate:up

GRANT SELECT ON public.swap_inventory_snapshots TO reader;
GRANT SELECT ON public.swap_inventory_snapshots TO query;


-- migrate:down

REVOKE SELECT ON public.swap_inventory_snapshots FROM reader;
REVOKE SELECT ON public.swap_inventory_snapshots FROM query;
