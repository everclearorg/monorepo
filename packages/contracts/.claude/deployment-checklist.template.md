# {{CHAIN_NAME}} {{ENVIRONMENT}} Deployment Checklist

## Placeholder Convention

- `{{DOUBLE_BRACES}}` — user inputs, filled when the checklist is created
- `<ANGLE_BRACKETS>` — deployment-time values, filled as contracts are deployed
- `$ENV_VAR` — shell environment variables (loaded from `packages/contracts/.env`)

## Required User Inputs

> **Agent instruction**: Collect these from the user before starting. All fields are required unless marked optional.

| # | Input | Value | Notes |
|---|-------|-------|-------|
| 1 | Environment | `{{ENVIRONMENT}}` | `Staging` or `Production` |
| 2 | Chain Name | `{{CHAIN_NAME}}` | Human-readable (e.g., Plasma, Sonic) |
| 3 | Chain ID | `{{CHAIN_ID}}` | EVM chain ID (= domain ID) |
| 4 | RPC URL | `{{RPC_URL}}` | Public RPC endpoint |
| 5 | Explorer URL | `{{EXPLORER_URL}}` | Block explorer (e.g., https://plasmascan.to) |
| 6 | Verifier API URL | `{{VERIFIER_API_URL}}` | Etherscan-compatible API for `forge verify-contract` |
| 7 | Hyperlane Mailbox | `{{MAILBOX_ADDRESS}}` | Mailbox contract on the new chain |
| 8 | Goldsky Network Name | `{{GOLDSKY_NETWORK_NAME}}` | Goldsky network identifier (e.g., `plasma-mainnet`) — check https://docs.goldsky.com/chains/supported-networks |
| 9 | Eng Multisig | `{{ENG_MULTISIG}}` | Engineering multisig on the new chain |
| 10 | Hub Gas Limit | `{{HUB_GAS_LIMIT}}` | Gas limit for hub messages (default: `30000000`) |
| 11 | Assets | See table below | Token symbols + addresses on the new chain |
| 12 | Confirmations | `{{CONFIRMATIONS}}` | Block confirmations for chaindata (default: `5`) |

### Asset Addresses

| Symbol | Address on {{CHAIN_NAME}} | Strategy |
|--------|--------------------------|----------|
| {{ASSET_1_SYMBOL}} | `{{ASSET_1_ADDRESS}}` | DEFAULT |
| {{ASSET_2_SYMBOL}} | `{{ASSET_2_ADDRESS}}` | DEFAULT |
<!-- Add more rows as needed for additional assets -->

---

## Environment Reference

> These are looked up from `Mainnet{{ENVIRONMENT}}.sol` — do NOT ask the user for these.

| Contract | Staging | Production |
|----------|---------|------------|
| Hub | `0x372396818F125b8f3AA5a73e70C30F54c6195331` | `0xa05A3380889115bf313f1Db9d5f335157Be4D816` |
| HubGateway | `0xe5F2F4afAd6211cfBD6a882D5a6a435530Ee3909` | `0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa` |
| EVERCLEAR_ISM | `0x6B84aCd5cf97833360deFf7D9406d0736c332a9B` | `0xcdBE2995Af304e9c14dF5B0c3d7C9CCc63D7b8B3` |
| Everclear HL Mailbox | `0x7f50C5776722630a0024fAE05fDe8b47571D7B39` | `0x7f50C5776722630a0024fAE05fDe8b47571D7B39` |
| Everclear RPC | `https://rpc.everclear.raas.gelato.cloud` | `https://rpc.everclear.raas.gelato.cloud` |

---

## Deployed Addresses

> Fill these in as contracts are deployed.

| Contract | Address |
|----------|---------|
| Spoke Proxy | |
| Spoke Gateway | |
| Call Executor | |
| XERC20 Module | |
| Spoke Impl (V5) | |
| Spoke Impl (V6) | |
| FeeAdapterV2 | |

---

## Pre-Deployment

- [ ] Git setup: checkout dev, pull latest, create feature branch `feat/add-{{CHAIN_NAME_LOWER}}`
- [ ] Add {{CHAIN_NAME}} to `packages/contracts/cli/config/domains.json` with `verifierUrl`
- [ ] Add {{CHAIN_NAME}} abstract contract to `packages/contracts/script/Mainnet{{ENVIRONMENT}}.sol` with placeholder addresses
- [ ] Add {{CHAIN_NAME}} to `Mainnet{{ENVIRONMENT}}Domains` inheritance list
- [ ] Add {{CHAIN_NAME}} to `SUPPORTED_DOMAINS` array
- [ ] Verify contracts compile: `forge build`

---

## Deployment

### Step 1: Deploy Spoke Contracts

```bash
cd packages/contracts
npm run cli
# Select: Deploy contracts > Mainnet {{ENVIRONMENT}} > spoke
```

- [ ] Spoke contracts deployed
- [ ] Record SPOKE_ADDRESS:
- [ ] Record GATEWAY_ADDRESS:
- [ ] Record EXECUTOR_ADDRESS:

### Step 2: Deploy XERC20 Module

```bash
npm run cli
# Select: Deploy XERC20 module > Mainnet {{ENVIRONMENT}}
```

- [ ] XERC20 Module deployed
- [ ] Record XERC20_MODULE_ADDRESS:

### Step 3: Read Spoke Implementation Address

```bash
cast storage <SPOKE_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url {{RPC_URL}}
```

- [ ] Record SPOKE_IMPL_ADDRESS:

### Step 4: Update Mainnet{{ENVIRONMENT}}.sol

- [ ] Fill in all deployed addresses in the {{CHAIN_NAME}} abstract contract
- [ ] Set `{{CHAIN_NAME_UPPER}}_ENG_MULTISIG` to `{{ENG_MULTISIG}}`

### Step 5: Add to SpokeUpgradeSwaps.s.sol

- [ ] Add `DeploymentParams` entry to `Mainnet{{ENVIRONMENT}}` setUp() in `packages/contracts/script/deploy/upgrades/SpokeUpgradeSwaps.s.sol`

### Step 6: Execute Spoke Upgrade (V6)

```bash
npm run cli
# Select: Upgrade Spoke to V6 > Mainnet {{ENVIRONMENT}}
```

- [ ] Spoke upgrade executed
- [ ] Record SPOKE_IMPL_V6_ADDRESS:
- [ ] Record FEE_ADAPTER_ADDRESS:

### Step 7: Verify Upgrade

```bash
# Confirm implementation slot changed
cast storage <SPOKE_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url {{RPC_URL}}
```

- [ ] Implementation address changed to V6 impl
- [ ] Update `{{CHAIN_NAME_UPPER}}_SPOKE_IMPL_V6` in Mainnet{{ENVIRONMENT}}.sol
- [ ] Update `{{CHAIN_NAME_UPPER}}_FEE_ADAPTER` in Mainnet{{ENVIRONMENT}}.sol

### Step 8: Verify Contracts on Block Explorer

```bash
cd packages/contracts
source .env

# EverclearSpoke (impl)
forge verify-contract --chain-id {{CHAIN_ID}} --num-of-optimizations 10000 --watch --compiler-version v0.8.25 --verifier-url "{{VERIFIER_API_URL}}" --etherscan-api-key "$ETHERSCAN_API_KEY" <SPOKE_IMPL_ADDRESS> src/contracts/intent/EverclearSpoke.sol:EverclearSpoke

# SpokeGateway (impl)
forge verify-contract --chain-id {{CHAIN_ID}} --num-of-optimizations 10000 --watch --compiler-version v0.8.25 --verifier-url "{{VERIFIER_API_URL}}" --etherscan-api-key "$ETHERSCAN_API_KEY" <GATEWAY_ADDRESS> src/contracts/intent/SpokeGateway.sol:SpokeGateway

# CallExecutor
forge verify-contract --chain-id {{CHAIN_ID}} --num-of-optimizations 10000 --watch --compiler-version v0.8.25 --verifier-url "{{VERIFIER_API_URL}}" --etherscan-api-key "$ETHERSCAN_API_KEY" <EXECUTOR_ADDRESS> src/contracts/intent/CallExecutor.sol:CallExecutor

# XERC20Module (has constructor args)
forge verify-contract --chain-id {{CHAIN_ID}} --num-of-optimizations 10000 --watch --compiler-version v0.8.25 --verifier-url "{{VERIFIER_API_URL}}" --etherscan-api-key "$ETHERSCAN_API_KEY" --constructor-args $(cast abi-encode "constructor(address)" <SPOKE_ADDRESS>) <XERC20_MODULE_ADDRESS> src/contracts/intent/modules/XERC20Module.sol:XERC20Module

# EverclearSpokeV6
forge verify-contract --chain-id {{CHAIN_ID}} --num-of-optimizations 10000 --watch --compiler-version v0.8.25 --verifier-url "{{VERIFIER_API_URL}}" --etherscan-api-key "$ETHERSCAN_API_KEY" <SPOKE_IMPL_V6_ADDRESS> src/contracts/intent/EverclearSpokeV6.sol:EverclearSpokeV6

# FeeAdapterV2 (has constructor args — get from broadcast file)
forge verify-contract --chain-id {{CHAIN_ID}} --num-of-optimizations 10000 --watch --compiler-version v0.8.25 --verifier-url "{{VERIFIER_API_URL}}" --etherscan-api-key "$ETHERSCAN_API_KEY" --constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" <SPOKE_ADDRESS> <ENG_MULTISIG> <FEE_SIGNER> <XERC20_MODULE_ADDRESS> <FEE_RECIPIENT>) <FEE_ADAPTER_ADDRESS> src/contracts/intent/FeeAdapterV2.sol:FeeAdapterV2
```

- [ ] EverclearSpoke impl verified
- [ ] SpokeGateway impl verified
- [ ] CallExecutor verified
- [ ] XERC20Module verified
- [ ] EverclearSpokeV6 verified
- [ ] FeeAdapterV2 verified

---

## Post-Deployment Config

### Step 9: Update spoke.json

- [ ] Add entry to `packages/contracts/cli/config/spoke.json`:
```json
{
  "address": "<SPOKE_ADDRESS>",
  "feeAdapterAddress": "<FEE_ADAPTER_ADDRESS>",
  "domainName": "{{CHAIN_NAME}}",
  "domainId": {{CHAIN_ID}},
  "environment": "Mainnet{{ENVIRONMENT}}"
}
```

### Step 10: Create Deployment Artifacts

- [ ] Create directory: `packages/contracts/deployments/{{ENVIRONMENT_LOWER}}/{{CHAIN_ID}}/`
- [ ] Create `EverclearSpoke.json` with address, startBlock, and ABI
- [ ] Create `SpokeGateway.json` with address, startBlock, and ABI
- [ ] Create `FeeAdapter.json` with FeeAdapterV2 address, startBlock, and ABI

### Step 11: Update deployments/index.ts

- [ ] Add imports for {{CHAIN_NAME}} {{ENVIRONMENT_LOWER}} deployments
- [ ] Add to `Deployments.{{ENVIRONMENT_LOWER}}` object (key `{{CHAIN_ID}}`)

---

## Hub Registration

### Step 12a: Run CLI — `addSupportedDomains` + `updateChainGateway`

The CLI runs `SetupDomainsAndGateways.s.sol` which handles these two calls automatically. However, `addSupportedDomains` **reverts** if any domain is already registered.

**Before running:**
1. Check which domains are already registered:
```bash
cast call <HUB_ADDRESS> "supportedDomains()(uint32[])" --rpc-url https://rpc.everclear.raas.gelato.cloud
```
2. In `Mainnet{{ENVIRONMENT}}.sol`:
   - Comment out every `SUPPORTED_DOMAINS_AND_GATEWAYS.push(...)` entry whose domain is already registered — leave only {{CHAIN_NAME}}
   - Comment out the full `SUPPORTED_DOMAINS` array and replace with: `uint32[] public SUPPORTED_DOMAINS = [{{CHAIN_NAME_UPPER}}];`
3. In `SetupDomainsAndGateways.s.sol`, comment out the assertions section in the `Mainnet{{ENVIRONMENT}}` contract — it indexes `_supportedDomains[_i]` assuming array order matches, which fails when only registering new domains
4. Run the CLI
5. **After success**, uncomment everything back before committing

```bash
npm run cli
# Select: Setup hub domains and gateways > Mainnet {{ENVIRONMENT}}
```

- [ ] Comment out already-registered domains in `SUPPORTED_DOMAINS_AND_GATEWAYS` constructor
- [ ] Replace `SUPPORTED_DOMAINS` array with only `[{{CHAIN_NAME_UPPER}}]`
- [ ] Comment out assertions in `SetupDomainsAndGateways.s.sol` for `Mainnet{{ENVIRONMENT}}`
- [ ] Run CLI
- [ ] Uncomment all three changes back

### Step 12b: Manual calls (CLI does NOT handle these)

> **These must be done manually after step 12a.**

1. **`updateActiveMailbox`** on **HubGateway** — set the Everclear chain's Hyperlane mailbox for the new domain
2. **`set`** on **EVERCLEAR_ISM** — register the new domain on the ISM

Both calls use the **Everclear chain's HL mailbox** as the address parameter (not the new chain's mailbox). The ISM address is in `Mainnet{{ENVIRONMENT}}.sol` (`EVERCLEAR_ISM`).

