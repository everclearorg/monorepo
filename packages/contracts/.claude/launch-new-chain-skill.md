---
name: launch-new-chain
description: Automate Everclear chain expansion for staging (auto-execute + PR) or production (Safe transaction files)
version: 3.0.0
---

# Launch New Chain Skill

Automates the Everclear chain expansion process for adding new spoke chains. Supports two modes:
- **Staging**: Execute deployments, update configs, and create PRs automatically
- **Production**: Deploy with deployer key (pre-ownership-transfer), generate Safe TX for hub registration

## Usage

```
/launch-new-chain <environment>
```

**Examples:**
```bash
# Staging deployment (auto-execute + PR)
/launch-new-chain staging

# Production deployment (deploy + Safe files for hub)
/launch-new-chain production
```

## Required Information

The skill will prompt for all of these before starting deployment. All fields are required unless marked with a default.

| # | Parameter | Description | Example |
|---|-----------|-------------|---------|
| 1 | Environment | `staging` or `production` | staging |
| 2 | Chain Name | Human-readable chain name | Plasma, Sonic |
| 3 | Chain ID | EVM chain ID (= domain ID) | 9745, 146 |
| 4 | RPC URL | Public RPC endpoint | https://rpc.plasma.to |
| 5 | Explorer URL | Block explorer URL | https://plasmascan.to |
| 6 | Verifier API URL | Etherscan-compatible API for verification | https://api.etherscan.io/v2/api?chainid=9745 |
| 7 | Hyperlane Mailbox | Mailbox contract on the new chain | 0x3a464f746D23Ab22155710f44dB16dcA53e0775E |
| 8 | Goldsky Network Name | Goldsky identifier for subgraph deployment | plasma-mainnet |
| 9 | Eng Multisig | Engineering multisig on the new chain | 0xBc8988C7a4b77c1d6df7546bd876Ea4D42DF0837 |
| 10 | Hub Gas Limit | Gas limit for hub messages (default: `30000000`) | 30000000 |
| 11 | Assets | Token symbols + their addresses on the new chain | WETH: 0x..., USDT: 0x... |
| 12 | Confirmations | Block confirmations for chaindata (default: `5`) | 5 |

**Asset input format**: For each asset, the user must provide the token symbol and its deployed address on the new chain. Example:
```
WETH: 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB
USDT: 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb
```

**Environment-specific addresses** (Hub, HubGateway, EVERCLEAR_ISM, Everclear HL Mailbox) are looked up from `MainnetStaging.sol` or `MainnetProduction.sol` — do NOT ask the user for these. They are listed in the deployment checklist template's Environment Reference table.

## Workflow

### Staging Mode

