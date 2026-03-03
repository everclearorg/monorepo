# Cartographer

The Cartographer is a service that stores intent data to a persistent datastore. The data schema is bespoke for Everclear cross-chain intents and can facilitate use cases such as:

- Querying current state of intents (i.e. to get the status).
- Get intent history for a user.
- Network-wide analytics.

# Architecture

The Cartographer consists of multiple microservices:

- **Handler**: An event-driven Fastify server that receives webhook payloads from Goldsky Mirror pipelines. Each webhook corresponds to an on-chain entity change (e.g. origin intent, hub message, invoice). The handler enriches payloads by querying SubgraphReader for complete entity data (since Mirror payloads omit reference fields) and persists results to the database. Includes a periodic backfill loop for gap recovery.
- **Poller**: A polling-based service that periodically queries subgraphs and stores intent data to the database.
- **Core**: Shared configuration, context types, and operations used by both the handler and the poller.

## Handler endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Health check. Returns `{ status, mode, paused }`. |
| `/pause` | POST | Pause webhook processing. Incoming webhooks return 200 without being processed. Useful during pipeline backfill to skip old events. |
| `/resume` | POST | Resume webhook processing. |
| `/webhooks/:webhookName` | POST | Webhook ingestion endpoint. Accepts `?domain=` query param for spoke-chain webhooks. Requires `Goldsky-Webhook-Secret` header. |

## Supported webhooks

| Webhook name | Entity |
|---|---|
| `origin-intent` | Origin intent (spoke) |
| `destination-intent` | Destination intent (spoke) |
| `hub-intent` | Hub intent |
| `settlement-intent` | Settlement intent (spoke) |
| `order` | Order |
| `hub-invoice` | Hub invoice |
| `hub-deposit-enqueued` | Hub deposit (enqueued) |
| `hub-deposit-processed` | Hub deposit (processed) |
| `hub-message` | Hub settlement message |
| `spoke-message` | Spoke message |
| `settlement-queue` | Settlement queue |
| `deposit-queue` | Deposit queue |
| `spoke-queue` | Spoke queue |
| `hub-meta` | Hub metadata |
| `spoke-meta` | Spoke metadata |
| `settlement-enqueued` | Settlement enqueued event |
| `hub-meta-update` | Protocol update log |
| `hub-token-update` | Hub token update log |
| `hub-asset-update` | Hub asset update log |
| `depositor-event` | Depositor event |
| `hub-token` | Token |

# Local Development

Refer to the individual microservice READMEs for more information.