- [ ] `updateActiveMailbox` called on HubGateway
- [ ] `set` called on EVERCLEAR_ISM

### Hub Registration Commands

> **Agent instruction**: Once the spoke is deployed and upgraded, populate this section with concrete commands using actual deployed addresses. Replace `<SPOKE_ADDRESS>`, `<GATEWAY_ADDRESS>`, etc. with real values from the Deployed Addresses table above. Look up hub addresses from the Environment Reference table.

```bash
# === Hub Registration Commands for {{CHAIN_NAME}} ({{ENVIRONMENT_LOWER}}) ===

# 1. CLI handles addSupportedDomains + updateChainGateway (step 12a)
#    Remember to comment out existing domains first!
npm run cli
# Select: Setup hub domains and gateways > Mainnet {{ENVIRONMENT}}

# 2. Manual: updateActiveMailbox on HubGateway (step 12b)
#    Target: HubGateway (see Environment Reference table)
#    Inputs: chain ID + Everclear chain's HL mailbox (see Environment Reference table)
cast send <HUB_GATEWAY> "updateActiveMailbox(uint32,address)" \
  {{CHAIN_ID}} <EVERCLEAR_HL_MAILBOX> \
  --rpc-url https://rpc.everclear.raas.gelato.cloud --private-key $EVERCLEAR_SPOKE_DEPLOYER_KEY

# 3. Manual: set on EVERCLEAR_ISM (step 12b)
#    Target: EVERCLEAR_ISM (see Environment Reference table)
#    Inputs: chain ID + Everclear chain's HL mailbox (default HL mailbox, unless Polymer)
cast send <EVERCLEAR_ISM> "set(uint32,address)" \
  {{CHAIN_ID}} <EVERCLEAR_HL_MAILBOX> \
  --rpc-url https://rpc.everclear.raas.gelato.cloud --private-key $EVERCLEAR_SPOKE_DEPLOYER_KEY

# === Verification ===
# Domain registered?
cast call <HUB_ADDRESS> "supportedDomains()(uint32[])" --rpc-url https://rpc.everclear.raas.gelato.cloud
cast call <HUB_ADDRESS> "domainGasLimit(uint32)(uint256)" {{CHAIN_ID}} --rpc-url https://rpc.everclear.raas.gelato.cloud

# Gateway set?
cast call <HUB_GATEWAY> "chainGateways(uint32)(bytes32)" {{CHAIN_ID}} --rpc-url https://rpc.everclear.raas.gelato.cloud

# Active mailbox set?
cast call <HUB_GATEWAY> "activeMailbox(uint32)(address)" {{CHAIN_ID}} --rpc-url https://rpc.everclear.raas.gelato.cloud

# ISM updated?
cast call <EVERCLEAR_ISM> "module(uint32)(address)" {{CHAIN_ID}} --rpc-url https://rpc.everclear.raas.gelato.cloud
```

