# Launch New Chain Skill

Deploy a new spoke chain to the Everclear staging environment.

## Usage

```
/launch-new-chain <chain-name> <chain-id>
```

Example: `/launch-new-chain Mantle 5000`

---

## Complete Staging Deployment Workflow

### Phase 1: Pre-Deployment Config Updates (Monorepo)

| Step | File | Action |
|------|------|--------|
| 1 | `packages/contracts/script/MainnetStaging.sol` | Add chain abstract contract |
| 2 | `packages/contracts/cli/config/domains.json` | Add domain entry |

### Phase 2: Contract Deployment (CLI)

| Step | Command | Description |
|------|---------|-------------|
| 3 | `forge script deploy/Spoke.s.sol` | Deploy Spoke, SpokeGateway, FeeAdapter |
| 4 | `cast send` (initialize) | Initialize Spoke, set message gas limit |
| 5 | `cast send` (hub registration) | Register domain on Hub (setDomain, setGateway) |
| 6 | `cast send` (assets) | Add assets to Spoke |

### Phase 3: Post-Deployment Config Updates

| Step | File | Action |
|------|------|--------|
| 7 | `packages/contracts/cli/config/spoke.json` | Add spoke entry |
| 8 | `packages/contracts/deployments/staging/{chainId}/` | Create EverclearSpoke.json, SpokeGateway.json |
| 9 | `packages/contracts/deployments/index.ts` | Add imports + exports |
| 10 | `packages/subgraph/config/everclear-spoke-staging.json` | Add subgraph entry |
| 11 | `ops/mainnet/staging/backend/config.tf` | Add terraform config |

### Phase 4: External Repo Updates

| Step | Repo | File | Action |
|------|------|------|--------|
| 12 | chaindata | `everclear.mainnet.staging.json` | Add chain entry |
| 13 | api | `src/config/config.ts` | Add chain config |

### Phase 5: Deployment & PRs

| Step | Command | Description |
|------|---------|-------------|
| 14 | `goldsky deploy` | Deploy subgraph |
| 15 | `gh pr create` | Create PRs for monorepo, chaindata, api |

---

## Config File Patterns

### 1. MainnetStaging.sol - Abstract Contract

Location: `packages/contracts/script/MainnetStaging.sol`

```solidity
abstract contract {{ChainName}} {
  uint32 public constant {{CHAIN_NAME}} = {{chainId}};
  IMailbox public {{CHAIN_NAME}}_MAILBOX = IMailbox({{mailboxAddress}});

  IEverclearSpoke public {{CHAIN_NAME}}_SPOKE = IEverclearSpoke({{spokeAddress}});
  ISpokeGateway public {{CHAIN_NAME}}_SPOKE_GATEWAY = ISpokeGateway({{gatewayAddress}});
  ICallExecutor public {{CHAIN_NAME}}_EXECUTOR = ICallExecutor({{executorAddress}});
  address public constant {{CHAIN_NAME}}_FEE_ADAPTER = {{feeAdapterAddress}};
}
```

Also update:
- `MainnetStagingDomains` - add to inheritance list
- `MainnetStagingSupportedDomainsAndGateways` constructor - add domain entry
- `MainnetStagingEnvironment.SUPPORTED_DOMAINS` array

### 2. domains.json - Domain Entry

Location: `packages/contracts/cli/config/domains.json`

```json
{
  "name": "{{ChainName}}",
  "id": {{chainId}},
  "rpc": "{{rpcUrl}}",
  "verifierUrl": "{{explorerApiUrl}}",
  "environments": ["MainnetStaging"],
  "realm": "spoke"
}
```

### 3. spoke.json - Spoke Entry

Location: `packages/contracts/cli/config/spoke.json`

```json
{
  "address": "{{spokeAddress}}",
  "feeAdapterAddress": "{{feeAdapterAddress}}",
  "domainName": "{{ChainName}}",
  "domainId": {{chainId}},
  "environment": "MainnetStaging"
}
```

### 4. Deployment JSON Files

Location: `packages/contracts/deployments/staging/{{chainId}}/`

Create `EverclearSpoke.json`:
```json
{
  "address": "{{spokeAddress}}",
  "abi": [...],
  "transactionHash": "{{deployTxHash}}",
  "receipt": {...},
  "args": [...]
}
```

Create `SpokeGateway.json`:
```json
{
  "address": "{{gatewayAddress}}",
  "abi": [...],
  "transactionHash": "{{deployTxHash}}",
  "receipt": {...},
  "args": [...]
}
```

### 5. deployments/index.ts - Imports and Exports

