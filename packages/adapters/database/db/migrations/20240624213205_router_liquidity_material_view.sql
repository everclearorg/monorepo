-- migrate:up

CREATE MATERIALIZED VIEW router_balances AS
SELECT
    r.*,
    b.*
FROM
    routers r
JOIN
    balances b ON r.address = b.account;

REFRESH MATERIALIZED VIEW router_balances;
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('* * * * *', $$REFRESH MATERIALIZED VIEW router_balances;$$);

-- Grant read permissions to the `query` role
GRANT SELECT ON router_balances TO query;

-- migrate:down

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE command = 'REFRESH MATERIALIZED VIEW router_balances;';

-- Revoke read permissions from the `query` role, to clean up on migration down
REVOKE SELECT ON router_balances FROM query;

DROP MATERIALIZED VIEW IF EXISTS router_balances;