0. **Deployment Checklist**: Copy `packages/contracts/.claude/deployment-checklist.template.md` to `.claude/<chain-name>-deployment-checklist.md` in the monorepo. Fill in all known chain-specific values (chain name, chain ID, RPC URL, mailbox address, explorer URL, etc.). Update checklist items (`- [x]`) as each step completes. Record deployed addresses in the checklist as they become available. Once the spoke is deployed and upgraded, populate the `Hub Registration Commands` section with the concrete hub registration commands using the actual deployed addresses (see template for format).
1. **Git Setup**: Checkout dev, pull latest, create feature branch
2. **Update MainnetStaging.sol**: Add chain contract block with placeholder addresses (SPOKE, SPOKE_GATEWAY, EXECUTOR, XERC20_MODULE, SPOKE_IMPL, ENG_MULTISIG, FEE_ADAPTER). Add to MainnetStagingDomains and SUPPORTED_DOMAINS.
3. **Update domains.json**: Add chain entry with `verifierUrl` if available
4. **Update Spoke.s.sol**: Add `_deploymentParams[<CHAIN>]` to `MainnetStaging` setUp() — maps chain ID to mailbox, lighthouse, watchtower, etc. Without this, the deploy script reverts with `WrongChainId()`.
5. **Deploy Spoke Contracts** (via CLI): `npm run cli` > Deploy contracts > Mainnet Staging > spoke
6. **Deploy XERC20 Module** (via CLI): `npm run cli` > Deploy XERC20 module > Mainnet Staging
7. **Read Spoke Impl Address**: `cast storage <SPOKE_PROXY> 0x360894...bbc` — record SPOKE_IMPL
8. **Update MainnetStaging.sol**: Fill in deployed addresses from steps 5-7
9. **Add to SpokeUpgradeSwaps.s.sol**: Add `DeploymentParams` entry to `MainnetStaging` setUp()
10. **Execute Spoke Upgrade** (via CLI): `npm run cli` > Upgrade Spoke to V6 > Mainnet Staging
11. **Verify Upgrade**: Re-read implementation slot, confirm change. Update FEE_ADAPTER in config.
12. **Verify Contracts on Block Explorer**: `source .env && forge verify-contract ...` for all deployed contracts
13. **Hub Registration**: Four operations in two groups — (a) via CLI, then (b) and (c) manually:
    - **(a) CLI — `addSupportedDomains` + `updateChainGateway`**: The script **reverts** if any domain is already registered. Before running: comment out already-registered entries in `SUPPORTED_DOMAINS_AND_GATEWAYS` constructor, replace `SUPPORTED_DOMAINS` with only the new chain, comment out assertions in `SetupDomainsAndGateways.s.sol`. Run `npm run cli` > Setup hub domains and gateways > Mainnet Staging. Uncomment everything back after success.
    - **(b) Manual — `updateActiveMailbox` on HubGateway**: `cast send <HUB_GATEWAY> "updateActiveMailbox(uint32,address)" <CHAIN_ID> <EVERCLEAR_MAILBOX> --rpc-url $EVERCLEAR_RPC --private-key $KEY`. The second parameter is the Everclear chain's Hyperlane mailbox (default HL mailbox, unless Polymer is used). The CLI does NOT handle this.
    - **(c) Manual — `set` on EVERCLEAR_ISM**: `cast send <EVERCLEAR_ISM> "set(uint32,address)" <CHAIN_ID> <EVERCLEAR_MAILBOX> --rpc-url $EVERCLEAR_RPC --private-key $KEY`. Same as (b) — uses the Everclear chain's HL mailbox. The ISM address is in `MainnetStaging.sol` (`EVERCLEAR_ISM`). The CLI does NOT handle this.
14. **Asset Setup**: For each asset the new chain supports:
    - **(a)** Add token address constant to `MainnetAssets` in `MainnetStaging.sol` (e.g., `address public constant MEGAETH_WETH = 0x...;`)
    - **(b)** Update the asset script in `script/assets/mainnetstaging/<SYMBOL>.s.sol`: increment `_assetConfigs` array size by 1, add new `AssetConfig` entry with `adopted: <CHAIN>_<SYMBOL>.toBytes32()`, `domain: <CHAIN>`, `approval: true`, `strategy: IEverclear.Strategy.DEFAULT`
    - **(c)** Update `cli/config/tokenInfo.json`: add `"<CHAIN_ID>": "<TOKEN_ADDRESS>"` to the token's `addresses` object
    - **(d)** Run CLI to execute `setTokenConfigs` on Hub: `npm run cli` > Add asset > Mainnet Staging > select asset. Set `initLastClosedEpochProcessed: false` for tokens after their first init.
15. **Update Subgraph Config**: Add entry to spoke staging config
16. **Deploy Subgraph**: Goldsky deployment
17. **Update Chaindata Repo**: PR with new chain entry. The `assets` object must include each token's `symbol`, `address`, `decimals`, `tickerHash`, `isNative`, and `price` (with `isStable`, `coingeckoId`). Ticker hashes are in CLAUDE.md or computed via `keccak256(symbol)`.
18. **Update API Repo**: PR with new chain support
19. **Create Monorepo PR**: PR to dev branch

### Production Mode

