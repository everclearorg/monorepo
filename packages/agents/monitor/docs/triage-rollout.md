# Monitor Event Producer Rollout

This runbook replaces monorepo triage rollout guidance. The monitor is now the
sensor plane and emits signed `MonitorEventV1` payloads to everclear-agents.

## Required Configuration

Set pipeline mode and webhook settings:

```bash
ALERT_PIPELINE_MODE=legacy|dual|events_only
ALERT_EVENT_WEBHOOK_URL=https://<everclear-agents-host>:3100/events
ALERT_EVENT_WEBHOOK_SECRET=<shared-secret>
ALERT_EVENT_ENVIRONMENT=prod
ALERT_EVENT_RETRIES=3
ALERT_EVENT_RETRY_BASE_MS=1000
ALERT_EVENT_TIMEOUT_MS=10000
```

Equivalent structured config may be provided under `eventPipeline` in monitor
config, with env vars used as runtime overrides.

## Rollout Plan

1. **legacy**: baseline behavior (Discord/Telegram/BetterUptime + legacy triage).
2. **dual**: emit signed events and keep legacy fanout for safe comparison.
3. **events_only**: monitor emits events only; human/action handling comes from everclear-agents.

## Acceptance Gates

Before moving from `dual` to `events_only`, verify:

1. Missed event rate from sensor to ingest is < 0.1%.
2. Duplicate human notifications are reduced by >= 60% in trial channels.
3. Event ingest auth is enabled (`MONITOR_WEBHOOK_SECRET` configured on consumer).
4. Dedup and ingest metrics are stable for at least 7 days.

## Kill Switch

- Set `ALERT_PIPELINE_MODE=legacy`.
- This bypasses event-only routing and restores legacy fanout immediately.

## Rollback Checklist

1. Flip to `legacy`.
2. Confirm legacy channel alerts resume.
3. Confirm no ingestion errors are blocking critical monitoring.
4. Keep `dual` available for replay comparison until incident closes.
