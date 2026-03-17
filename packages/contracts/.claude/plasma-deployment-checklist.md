# Plasma Staging Deployment Checklist

## Chain Info

| Field             | Value                                        |
| ----------------- | -------------------------------------------- |
| Chain Name        | Plasma                                       |
| Chain ID          | 9745                                         |
| Domain ID         | 9745                                         |
| RPC URL           | https://rpc.plasma.to                        |
| Explorer          | https://plasmascan.to                        |
| Verifier API      | https://api.etherscan.io/v2/api?chainid=9745 |
| Hyperlane Mailbox | 0x3a464f746D23Ab22155710f44dB16dcA53e0775E   |
| Hub Gas Limit     | 30000000                                     |
| Environment       | Staging                                      |
| Eng Multisig      | 0xBc8988C7a4b77c1d6df7546bd876Ea4D42DF0837   |

## Deployed Addresses

| Contract          | Address                                    |
| ----------------- | ------------------------------------------ |
| Spoke Proxy       | 0xa05A3380889115bf313f1Db9d5f335157Be4D816 |
| Spoke Gateway     | 0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7 |
| Call Executor     | 0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99 |
| XERC20 Module     | 0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4 |
| Spoke Impl (V5)   | 0x255aba6E7f08d40B19872D11313688c2ED65d1C9 |
| Spoke Impl (V6)   | 0xdCA40903E271Cc76AECd62dF8d6c19f3Ac873E64 |
| FeeAdapterV2      | 0x7B435CCF350DBC773e077410e8FEFcd46A1cDfAA |

---

## Pre-Deployment

- [x] Git setup: checkout dev, pull latest, create feature branch
- [x] Add Plasma to `packages/contracts/cli/config/domains.json` with `verifierUrl`
- [x] Add Plasma abstract contract to `packages/contracts/script/MainnetStaging.sol` with placeholder addresses
- [x] Add Plasma to `MainnetStagingDomains` inheritance list
- [x] Add Plasma to `SUPPORTED_DOMAINS` array
- [x] Verify contracts compile

---

## Deployment

### Step 1: Deploy Spoke Contracts

- [x] Spoke contracts deployed
- [x] Record SPOKE_ADDRESS: `0xa05A3380889115bf313f1Db9d5f335157Be4D816`
- [x] Record GATEWAY_ADDRESS: `0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7`
- [x] Record EXECUTOR_ADDRESS: `0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99`

### Step 2: Deploy XERC20 Module

- [x] XERC20 Module deployed
- [x] Record XERC20_MODULE_ADDRESS: `0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4`

### Step 3: Read Spoke Implementation Address

```bash
cast storage 0xa05A3380889115bf313f1Db9d5f335157Be4D816 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url https://rpc.plasma.to
```

- [x] Record SPOKE_IMPL_ADDRESS: `0x255aba6E7f08d40B19872D11313688c2ED65d1C9`

### Step 4: Update MainnetStaging.sol

- [x] Fill in all deployed addresses in the Plasma abstract contract
- [x] Set `PLASMA_ENG_MULTISIG` to `0xBc8988C7a4b77c1d6df7546bd876Ea4D42DF0837`

### Step 5: Add to SpokeUpgradeSwaps.s.sol

- [x] Add `DeploymentParams` entry to `MainnetStaging` setUp()

### Step 6: Execute Spoke Upgrade (V6)

- [x] Spoke upgrade executed
- [x] Record SPOKE_IMPL_V6_ADDRESS: `0xdCA40903E271Cc76AECd62dF8d6c19f3Ac873E64`
- [x] Record FEE_ADAPTER_ADDRESS: `0x7B435CCF350DBC773e077410e8FEFcd46A1cDfAA`

### Step 7: Verify Upgrade

```bash
# Confirmed: implementation slot = 0xdCA40903E271Cc76AECd62dF8d6c19f3Ac873E64
cast storage 0xa05A3380889115bf313f1Db9d5f335157Be4D816 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url https://rpc.plasma.to
```

- [x] Implementation address changed to V6 impl
- [x] Update `PLASMA_SPOKE_IMPL_V6` in MainnetStaging.sol
- [x] Update `PLASMA_FEE_ADAPTER` in MainnetStaging.sol

### Step 8: Verify Contracts on Block Explorer