Location: `packages/contracts/deployments/index.ts`

Add imports in "Mainnet Staging Deployments" section:
```typescript
import StagingEverclearSpoke{{ChainName}} from './staging/{{chainId}}/EverclearSpoke.json';
import StagingSpokeGateway{{ChainName}} from './staging/{{chainId}}/SpokeGateway.json';
```

Add to `Deployments.staging` object:
```typescript
{{chainId}}: {
  everclear: StagingEverclearSpoke{{ChainName}},
  gateway: StagingSpokeGateway{{ChainName}},
},
```

### 6. Subgraph Config Entry

Location: `packages/subgraph/config/everclear-spoke-staging.json`

```json
{
  "subgraphName": "everclear-spoke-{{chain-name}}",
  "domain": "{{chainId}}",
  "environment": "staging",
  "network": "{{goldsky-network-name}}",
  "indexers": ["goldsky"]
}
```

### 7. Terraform Config

Location: `ops/mainnet/staging/backend/config.tf`

Add to `local_cartographer_config.chains`:
```hcl
"{{chainId}}" = {
  providers = [
    "{{rpcUrlWithApiKey}}"
  ]
}
```

### 8. Chaindata Entry

Repo: `connext/chaindata`
File: `everclear.mainnet.staging.json`

Add under `chains`:
```json
"{{chainId}}": {
  "network": "evm",
  "providers": ["{{rpcUrl}}"],
  "subgraphUrls": ["https://api.goldsky.com/api/public/project_clssc64y57n5r010yeoly05up/subgraphs/everclear-spoke-{{chain-name}}/latest/gn"],
  "deployments": {
    "everclear": "{{spokeAddress}}",
    "gateway": "{{gatewayAddress}}",
    "feeAdapter": "{{feeAdapterAddress}}"
  },
  "confirmations": {{confirmations}},
  "messageGasLimit": { "base": 0, "extraIntent": 0 },
  "assets": {}
}
```

### 9. API Config

Repo: `everclear/api`
File: `src/config/config.ts`

Add chain configuration following existing patterns.

---

## Confirmation Thresholds Reference

| Chain Type | Confirmations | Examples |
|------------|---------------|----------|
| Ethereum Mainnet | 15 | Ethereum |
| OP Stack L2s | 5-10 | Optimism, Base, Blast |
| Arbitrum | 5 | Arbitrum One |
| Fast Finality | 3 | BNB, Polygon, Avalanche |
| zkEVM | 5-17 | Linea, Scroll |

---

## Verification Checklist

After deployment, verify:

- [ ] Contracts verified on block explorer
- [ ] `cast call spoke owner()` returns expected owner
- [ ] `cast call spoke gateway()` returns gateway address
- [ ] `cast call hub domains(chainId)` shows domain registered
- [ ] Subgraph indexing (`goldsky subgraph status everclear-spoke-{{chain-name}}`)
- [ ] Chaindata has new chain entry
- [ ] API returns chain in supported chains list

---

## Required Information

When launching a new chain, gather:

1. **Chain Info**
   - Chain name (PascalCase for contracts, lowercase for subgraph)
   - Chain ID
   - RPC URL
   - Block explorer API URL

2. **Hyperlane Info**
   - Mailbox address (from Hyperlane registry)

3. **Deploy Addresses** (from deployment)
   - Spoke address
   - SpokeGateway address
   - FeeAdapter address
   - CallExecutor address

4. **Config Values**
   - Confirmation threshold
   - Message gas limits

---

## Example: Adding Mantle to Staging

```bash
# Chain info
CHAIN_NAME="Mantle"
CHAIN_ID=5000
RPC_URL="https://rpc.mantle.xyz"
EXPLORER_API="https://api.mantlescan.xyz/api"
MAILBOX="0x..." # from Hyperlane registry

# After deployment
SPOKE_ADDRESS="0x..."
GATEWAY_ADDRESS="0x..."
FEE_ADAPTER_ADDRESS="0x..."
```

Files to update:
1. `packages/contracts/script/MainnetStaging.sol`
2. `packages/contracts/cli/config/domains.json`
3. `packages/contracts/cli/config/spoke.json`
4. `packages/contracts/deployments/staging/5000/EverclearSpoke.json`
5. `packages/contracts/deployments/staging/5000/SpokeGateway.json`
6. `packages/contracts/deployments/index.ts`
7. `packages/subgraph/config/everclear-spoke-staging.json`
8. `ops/mainnet/staging/backend/config.tf`
9. `chaindata/everclear.mainnet.staging.json` (external)
10. `api/src/config/config.ts` (external)
