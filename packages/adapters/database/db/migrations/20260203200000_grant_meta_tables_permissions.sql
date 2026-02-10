-- migrate:up

GRANT SELECT ON public.protocol_update_logs TO reader;
GRANT SELECT ON public.protocol_update_logs TO query;

GRANT SELECT ON public.hub_meta TO reader;
GRANT SELECT ON public.hub_meta TO query;

GRANT SELECT ON public.spoke_meta TO reader;
GRANT SELECT ON public.spoke_meta TO query;

-- migrate:down

REVOKE SELECT ON public.protocol_update_logs FROM reader;
REVOKE SELECT ON public.protocol_update_logs FROM query;

REVOKE SELECT ON public.hub_meta FROM reader;
REVOKE SELECT ON public.hub_meta FROM query;

REVOKE SELECT ON public.spoke_meta FROM reader;
REVOKE SELECT ON public.spoke_meta FROM query;