- [x] EverclearSpoke impl (0x255aba6E7f08d40B19872D11313688c2ED65d1C9) verified
- [x] SpokeGateway impl (0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7) verified
- [x] CallExecutor (0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99) verified
- [x] XERC20Module (0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4) verified
- [x] EverclearSpokeV6 (0xdCA40903E271Cc76AECd62dF8d6c19f3Ac873E64) verified
- [x] FeeAdapterV2 (0x7B435CCF350DBC773e077410e8FEFcd46A1cDfAA) verified

---

## Post-Deployment Config

### Step 9: Update spoke.json

- [x] Add entry to `packages/contracts/cli/config/spoke.json`

### Step 10: Create Deployment Artifacts

- [x] Create directory: `packages/contracts/deployments/staging/9745/`
- [x] Create `EverclearSpoke.json`
- [x] Create `SpokeGateway.json`
- [x] Create `FeeAdapter.json`

### Step 11: Update deployments/index.ts

- [x] Add imports for Plasma staging deployments
- [x] Add to `Deployments.staging` object (key `9745`)

---

## Hub Registration

### Step 12a: Run CLI — `addSupportedDomains` + `updateChainGateway`

The CLI handles these two calls automatically, but `addSupportedDomains` **reverts** if any domain is already registered.

**Already-registered domains on staging hub:** `[10, 42161, 239, 1, 8453, 1399811149, 728126428, 5000]`

**Before running:**
1. In `MainnetStaging.sol`:
   - Comment out all `SUPPORTED_DOMAINS_AND_GATEWAYS.push(...)` entries **except** Plasma
   - Comment out `SUPPORTED_DOMAINS` array and replace with: `uint32[] public SUPPORTED_DOMAINS = [PLASMA];`
2. In `SetupDomainsAndGateways.s.sol`, comment out assertions in `SetupDomainsAndGatewaysMainnetStaging`
3. Run the CLI
4. After success, uncomment all changes back

- [x] Comment out already-registered domains in `SUPPORTED_DOMAINS_AND_GATEWAYS` constructor
- [x] Replace `SUPPORTED_DOMAINS` array with only `[PLASMA]`
- [x] Comment out assertions in `SetupDomainsAndGateways.s.sol` for `MainnetStaging`
- [x] Run CLI
- [x] Uncomment all three changes back

### Step 12b: Manual calls (CLI does NOT handle these)

- [x] Call `updateActiveMailbox` on HubGateway (confirmed: `activeMailbox(9745)` = `0x7f50C5776722630a0024fAE05fDe8b47571D7B39`)
- [x] Call `set` on EVERCLEAR_ISM (confirmed: `module(9745)` = `0x7BD53d94D4F3c5d0300f48Dc467E178eBF044021`)

### // Next Steps

```bash
# === Hub Registration Commands for Plasma (staging) ===

# 1. CLI handles addSupportedDomains + updateChainGateway (step 12a)
#    Remember to comment out existing domains first!
npm run cli
# Select: Setup hub domains and gateways > Mainnet Staging

# 2. Manual: updateActiveMailbox on HubGateway (step 12b)
#    Target: Staging HubGateway (0xe5F2F4afAd6211cfBD6a882D5a6a435530Ee3909)
#    Chain ID: 9745 (Plasma)
#    Everclear Mailbox: 0x7f50C5776722630a0024fAE05fDe8b47571D7B39
cast send 0xe5F2F4afAd6211cfBD6a882D5a6a435530Ee3909 "updateActiveMailbox(uint32,address)" \
  9745 0x7f50C5776722630a0024fAE05fDe8b47571D7B39 \
  --rpc-url https://rpc.everclear.raas.gelato.cloud --private-key $EVERCLEAR_SPOKE_DEPLOYER_KEY

# 3. Manual: set on EVERCLEAR_ISM (step 12b)
#    Target: Staging EVERCLEAR_ISM (0x6B84aCd5cf97833360deFf7D9406d0736c332a9B)
#    Chain ID: 9745 (Plasma)
#    Everclear Mailbox: 0x7f50C5776722630a0024fAE05fDe8b47571D7B39 (default HL mailbox, unless Polymer)
cast send 0x6B84aCd5cf97833360deFf7D9406d0736c332a9B "set(uint32,address)" \
  9745 0x7f50C5776722630a0024fAE05fDe8b47571D7B39 \
  --rpc-url https://rpc.everclear.raas.gelato.cloud --private-key $EVERCLEAR_SPOKE_DEPLOYER_KEY

# === Verification ===
cast call 0x372396818F125b8f3AA5a73e70C30F54c6195331 "supportedDomains()(uint32[])" --rpc-url https://rpc.everclear.raas.gelato.cloud
cast call 0x372396818F125b8f3AA5a73e70C30F54c6195331 "domainGasLimit(uint32)(uint256)" 9745 --rpc-url https://rpc.everclear.raas.gelato.cloud
cast call 0xe5F2F4afAd6211cfBD6a882D5a6a435530Ee3909 "chainGateways(uint32)(bytes32)" 9745 --rpc-url https://rpc.everclear.raas.gelato.cloud
```