0. **Deployment Checklist**: Copy `packages/contracts/.claude/deployment-checklist.template.md` to `.claude/<chain-name>-deployment-checklist.md` in the monorepo. Fill in all known chain-specific values (chain name, chain ID, RPC URL, mailbox address, explorer URL, etc.). Update checklist items (`- [x]`) as each step completes. Record deployed addresses in the checklist as they become available. Once the spoke is deployed and upgraded, populate the `Hub Registration Commands` section with the concrete hub registration commands using the actual deployed addresses (see template for format).
1. **Deploy Spoke Contracts** (via CLI): `npm run cli` > Deploy contracts > Mainnet Production > spoke
2. **Deploy XERC20 Module** (via CLI): `npm run cli` > Deploy XERC20 module > Mainnet Production
3. **Read Spoke Impl Address**: `cast storage` ERC1967 implementation slot
4. **Update MainnetProduction.sol**: Add chain contract block with all deployed addresses
5. **Add to SpokeUpgradeSwaps.s.sol**: Add `DeploymentParams` entry to `MainnetProduction` setUp()
6. **Execute Spoke Upgrade** (via CLI): `npm run cli` > Upgrade Spoke to V6 > Mainnet Production. Must use spoke owner key.
7. **Verify Upgrade**: Confirm implementation changed, update FEE_ADAPTER
8. **Verify Contracts on Block Explorer**: `source .env && forge verify-contract ...`
9. **Transfer Ownership to Safe**: Must happen AFTER upgrade step
10. **Hub Registration**: The Hub, HubGateway, and ISM are Safe-owned on production. Four transactions via Safe (two targets):
    - **`addSupportedDomains`** on **EverclearHub**: `cast calldata "addSupportedDomains((uint32,uint256)[])" "[(<CHAIN_ID>,<GAS_LIMIT>)]"`. Submit via Safe CLI.
    - **`updateChainGateway`** on **EverclearHub**: `cast calldata "updateChainGateway(uint32,bytes32)" <CHAIN_ID> $(cast to-uint256 <GATEWAY_ADDRESS>)`. Submit via Safe CLI.
    - **`updateActiveMailbox`** on **HubGateway**: `cast calldata "updateActiveMailbox(uint32,address)" <CHAIN_ID> <EVERCLEAR_MAILBOX>`. Second param is Everclear chain's HL mailbox (unless Polymer). Submit via Safe CLI (different target than Hub).
    - **`set`** on **EVERCLEAR_ISM**: `cast calldata "set(uint32,address)" <CHAIN_ID> <EVERCLEAR_MAILBOX>`. Same — Everclear chain's HL mailbox. Submit via Safe CLI. ISM address is in `MainnetProduction.sol` (`EVERCLEAR_ISM`).
11. **Asset Setup**: For each asset the new chain supports:
    - **(a)** Add token address constant to `MainnetAssets` in `MainnetProduction.sol`
    - **(b)** Update asset script in `script/assets/mainnetproduction/<SYMBOL>.s.sol`: increment `_assetConfigs` array size, add new `AssetConfig` entry
    - **(c)** Update `cli/config/tokenInfo.json` with new chain's token addresses
    - **(d)** Run CLI or generate Safe TX for `setTokenConfigs` on Hub. Set `initLastClosedEpochProcessed: false` for tokens after their first init.
12. **Update Subgraph Config + Deploy**: Add config entry, update `network.ts` mapping, deploy via Goldsky
13. **Update Chaindata Repo**: PR with new chain entry (including asset tickers — symbol, address, decimals, tickerHash, isNative, price)
14. **Update API Repo**: PR with new chain support
15. **Create Monorepo PR**: PR to dev branch

**Important**: The upgrade must execute BEFORE ownership transfer to Safe. Once ownership transfers, the deployer can no longer call upgrade functions directly.

## Deployment via Monorepo CLI

Always use `npm run cli` (from `packages/contracts/`) for deployments and upgrades instead of raw `forge script` commands. The CLI:

- **Loads `.env`** from the contracts directory — picks up private keys and API keys
- **Handles account selection** — scans `.env` for valid private keys, presents interactive choice
- **Passes correct flags** — `--private-key $VAR_NAME`, `--chain`, `--rpc-url`, `--verify` etc.
- **Supports dry-run** — simulates first, then asks to broadcast

### Available CLI Actions

| CLI Action | Use Case |
|-----------|----------|
| Deploy contracts | Deploy Spoke/Hub contracts |
| Deploy XERC20 module | Deploy XERC20Module for a spoke |
| Upgrade Spoke to V6 | Execute SpokeUpgradeSwaps.s.sol (deploys V6 impl + FeeAdapterV2) |
| Setup hub domains and gateways | Register domain on Hub chain |
| Add asset | Execute `setTokenConfigs` on Hub for an asset script |

### Why CLI over raw forge commands