For **production** (Safe-owned), generate calldata and submit via Safe Transaction Builder:
```bash
# addSupportedDomains → EverclearHub
cast calldata "addSupportedDomains((uint32,uint256)[])" "[({{CHAIN_ID}},{{HUB_GAS_LIMIT}})]"

# updateChainGateway → EverclearHub
cast calldata "updateChainGateway(uint32,bytes32)" {{CHAIN_ID}} $(cast to-uint256 <GATEWAY_ADDRESS>)

# updateActiveMailbox → HubGateway (different target!)
cast calldata "updateActiveMailbox(uint32,address)" {{CHAIN_ID}} <EVERCLEAR_HL_MAILBOX>

# set → EVERCLEAR_ISM (different target!)
cast calldata "set(uint32,address)" {{CHAIN_ID}} <EVERCLEAR_HL_MAILBOX>
```

**Verification:**
- [ ] Domain registered on hub (`domainGasLimit({{CHAIN_ID}})` returns > 0)
- [ ] Domain in supported list: `supportedDomains()` includes {{CHAIN_ID}}
- [ ] Gateway set on HubGateway: `chainGateways({{CHAIN_ID}})` returns spoke gateway
- [ ] Active mailbox set: `activeMailbox({{CHAIN_ID}})` returns Everclear HL mailbox
- [ ] ISM updated: `module({{CHAIN_ID}})` returns non-zero

