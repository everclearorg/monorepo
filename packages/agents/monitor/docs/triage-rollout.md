# Agent-In-The-Loop Triage Rollout

## Required Configuration

Add `triage` under monitor config:

```json
{
  "triage": {
    "mode": "dry-run",
    "timeoutMs": 15000,
    "lookbackHours": 6,
    "retentionHours": 24,
    "timeBucketMinutes": 30,
    "providers": {
      "openai": { "apiKey": "${OPENAI_API_KEY}", "model": "gpt-4o-mini" },
      "anthropic": { "apiKey": "${ANTHROPIC_API_KEY}", "model": "claude-sonnet-4-20250514" }
    },
    "autoResolve": {
      "minConfidence": 0.85,
      "allowedTypes": ["BadRpcDetected"],
      "cooldownMinutes": 30
    }
  }
}
```

## Rollout Plan

1. **Phase 0 (dry-run)**: triage computes analysis but does not modify alert body and never auto-resolves.
2. **Phase 1 (shadow)**: alert body includes `Agent Analysis`; auto-resolve remains disabled.
3. **Phase 2 (enabled canary)**: enable auto-resolve for a single type (`BadRpcDetected`) in staging.
4. **Phase 3 (prod)**: promote to production and gradually expand `allowedTypes`.

## Canary Readiness Gates

Before moving to the next phase, verify all gates below:

1. At least one LLM provider API key is configured in `triage.providers`.
2. `triage.mode=enabled` only when BetterUptime credentials are configured.
3. `triage.timeoutMs` is between `1000` and `30000`.
4. Auto-resolve is restricted to explicitly whitelisted alert types.
5. Monitor logs contain triage metadata (`provider`, `model`, `fingerprint`, `mode`, `reasonCode`).
6. `alert_triage_log` contains rows with both reservation and finalized analysis fields.
7. Rollback rehearsal executed once in staging (toggle `triage.mode` to `disabled` and verify alert flow).

## Kill Switch

- Set `triage.mode` to `disabled`.
- Wait for config refresh (`polling.config`) or redeploy.
- Confirm outbound alerts no longer include `Agent Analysis`.

## Rollback Checklist

1. Set `triage.mode=disabled`.
2. Redeploy monitor if immediate effect is required.
3. Verify alerts are still delivered to Better Stack/Discord/Telegram.
4. Verify no new rows are inserted into `alert_triage_log`.
5. Keep historical rows; they expire using `expires_at`.
