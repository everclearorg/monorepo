# Everclear Subgraph Package

Subgraph and webhook pipeline deployment tooling for Everclear.

## Deploy Commands

### Subgraph + Webhook Pipeline (combined)

Deploy a subgraph and its corresponding webhook pipeline in one step:

```bash
# Deploy spoke subgraph + webhook for a specific network (auto-detects next label)
yarn deploy:spoke:mainnet:staging:mainnet

# Deploy with an explicit label
yarn deploy everclear-spoke --version staging --networks mainnet --label v0.0.15 --with-webhooks

# Deploy without webhooks
yarn deploy everclear-spoke --version staging --networks mainnet --label v0.0.15
```

When `--label` is omitted, the script queries Goldsky for the latest deployed version and increments the patch number automatically (e.g. `v0.0.12` -> `v0.0.13`).

### Webhook Pipeline Only

Redeploy a webhook pipeline without redeploying the subgraph:

```bash
# Auto-detects the current latest subgraph label
yarn deploy:webhooks:spoke:staging:mainnet

# With explicit label
yarn deploy:webhooks everclear-spoke-webhooks --version staging --networks mainnet --subgraph-label v0.0.12
```

When `--subgraph-label` is omitted, the script auto-detects the current latest label (without incrementing).

### Dry Run

Preview the generated pipeline YAML without deploying:

```bash
yarn deploy:webhooks everclear-spoke-webhooks --version staging --networks mainnet --dry-run
```

## CLI Options

### `yarn deploy` (subgraph)

| Option | Description |
|--------|-------------|
| `-v, --version <value>` | Config version: `staging` or `production` |
| `-n, --networks <value...>` | Network names, or `all` |
| `-l, --label <value>` | Subgraph version label (auto-detected if omitted) |
| `-d, --deploy <value>` | Deploy to network (`true`/`false`) |
| `-i, --indexers <value...>` | Indexers: `all`, `studio`, `goldsky`, etc. |
| `-w, --with-webhooks` | Also deploy webhook pipelines after subgraph deploy |

### `yarn deploy:webhooks` (webhook pipeline)

| Option | Description |
|--------|-------------|
| `-v, --version <value>` | Config version: `staging` or `production` |
| `-n, --networks <value...>` | Network names to filter (spoke only) |
| `-s, --subgraph-label <value>` | Subgraph label (auto-detected if omitted) |
| `-d, --dry-run` | Preview YAML without deploying |

## Config Files

- `config/everclear-spoke-staging.json` - Spoke subgraph network configs (staging)
- `config/everclear-spoke-webhooks-staging.json` - Spoke webhook pipeline configs (staging)
- `config/everclear-hub-staging.json` - Hub subgraph config (staging)
- `config/everclear-hub-webhooks-staging.json` - Hub webhook pipeline config (staging)
- Same pattern for `production` variants
