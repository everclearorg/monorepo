-- migrate:up
GRANT SELECT ON public.epoch_results TO reader;
GRANT SELECT ON public.epoch_results TO query;
GRANT SELECT ON public.rewards TO reader;
GRANT SELECT ON public.rewards TO query;
GRANT SELECT ON public.merkle_trees TO reader;
GRANT SELECT ON public.merkle_trees TO query;

-- migrate:down
REVOKE SELECT ON public.epoch_results FROM reader;
REVOKE SELECT ON public.epoch_results FROM query;
REVOKE SELECT ON public.rewards FROM reader;
REVOKE SELECT ON public.rewards FROM query;
REVOKE SELECT ON public.merkle_trees FROM reader;
REVOKE SELECT ON public.merkle_trees FROM query;