The CLI loads private keys from `packages/contracts/.env` via `dotenv`. When running `forge script` directly, Foundry does NOT auto-load `.env` files. The `--account` flag uses Foundry keystores (`~/.foundry/keystores/`), which may hold different keys than `.env`. This mismatch caused upgrade failures in practice — the CLI avoids this by always using `--private-key $VAR_NAME` with shell expansion.

## Contract Verification

After deployment and upgrade, verify all contracts on the block explorer.

### Prerequisites

- `ETHERSCAN_API_KEY` set in `packages/contracts/.env`
- Run `source .env` before verification commands

### Verification Command Pattern

```bash
cd packages/contracts
source .env

# Contracts without constructor args:
forge verify-contract \
  --chain-id <CHAIN_ID> \
  --num-of-optimizations 10000 \
  --watch \
  --compiler-version v0.8.25 \
  --verifier-url "https://api.etherscan.io/v2/api?chainid=<CHAIN_ID>" \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  <CONTRACT_ADDRESS> <SOURCE_PATH>:<CONTRACT_NAME>

# Contracts with constructor args:
forge verify-contract \
  --chain-id <CHAIN_ID> \
  --num-of-optimizations 10000 \
  --watch \
  --compiler-version v0.8.25 \
  --verifier-url "https://api.etherscan.io/v2/api?chainid=<CHAIN_ID>" \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  --constructor-args $(cast abi-encode "constructor(...)" <args>) \
  <CONTRACT_ADDRESS> <SOURCE_PATH>:<CONTRACT_NAME>
```

### Contracts to Verify

| Contract | Source Path | Constructor Args |
|----------|-----------|-----------------|
| EverclearSpoke (impl) | `src/contracts/intent/EverclearSpoke.sol:EverclearSpoke` | none |
| SpokeGateway (impl) | `src/contracts/intent/SpokeGateway.sol:SpokeGateway` | none |
| CallExecutor | `src/contracts/intent/CallExecutor.sol:CallExecutor` | none |
| SpokeMessageReceiver | `src/contracts/intent/modules/SpokeMessageReceiver.sol:SpokeMessageReceiver` | none |
| SpokeMessageReceiverV2 | `src/contracts/intent/modules/SpokeMessageReceiverV2.sol:SpokeMessageReceiverV2` | none |
| EverclearSpokeV6 | `src/contracts/intent/EverclearSpokeV6.sol:EverclearSpokeV6` | none |
| XERC20Module | `src/contracts/intent/modules/XERC20Module.sol:XERC20Module` | `(address spoke)` |
| FeeAdapterV2 | `src/contracts/intent/FeeAdapterV2.sol:FeeAdapterV2` | `(address spoke, address owner, address feeSigner, address xerc20Module, address feeRecipient)` |
| ERC1967Proxy (spoke) | Use absolute path to `node_modules/@openzeppelin/.../ERC1967Proxy.sol` with `--root .` | `(address impl, bytes initData)` — often already verified |
| ERC1967Proxy (gateway) | Same as above | `(address impl, bytes initData)` — often already verified |

### Getting Constructor Args from Broadcast Files

Constructor args can be found in the broadcast JSON files:
```bash
# Spoke deployment
cat broadcast/Spoke.s.sol/<CHAIN_ID>/run-latest.json | jq '.transactions[] | {contractName, contractAddress, arguments}'

# XERC20 deployment
cat broadcast/XERC20.s.sol/<CHAIN_ID>/run-latest.json | jq '.transactions[] | {contractName, contractAddress, arguments}'

# Upgrade deployment
cat broadcast/SpokeUpgradeSwaps.s.sol/<CHAIN_ID>/run-latest.json | jq '.transactions[] | {contractName, contractAddress, arguments}'
```

## Files Modified

### Monorepo
- `packages/contracts/script/MainnetProduction.sol` or `MainnetStaging.sol` (chain contract block + MainnetAssets token addresses)
- `packages/contracts/script/deploy/upgrades/SpokeUpgradeSwaps.s.sol`
- `packages/contracts/script/assets/mainnet<env>/<SYMBOL>.s.sol` (AssetConfig entries for each token)
- `packages/contracts/cli/config/domains.json`
- `packages/contracts/cli/config/spoke.json`
- `packages/contracts/cli/config/tokenInfo.json` (token addresses per chain)
- `packages/contracts/deployments/index.ts`
- `packages/subgraph/config/everclear-spoke-<env>.json`
- `packages/subgraph/src/common/network.ts` (Goldsky network → chain ID mapping)
- `ops/mainnet/<env>/backend/config.tf`