---

## Asset Setup

### Step 13: Configure Assets on Hub

For each asset the new chain supports:

- [ ] Add token address constants to `MainnetAssets` in `Mainnet{{ENVIRONMENT}}.sol`:
```solidity
address public constant {{CHAIN_NAME_UPPER}}_{{ASSET_1_SYMBOL}} = {{ASSET_1_ADDRESS}};
address public constant {{CHAIN_NAME_UPPER}}_{{ASSET_2_SYMBOL}} = {{ASSET_2_ADDRESS}};
```

- [ ] Update asset scripts in `script/assets/mainnet{{ENVIRONMENT_LOWER}}/`:
  - For each `<SYMBOL>.s.sol`: increment `_assetConfigs` array size by 1, add:
```solidity
_assetConfigs[N] = IHubStorage.AssetConfig({
  tickerHash: _tickerHash,
  adopted: {{CHAIN_NAME_UPPER}}_<SYMBOL>.toBytes32(),
  domain: {{CHAIN_NAME_UPPER}},
  approval: true,
  strategy: IEverclear.Strategy.DEFAULT
});
```

- [ ] Update `cli/config/tokenInfo.json` — add `"{{CHAIN_ID}}": "<TOKEN_ADDRESS>"` to each token's `addresses`

- [ ] Run CLI to execute `setTokenConfigs`: `npm run cli` > Add asset > Mainnet {{ENVIRONMENT}} > select each asset
  - Set `initLastClosedEpochProcessed: false` for tokens after their first init

