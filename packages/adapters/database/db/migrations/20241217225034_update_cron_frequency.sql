-- migrate:up

UPDATE cron.job
SET schedule = '*/10 * * * *'
WHERE jobid IN (SELECT jobid FROM cron.job WHERE command NOT ILIKE '%daily_metrics_%');


-- migrate:down

UPDATE cron.job
SET schedule = '* * * * *'
WHERE jobid IN (SELECT jobid FROM cron.job WHERE command NOT ILIKE '%daily_metrics_%');