### Chaindata Repo
- `everclear.mainnet.staging.json` (staging) or `everclear.json` (production)

### API Repo
- `src/config/config.ts`
- `ops/mainnet/<env>/backend/config.tf`

## Templates

| Template | Location | Purpose |
|----------|----------|---------|
| `deployment-checklist.template.md` | `packages/contracts/.claude/` (monorepo) | Full deployment checklist with progress tracking |
| `chain-config.template.sol` | `.claude/skills/launch-new-chain/templates/` | Chain contract block for env config |
| `upgrade-params.template.sol` | `.claude/skills/launch-new-chain/templates/` | `DeploymentParams` entry for SpokeUpgradeSwaps.s.sol |
| `domain.template.json` | `.claude/skills/launch-new-chain/templates/` | Domain entry for domains.json |
| `subgraph.template.json` | `.claude/skills/launch-new-chain/templates/` | Subgraph config entry |
| `chaindata.template.json` | `.claude/skills/launch-new-chain/templates/` | Chaindata repo entry |
| `safe-tx.template.json` | `.claude/skills/launch-new-chain/templates/` | Safe Transaction Builder JSON |

## Technical Notes

### ERC1967 Implementation Slot

The spoke proxy stores its implementation address at the standard ERC1967 slot:
```
0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```

Read with: `cast storage <SPOKE_PROXY> <SLOT> --rpc-url <RPC>`

This is used to:
1. Record the initial implementation address (SPOKE_IMPL) after spoke deployment
2. Verify the implementation changed after the upgrade

### FeeAdapterV2

FeeAdapterV2 is deployed as part of the `SpokeUpgradeSwaps.s.sol` upgrade script. There is no separate FeeAdapter deployment step — the upgrade script handles both the spoke upgrade and FeeAdapterV2 deployment.

### Private Key Management

Private keys are stored in `packages/contracts/.env` (gitignored). The CLI loads them via `dotenv` and presents matching env vars (valid hex private keys) for selection. Never use raw `forge script` with `--account` for keystores unless you've verified the keystore holds the correct key — prefer the CLI which uses `.env` private keys consistently.

## Subgraph Deployment (Goldsky)

### Authentication

Goldsky uses `GOLDSKY_API_KEY` env var stored in `packages/subgraph/.env`. The deploy script loads it via `dotenv`. Alternatively, run `goldsky login` for interactive auth.

### Config File

Add an entry to `packages/subgraph/config/everclear-spoke-<env>.json`:
```json
{
  "subgraphName": "everclear-spoke-<network>",
  "domain": "<chain-id>",
  "environment": "staging",
  "network": "<network>",
  "indexers": ["goldsky"]
}
```

The `network` value must be a Goldsky-supported network name. These often differ from the chain's common name — check the full list at https://docs.goldsky.com/chains/supported-networks.

Common Goldsky network name patterns:
- L2s with "mainnet" suffix: `plasma-mainnet`, `mantle-mainnet`
- Standard names: `mainnet`, `base`, `optimism`, `arbitrum-one`, `blast`
- Testnets: `sepolia`, `optimism-sepolia`, `arbitrum-sepolia`

### Update Network Mapping (CRITICAL)

The subgraph's AssemblyScript code at `packages/subgraph/src/common/network.ts` contains a `getChainId()` function that maps Goldsky network names to chain IDs. **Every new chain must be added to this mapping**, otherwise the subgraph will abort at runtime with `No chainName for network <name>`.

Add an entry before the `else` block:
```typescript
} else if (network == '<goldsky-network-name>') {
    chainId = BigInt.fromI32(<chain-id>);
}
```

This mapping must use the same Goldsky network name as the `network` field in the subgraph config above.

### Deployment Artifacts

The deploy script reads contract artifacts from:
```
packages/contracts/deployments/<environment>/<domain>/
```

Required files: `EverclearSpoke.json`, `SpokeGateway.json`, `FeeAdapter.json` — each containing `{ "address": "0x...", "startBlock": N, "abi": [...] }`.