### Asset Verification

Verify each asset was registered on the Hub. Use the two-step approach: `assetHash` then `adoptedForAssets`.

```bash
# Common ticker hashes:
# WETH: 0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8
# USDC: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa
# USDT: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0
# CLEAR: 0x06ac253a00ee13562eecafc06057c6db73566a05bdce988194aad3616e28e87c

# Step 1: Compute asset hash
cast call <HUB_ADDRESS> "assetHash(bytes32,uint32)(bytes32)" <TICKER_HASH> {{CHAIN_ID}} --rpc-url https://rpc.everclear.raas.gelato.cloud

# Step 2: Read adopted config (use hash from step 1)
cast call <HUB_ADDRESS> "adoptedForAssets(bytes32)((bytes32,bytes32,uint32,bool,uint8))" <ASSET_HASH> --rpc-url https://rpc.everclear.raas.gelato.cloud
# Expected: (tickerHash, adopted address as bytes32, domain, approved=true, strategy)
```

- [ ] All assets verified on-chain (adopted address matches, approved = true)

---

## Subgraph

### Step 14: Add Subgraph Config Entry

- [ ] Add entry to `packages/subgraph/config/everclear-spoke-{{ENVIRONMENT_LOWER}}.json`:
```json
{
  "subgraphName": "everclear-spoke-{{GOLDSKY_NETWORK_NAME}}",
  "domain": "{{CHAIN_ID}}",
  "environment": "{{ENVIRONMENT_LOWER}}",
  "network": "{{GOLDSKY_NETWORK_NAME}}",
  "indexers": ["goldsky"]
}
```

### Step 15: Update Network Mapping (CRITICAL)

- [ ] Add chain to `packages/subgraph/src/common/network.ts` `getChainId()`:
```typescript
} else if (network == '{{GOLDSKY_NETWORK_NAME}}') {
    chainId = BigInt.fromI32({{CHAIN_ID}});
}
```

