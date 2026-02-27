# AI-Powered Alert Triage & Auto-Resolution — Feature Spec

> **Branch:** `feat/auto_resolve`
> **Changeset:** 38 files changed, ~1,800 insertions
> **Generated:** 2025-02-11

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Module Inventory](#module-inventory)
- [Triage Pipeline Flow](#triage-pipeline-flow)
- [Rollout Modes](#rollout-modes)
- [Auto-Resolve Policy](#auto-resolve-policy)
- [Database Schema](#database-schema)
- [Configuration](#configuration)
- [Completeness Assessment](#completeness-assessment)
- [Correctness Assessment](#correctness-assessment)
- [Test Coverage](#test-coverage)
- [Issues to Fix Before Merge](#issues-to-fix-before-merge)
- [Summary Verdict](#summary-verdict)

---

## Overview

This changeset introduces an **LLM-based alert triage system** into the Everclear monitor agent. When an alert fires, instead of immediately dispatching it to all channels (Telegram, Discord, BetterUptime), it is first intercepted and analyzed by an AI model (Anthropic Claude or OpenAI GPT).

The model produces:

- A **root-cause analysis** (RCA)
- A **confidence score** (0–1)
- A **verdict** and recommended **remediation steps**
- An **auto-resolve recommendation** (boolean)

If the recommendation passes a strict policy gate, the system resolves the BetterUptime incident automatically — reducing alert fatigue for operators.

### Key Capabilities

| Capability | Description |
|---|---|
| Fingerprint-based dedup | Prevents the same alert pattern from being triaged twice within a time window |
| LLM-powered RCA | Sends redacted alert context + recent incident history to Claude or GPT |
| Auto-resolution | Optionally resolves BetterUptime incidents for low-risk, high-confidence verdicts |
| Circuit breaker + retry | Protects against cascading LLM provider failures (2 retries, 300ms delay) |
| Graduated rollout | `disabled` → `dry-run` → `shadow` → `enabled`, with a kill switch |
| Full audit trail | Every triage decision logged to Postgres `alert_triage_log` table |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                          sendAlerts()                                │
│  packages/utils/src/helpers/alerts.ts                                │
└──────────┬───────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      triageInterceptor()                             │
│  packages/utils/src/triage/interceptor.ts                            │
│                                                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐               │
│  │ readiness.ts │─▶│fingerprint.ts│─▶│   dedup.ts    │               │
│  │  validate    │  │  SHA-256 key │  │ reserve/check │               │
│  └─────────────┘  └──────────────┘  └───────┬───────┘               │
│                                              │                       │
│       ┌──────────────────────────────────────┘                       │
│       ▼                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐               │
│  │  router.ts  │─▶│  redact.ts   │─▶│   prompt.ts   │               │
│  │select model │  │ strip secrets│  │ build context  │               │
│  └─────────────┘  └──────────────┘  └───────┬───────┘               │
│                                              │                       │
│       ┌──────────────────────────────────────┘                       │
│       ▼                                                              │
│  ┌──────────────────────────────────────────────────┐                │
│  │              providers/                           │                │
│  │  ┌─────────────┐  ┌────────────┐  ┌───────────┐  │                │
│  │  │ anthropic.ts │  │ openai.ts  │  │  base.ts  │  │                │
│  │  │ Claude       │  │ GPT-4o-    │  │ circuit   │  │                │
│  │  │ Sonnet 4     │  │ mini       │  │ breaker   │  │                │
│  │  └─────────────┘  └────────────┘  └───────────┘  │                │
│  └──────────────────────────────────────────────────┘                │
│       │                                                              │
│       ▼                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │auto-resolve  │─▶│  metrics.ts  │─▶│  history.ts  │               │
│  │   policy     │  │  counters    │  │ BetterUptime  │               │
│  └──────────────┘  └──────────────┘  │ incident fetch│               │
│                                      └──────────────┘                │
└──────────┬───────────────────────────────────────────────────────────┘
           │
           ▼  Returns { report, shouldAutoResolve, triageMeta }
┌──────────────────────────────────────────────────────────────────────┐
│  sendAlerts() continues                                              │
│  ├── Fan-out: Telegram · Discord · BetterUptime · PagerDuty         │
│  └── If shouldAutoResolve → resolveAlertViaBetterUptime()           │
│       └── Track outcome via setAutoResolveOutcome()                  │
└──────────┬───────────────────────────────────────────────────────────┘
           │
           ▼  Persistence
┌──────────────────────────────────────────────────────────────────────┐
│  alert_triage_log  (Postgres)                                        │
│  fingerprint(PK) │ report_type │ severity │ env │ triage_result     │
│  provider │ model │ latency_ms │ auto_resolve_* │ created/expires_at│
└──────────────────────────────────────────────────────────────────────┘
```

---

## Module Inventory

### Source — `packages/utils/src/triage/`

| File | Lines | Responsibility |
|---|---|---|
| `types.ts` | 154 | TypeBox schemas, config defaults, core interfaces (`TriageResult`, `TriageConfig`, etc.) |
| `interceptor.ts` | 211 | **Orchestrator** — glues the entire pipeline together |
| `fingerprint.ts` | 37 | SHA-256 fingerprint from `env\|network\|type\|severity\|ids\|reason\|timeBucket` |
| `dedup.ts` | 72 | In-memory persistence store (swappable to DB) for fingerprint reservation |
| `router.ts` | 36 | Selects provider/model by severity, blast radius, and routing rule overrides |
| `redact.ts` | 52 | Recursive scrubbing of API keys, tokens, passwords, URLs before LLM call |
| `prompt.ts` | 44 | Structured LLM prompt builder + JSON response parser with safe defaults |
| `history.ts` | 126 | Paginated BetterUptime incident fetch + clustering by key |
| `auto-resolve.ts` | 27 | Policy gate: blocks critical, requires confidence ≥ 0.85, type whitelist |
| `readiness.ts` | 43 | Pre-flight validation of credentials and config sanity |
| `metrics.ts` | 43 | In-memory counters (intercepted, triaged, deduped, timeouts, fallbacks) |
| `providers/base.ts` | 44 | `CircuitBreaker` class + `withRetry` utility |
| `providers/anthropic.ts` | 45 | Anthropic Claude adapter with `Promise.race` timeout |
| `providers/openai.ts` | 47 | OpenAI GPT adapter with `Promise.race` timeout |
| `providers/index.ts` | 62 | Factory wrapping providers with shared circuit breaker + retry |
| `index.ts` | 12 | Barrel re-exports |

### Integration points (modified files)

| File | What changed |
|---|---|
| `utils/src/helpers/alerts.ts` | Calls `triageInterceptor()`, handles auto-resolve + outcome tracking |
| `utils/src/helpers/config.ts` | Added `triage: Type.Optional(TTriageConfigSchema)` to alert config |
| `monitor/src/monitor.ts` | Wires DB-backed `TriagePersistenceStore` in `makeMonitor()` |
| `monitor/src/config.ts` | Parses `TRIAGE_CONFIG` env var, merges into monitor config |
| `monitor/src/types/config.ts` | Added optional `triage` field to `TMonitorConfigSchema` |
| `database/src/client.ts` | 5 new functions: reserve, finalize, check, setOutcome, prune |
| `database/src/index.ts` | Exports `TriageFingerprintLog` type + triage DB methods |
| `database/db/migrations/...` | `alert_triage_log` table DDL |

---

## Triage Pipeline Flow

```
1. sendAlerts() called with a Report
       │
2. ─── triageInterceptor(report, config) ────────────────────────
       │
       ├─ Mode == 'disabled'?  → return original report immediately
       │
       ├─ validateTriageReadiness()  → errors? log + return original
       │
       ├─ pruneExpiredFingerprints()  (best-effort, warn on failure)
       │
       ├─ computeFingerprint(report)  → SHA-256 hash
       │
       ├─ tryReserveFingerprint(hash)
       │    └─ Already processed?  → return original (deduped)
       │
       ├─ selectTriageRoute(report, config)
       │    └─ Returns { provider: 'anthropic'|'openai', model: '...' }
       │
       ├─ fetchRecentIncidents(lookbackHours)
       │    └─ Paginated BetterUptime API → clusterIncidents()
       │
       ├─ redactSensitiveData(config)
       │
       ├─ buildTriagePrompt(report, redactedConfig, history)
       │
       ├─ provider.analyze(prompt)       ← with timeout + retry + breaker
       │    └─ parseTriageResult(response)  → TriageResult
       │
       ├─ shouldAutoResolve(result, config)
       │    └─ Policy: !critical, confidence ≥ 0.85, type in allowedTypes
       │
       ├─ finalizeFingerprint(hash, record)
       │
       └─ Mode != 'dry-run'?
            ├─ Yes → enrich report.reason with "[Agent Analysis] ..."
            └─ No  → keep original
       │
3. ─── Return { report, shouldAutoResolve, triageMeta } ────────
       │
4. sendAlerts() fans out to channels
       │
5. If shouldAutoResolve → resolveAlertViaBetterUptime()
       └─ Track outcome via setAutoResolveOutcome()
```

---

## Rollout Modes

| Mode | Alert Modified? | Auto-Resolve? | Audit Logged? | Use Case |
|---|---|---|---|---|
| `disabled` | No | No | No | Kill switch / default state |
| `dry-run` | No | No | Yes | Validate LLM output quality offline |
| `shadow` | Yes (appends Agent Analysis) | No | Yes | Show RCA to operators, build trust |
| `enabled` | Yes | Yes (if policy passes) | Yes | Full production auto-resolve |

See [`triage-rollout.md`](./triage-rollout.md) for the phased rollout plan.

---

## Auto-Resolve Policy

An alert is auto-resolved **only if all** of these conditions are true:

1. **Severity is not `critical`**
2. **The LLM recommends auto-resolve** (`autoResolveRecommendation: true`)
3. **Confidence ≥ `minConfidence`** (default: `0.85`)
4. **Alert type is in `allowedTypes`** (default: `['BadRpcDetected']`)

If any condition fails, the alert flows through the normal channel fan-out unchanged.

---

## Database Schema

```sql
CREATE TABLE IF NOT EXISTS alert_triage_log (
    fingerprint             character(64)   PRIMARY KEY,
    report_type             text            NOT NULL,
    severity                text            NOT NULL,
    env                     text            NOT NULL,
    network                 text,
    ids                     text[],
    reason                  text,
    triage_mode             text            NOT NULL,
    triage_result           jsonb,
    provider_used           text,
    model_used              text,
    triage_latency_ms       integer,
    auto_resolve_attempted  boolean         DEFAULT false,
    auto_resolve_succeeded  boolean,
    auto_resolve_reason_code text,
    created_at              timestamptz     DEFAULT now(),
    expires_at              timestamptz     NOT NULL
);
-- Indexes on created_at, (report_type, env), expires_at
```

---

## Configuration

Triage config can be provided via:

1. **`TRIAGE_CONFIG` env var** (JSON string — highest priority)
2. **`MONITOR_CONFIG` JSON** (nested under `.triage`)
3. **Config file** (nested under `.triage`)

### Example

```json
{
  "triage": {
    "mode": "dry-run",
    "timeoutMs": 15000,
    "lookbackHours": 6,
    "retentionHours": 24,
    "timeBucketMinutes": 30,
    "providers": {
      "anthropic": { "apiKey": "sk-ant-..." },
      "openai": { "apiKey": "sk-..." }
    },
    "autoResolve": {
      "minConfidence": 0.85,
      "allowedTypes": ["BadRpcDetected"]
    },
    "circuitBreaker": {
      "threshold": 5,
      "windowMs": 60000
    }
  }
}
```

---

## Completeness Assessment

### Done ✅

| Area | Notes |
|---|---|
| Core interceptor pipeline | Full happy-path: fingerprint → dedup → route → LLM → auto-resolve |
| Type system & config schema | TypeBox schemas, defaults, config merging from env/SSM/file |
| Fingerprint + dedup | SHA-256 with time bucketing, in-memory store with DB-backed swap |
| LLM providers (Anthropic + OpenAI) | Timeout races, circuit breaker, retry (2×, 300ms) |
| Prompt engineering + parsing | Structured prompt with alert data, history, response schema; JSON parse with defaults |
| Redaction layer | Recursive scrubbing of sensitive keys + URL-aware redaction |
| Auto-resolve policy | Gates on severity, confidence threshold, allowed types whitelist |
| BetterUptime history fetch | Paginated fetch, lookback window, incident clustering |
| Database persistence | Migration, 5 CRUD functions, persistence store wiring in monitor |
| Monitor integration | Persistence store setup in `makeMonitor()`, config loading |
| `sendAlerts()` integration | Interceptor call, conditional auto-resolve, outcome tracking |
| In-memory metrics | Counters for intercepted, triaged, deduped, timeouts, fallbacks |
| Rollout documentation | 4-phase plan with kill switch and rollback checklist |

### Weak or Missing ⚠️

| Area | Concern |
|---|---|
| **Test depth** | Only 20 test cases across 10 files. Most are thin happy-path smoke tests. |
| **Interceptor error-path tests** | No tests for: provider timeout, provider error + fallback, circuit breaker open, fingerprint collision, history fetch failure |
| **Auto-resolve integration test** | No test verifies the full path from `shouldAutoResolve=true` through to `resolveAlertViaBetterUptime()` being called |
| **Provider fallback** | If the routed provider fails, there is no fallback to the other provider. Circuit breaker protects but doesn't redirect. |
| **Prompt response validation** | `parseTriageResult` uses defaults for missing fields but doesn't validate value ranges (e.g. confidence > 1.0) |
| **Config parsing edge case** | `config.ts:235` — `triageConfigJson.mode ? triageConfigJson : triageConfigJson.triage` is ambiguous if both keys exist |
| **Metrics export** | In-memory only. No Prometheus/CloudWatch exporter — only useful in tests today. |
| **Rate limiting** | No rate limiter on LLM calls. Burst of unique fingerprints = burst of API requests. |
| **DB error handling** | Triage DB functions use raw SQL without explicit connection error handling or transaction wrapping |

---

## Correctness Assessment

| Aspect | Verdict | Detail |
|---|---|---|
| Graceful degradation | ✅ Correct | Every error path catches, logs, records metric, returns original report. Alert pipeline never breaks. |
| Dedup atomicity | ✅ Correct | DB uses `INSERT ... ON CONFLICT DO NOTHING` with `RETURNING`. In-memory fallback is synchronous (single-threaded JS). Concurrent test verifies only 1-of-10 wins. |
| Secret redaction | ✅ Correct | Recursive traversal, case-insensitive key matching, URL-aware redaction. Covers API keys, tokens, passwords, secrets. |
| Timeout safety | ✅ Correct | `Promise.race` against delay in both providers. Interceptor wraps entire flow in its own timeout. |
| Mode gating | ✅ Correct | `disabled` → return immediately; `dry-run` → skip mutation; `shadow` → enrich only; `enabled` → enrich + auto-resolve. |
| Auto-resolve safety | ✅ Correct | Critical unconditionally blocked. Confidence ≥ 0.85 required. Only whitelisted types allowed. |
| Fingerprint stability | ✅ Correct | Normalizes hex, timestamps, numbers before hashing. Time-bucketed. Determinism verified by test. |
| Circular dependencies | ✅ Low risk | `triage/` is a leaf module in `utils/`. No circular imports. |

---

## Test Coverage

**20 test cases** across **10 spec files** (~390 lines):

| Spec File | Cases | What's Covered |
|---|---|---|
| `interceptor.spec.ts` | 4 | Disabled mode, successful triage, dry-run, readiness failure |
| `dedup.spec.ts` | 1 | Reserve → finalize → check lifecycle |
| `dedup-concurrent.spec.ts` | 1 | Only 1-of-10 concurrent reserves wins |
| `fingerprint.spec.ts` | 3 | Reason normalization, determinism, time bucketing |
| `auto-resolve.spec.ts` | 2 | Critical blocked, whitelisted type allowed |
| `history.spec.ts` | 2 | Paginated fetch, incident clustering |
| `redact.spec.ts` | 2 | Key redaction, URL redaction |
| `router.spec.ts` | 2 | Default routing, override routing |
| `regression.spec.ts` | 1 | Fan-out preserved when triage disabled |
| `alerts.spec.ts` | 2 | Basic send, resolve matching |

### Coverage Gaps

- **No error-path tests** for provider timeout, circuit breaker trip, history fetch failure
- **No integration test** for the full auto-resolve → BetterUptime resolve → outcome tracking path
- **No edge-case tests** for confidence boundary (exactly 0.85), time bucket boundaries, empty incident lists
- **No config validation tests** for malformed or partial triage configs

---

## Issues to Fix Before Merge

1. **`readiness.ts` is untracked** — shows as `??` in git status. Needs `git add`.
2. **Config parsing ambiguity** — `config.ts:235` should explicitly handle the case where `triageConfigJson` has both `.mode` and `.triage` keys.
3. **Confidence bound validation** — `parseTriageResult` should clamp confidence to `[0, 1]`.
4. **Provider fallback** — Consider routing to secondary provider when primary fails (not just circuit-breaking).
5. **Test coverage** — Add error-path and integration tests before promoting beyond `dry-run`.

---

## Summary Verdict

**The design is solid and the execution is substantially complete for a v1 ship.** The architecture follows clean separation of concerns — each module has a single responsibility, the interceptor orchestrates clearly, and the fail-safe semantics are correct (triage failure never blocks alert delivery). The 4-mode rollout strategy is well thought out.

**Primary gap: test coverage.** At 20 test cases covering ~1,100 lines of source, the tests are largely happy-path smoke tests. The most critical missing tests are around provider failure/timeout paths in the interceptor, the full auto-resolve integration path, and circuit breaker behavior. These should be addressed before promoting beyond `dry-run`.

The feature is **safe to merge into `dry-run` mode** as-is — the disabled-by-default posture and graceful degradation mean zero production risk. Hardening tests should be added before advancing to `shadow` or `enabled`.