The `FeeAdapter.json` artifact is created after the spoke upgrade (step 9), using the FeeAdapterV2 address from the upgrade output. Copy the ABI from an existing chain's `FeeAdapter.json` and update the address and startBlock.

### Deploy Command

```bash
cd packages/subgraph
yarn deploy everclear-spoke --version staging --networks <goldsky-network-name> --label v0.0.1 --deploy true
```

**Important**: The `--networks` flag must use the Goldsky network name (e.g., `plasma-mainnet`), not the short chain name (e.g., `plasma`). The deploy script matches this against the `network` field in the config JSON.

This generates `subgraph.yaml` from template, runs codegen + build, and deploys via:
```
goldsky subgraph deploy everclear-spoke-<network>/staging-v0.0.1
```

New chains start at label `v0.0.1`. Increment for redeployments.

### Subgraph API URL Format

After deployment, the subgraph is accessible at:
```
https://api.goldsky.com/api/public/project_clssc64y57n5r010yeoly05up/subgraphs/everclear-spoke-<network>/<env>-<version>/gn
```

- **Project ID**: `project_clssc64y57n5r010yeoly05up`
- **Subgraph name**: `everclear-spoke-<network>` (uses the Goldsky network name from the config)
- **Version slug**: `<env>-<version>` (e.g., `staging-v0.0.1`, `production-v0.0.1`)
- **Suffix**: `/gn` (required for GraphQL endpoint)

Example for Plasma on staging:
```
https://api.goldsky.com/api/public/project_clssc64y57n5r010yeoly05up/subgraphs/everclear-spoke-plasma/staging-v0.0.1/gn
```

This URL must be added to the chaindata entry's `subgraphUrls` array (see `chaindata.template.json`).

### Command Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `<name>` (positional) | Subgraph name | `everclear-spoke` |
| `--version` / `-v` | Environment version | `staging`, `production` |
| `--networks` / `-n` | Target networks (must use Goldsky network name, not short name) | `plasma-mainnet`, `all`, `mainnet optimism` |
| `--label` / `-l` | Version label | `v0.0.1` |
| `--deploy` / `-d` | Whether to deploy | `true`, `false` |

## Excluded Steps

The following steps from the Chain Expansion Playbook are NOT automated:
- Deploy sEarched Unwrapper
- Whitelist Spoke on Gelato
- Update Gitbook

## Requirements

- **Foundry**: Required for contract deployment, verification, and `cast storage`
- **Node.js**: Required for `npm run cli`
- **Git & GitHub CLI (gh)**: Required for PR creation
- **jq**: Required for JSON manipulation
- **curl**: Required for RPC verification
- **Goldsky CLI**: Required for subgraph deployment
- **ETHERSCAN_API_KEY**: Required for contract verification (in `.env`)

## Repository Paths

Default paths (adjust to match your local setup):
- **Monorepo**: Current working directory (or `~/Code/Proxima/monorepo`)
- **Chaindata**: `~/Code/Proxima/chaindata`
- **API**: `~/Code/Proxima/api`

## Safe Transaction Builder Format

Production mode generates JSON files compatible with the Safe Transaction Builder app (hub registration only):

```json
{
  "version": "1.0",
  "chainId": "25327",
  "createdAt": "2024-01-15T12:00:00Z",
  "meta": {
    "name": "Everclear Hub - Register ChainName",
    "description": "Add ChainName domain to Hub and set gateway"
  },
  "transactions": [
    {
      "to": "0x...",
      "value": "0",
      "data": "0x...",
      "contractMethod": null,
      "contractInputsValues": null
    }
  ]
}
```

## Post-Deployment Checklist

1. All contracts verified on block explorer
2. Spoke initialized correctly (`cast call` owner, gateway)
3. Implementation slot changed after upgrade (`cast storage`)
4. FeeAdapterV2 deployed and recorded in env config
5. Domain registered on Hub (`domainGasLimit` > 0, `supportedDomains` includes chain)
6. Hub gateway set (`chainGateways` returns spoke gateway)
7. Active mailbox set (`activeMailbox` returns Everclear HL mailbox)
8. ISM updated (`module` returns non-zero)
9. Assets configured (`setTokenConfigs` for each asset)
10. Subgraph indexing
11. Chaindata updated
12. API responding for new chain