**Verification:**
- [x] Domain registered on hub (`domainGasLimit(9745)` = 30000000)
- [x] Domain in supported list: `supportedDomains()` includes 9745
- [x] Gateway set on HubGateway: `chainGateways(9745)` = `0x0000...9ada72ccbafe94248afade6b604d1beaacc899a7`
- [x] Active mailbox set on HubGateway for Plasma (`0x7f50C5776722630a0024fAE05fDe8b47571D7B39`)
- [x] ISM updated for Plasma (`module(9745)` = `0x7BD53d94D4F3c5d0300f48Dc467E178eBF044021`)

---

## Asset Setup

### Step 13: Configure Assets on Hub

- [x] Add `PLASMA_WETH = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB` to `MainnetAssets` in `MainnetStaging.sol`
- [x] Add `PLASMA_USDT = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb` to `MainnetAssets` in `MainnetStaging.sol`
- [x] Update `WETH.s.sol`: bump array to 7, add Plasma entry at index 6
- [x] Update `USDT.s.sol`: bump array to 9, add Plasma entry at index 8
- [x] Update `tokenInfo.json` with Plasma addresses for WETH and USDT
- [x] Run CLI to execute `setTokenConfigs` for WETH on Hub (confirmed: `adoptedForAssets` returns `0x9895...32CB`, approved=true)
- [x] Run CLI to execute `setTokenConfigs` for USDT on Hub (confirmed: `adoptedForAssets` returns `0xB8CE...5ebb`, approved=true)

---

## Subgraph

### Step 14: Add Subgraph Config Entry

- [x] Add entry to `packages/subgraph/config/everclear-spoke-staging.json` (network: `plasma-mainnet`)

### Step 15: Update Network Mapping (CRITICAL)

- [x] Add `plasma-mainnet` → `9745` to `packages/subgraph/src/common/network.ts`

### Step 16: Deploy Subgraph

- [x] Subgraph deployed
- [x] Subgraph indexing confirmed (block 13366927 at time of check)
- [x] Subgraph URL: `https://api.goldsky.com/api/public/project_clssc64y57n5r010yeoly05up/subgraphs/everclear-spoke-plasma/staging-v0.0.2/gn`
- [x] Verified subgraph responds with `_meta` query

---

## External Repos

### Step 17: Update Chaindata

Repository: `connext/chaindata` — file `everclear.mainnet.staging.json`

- [x] Add Plasma chain entry with providers, subgraphUrls, deployments, confirmations, assets
- [ ] PR created and merged

### Step 18: Update API

Repository: `everclear/api`

- [ ] Add chain config to `src/config/config.ts`
- [ ] Update terraform config at `ops/mainnet/staging/backend/config.tf`
- [ ] PR created and merged

---

## Monorepo Terraform

- [x] Update `ops/mainnet/staging/backend/config.tf` with Plasma RPC provider

---

## Monorepo PR

- [ ] Create PR to dev branch with all monorepo changes
- [ ] PR approved and merged

---

## Final Verification

- [x] Contracts verified on block explorer
- [x] Implementation is V6: confirmed `0xdCA40903E271Cc76AECd62dF8d6c19f3Ac873E64`
- [x] FeeAdapterV2 deployed and recorded
- [x] Hub domain registered (gas limit = 30000000)
- [x] Subgraph indexing (v0.0.2, block 13366927)
- [x] Chaindata updated
- [x] Assets configured on Hub (WETH, USDT — both confirmed on-chain)
- [x] Chaindata updated with asset tickers (WETH + USDT with tickerHash, decimals, price)
- [ ] API updated

---

## Remaining Work Summary

| Step | Item | Status |
| ---- | ---- | ------ |
| 17 | Chaindata: add asset tickers for WETH + USDT | DONE |
| 18 | API repo update | NOT DONE |
| — | Chaindata PR | NOT DONE |
| — | Monorepo PR | NOT DONE |