> **WARNING**: Skipping this step will cause the subgraph to abort at runtime with `No chainName for network <name>`.

### Step 16: Deploy Subgraph

```bash
cd packages/subgraph
yarn deploy everclear-spoke --version {{ENVIRONMENT_LOWER}} --networks {{GOLDSKY_NETWORK_NAME}} --label v0.0.1 --deploy true
```

- [ ] Subgraph deployed
- [ ] Subgraph indexing confirmed: `goldsky subgraph status everclear-spoke-{{GOLDSKY_NETWORK_NAME}}`
- [ ] Subgraph URL (record actual version — label increments on redeployment, e.g. v0.0.2): `https://api.goldsky.com/api/public/project_clssc64y57n5r010yeoly05up/subgraphs/everclear-spoke-{{GOLDSKY_NETWORK_NAME}}/{{ENVIRONMENT_LOWER}}-<VERSION>/gn`
- [ ] Verify subgraph responds:
```bash
curl -s "<SUBGRAPH_URL>" -H 'Content-Type: application/json' -d '{"query":"{_meta{block{number}}}"}' | jq .
```

---

## Step 17: Monorepo Terraform

- [ ] Update `ops/mainnet/{{ENVIRONMENT_LOWER}}/backend/config.tf` with {{CHAIN_NAME}} RPC provider

---

## External Repos

### Step 18: Update Chaindata

Repository: `connext/chaindata` — file `everclear.mainnet.{{ENVIRONMENT_LOWER}}.json`

- [ ] Add {{CHAIN_NAME}} chain entry with:
  - `providers` (RPC URL)
  - `subgraphUrls` (Goldsky URL from step 16)
  - `deployments` (spoke, gateway, XERC20Module, feeAdapter)
  - `confirmations` ({{CONFIRMATIONS}})
  - `assets` — for each asset, include:
    - `symbol`, `address` (on the new chain), `decimals`
    - `tickerHash` (from CLAUDE.md common ticker hashes or `keccak256(symbol)`)
    - `isNative` (false for wrapped tokens)
    - `price`: `isStable` (true for stablecoins), `coingeckoId`, optional `priceFeed`
- [ ] PR created and merged

### Step 19: Update API

Repository: `everclear/api`

- [ ] Add chain config to `src/config/config.ts`
- [ ] Update terraform config at `ops/mainnet/{{ENVIRONMENT_LOWER}}/backend/config.tf`
- [ ] PR created and merged

---

## Production-Only Steps

### Transfer Ownership to Safe (after upgrade)

> **IMPORTANT**: Must happen AFTER the spoke upgrade (step 6). Once ownership transfers, the deployer can no longer call upgrade functions.

- [ ] Transfer spoke ownership to Safe multisig
- [ ] Verify new owner: `cast call <SPOKE_ADDRESS> "owner()(address)" --rpc-url {{RPC_URL}}`

---

## Monorepo PR

- [ ] Create PR to dev branch with all monorepo changes
- [ ] PR approved and merged

---

## Final Verification

- [ ] Contracts verified on block explorer
- [ ] Implementation is V6: `cast storage <SPOKE_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url {{RPC_URL}}`
- [ ] FeeAdapterV2 deployed and recorded
- [ ] Hub domain registered (`domainGasLimit({{CHAIN_ID}})` > 0)
- [ ] Hub gateway set (`chainGateways({{CHAIN_ID}})`)
- [ ] Active mailbox set (`activeMailbox({{CHAIN_ID}})`)
- [ ] ISM updated (`module({{CHAIN_ID}})`)
- [ ] Assets configured on Hub (setTokenConfigs for each asset)
- [ ] Subgraph indexing (verify via curl)
- [ ] Chaindata updated
- [ ] API updated

---

## Environment Variables

> These must be set in `packages/contracts/.env` before deployment and verification.

| Variable | Used For |
|----------|----------|
| `EVERCLEAR_SPOKE_DEPLOYER_KEY` | Hub registration manual calls (steps 12b) |
| `ETHERSCAN_API_KEY` | Contract verification (step 8) |

---

## Remaining Work Summary

| Step | Item | Status |
|------|------|--------|
| | | |
