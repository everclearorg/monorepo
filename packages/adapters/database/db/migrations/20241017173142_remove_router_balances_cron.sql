-- migrate:up
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE command = 'REFRESH MATERIALIZED VIEW router_balances;';

-- migrate:down
