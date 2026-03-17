# Register Hub Domain

Register a new spoke chain domain on the Everclear Hub (production).

## Usage

```
/register-hub-domain <chain-name> <chain-id> <gateway-address> <block-gas-limit>
```

Example: `/register-hub-domain Plasma 9745 0xE4197BC6b18E2BE0BAF09c13DA8239B40005D541 30000000`

---

## Overview

After deploying spoke contracts on a new chain, you must register the domain on the Hub (Everclear chain 25327). This involves:

1. Temporarily modifying `MainnetProduction.sol` to isolate the new domain
2. Temporarily modifying `SetupDomainsAndGateways.s.sol` to skip assertions
3. Running the CLI or generating calldata for Safe submission
4. Reverting the temporary changes
5. Updating the Polymer router on Hub (if applicable)

## Key Addresses (Production)

| Contract | Address | Chain |
|----------|---------|-------|
| EverclearHub | `0xa05A3380889115bf313f1Db9d5f335157Be4D816` | Everclear (25327) |
| HubGateway | `0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa` | Everclear (25327) |
| Everclear RPC | `https://rpc.everclear.raas.gelato.cloud` | |

## Required Roles

| Function | Role | Address |
|----------|------|---------|
| `addSupportedDomains` | ADMIN (or OWNER) | Owner Safe: `0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8` |
| `updateChainGateway` | OWNER | Owner Safe: `0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8` |

Note: The `hasRole(ADMIN)` modifier also allows the `owner` to call, so both functions can be submitted from the Owner Safe.

On mainnet production, the owner of Hub is a Gnosis Safe (`0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8`). Transactions must be submitted via Safe CLI.

---

## Step-by-Step Procedure

### Step 1: Temporarily modify MainnetProduction.sol

File: `packages/contracts/script/MainnetProduction.sol`

**1a. Isolate new domain in `SUPPORTED_DOMAINS_AND_GATEWAYS` constructor**

Comment out ALL existing entries and leave only the new chain:

```solidity
constructor() {
    // Comment out all existing entries...
    // SUPPORTED_DOMAINS_AND_GATEWAYS.push(
    //   DomainAndGateway({chainId: ETHEREUM, blockGasLimit: 30_000_000, gateway: address(ETHEREUM_SPOKE_GATEWAY).toBytes32()})
    // );
    // ... all others commented out ...

    // Only the new chain remains active:
    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: {{CHAIN_NAME}},
        blockGasLimit: {{blockGasLimit}},
        gateway: address({{CHAIN_NAME}}_SPOKE_GATEWAY).toBytes32()
      })
    );
}
```

**1b. Isolate new domain in `SUPPORTED_DOMAINS` array**

```solidity
// Comment out original:
// uint32[] public SUPPORTED_DOMAINS = [ETHEREUM, ARBITRUM_ONE, OPTIMISM, ...];

// Replace with only the new chain:
uint32[] public SUPPORTED_DOMAINS = [{{CHAIN_NAME}}];
```

### Step 2: Temporarily modify SetupDomainsAndGateways.s.sol

File: `packages/contracts/script/hub/SetupDomainsAndGateways.s.sol`

Comment out the assertions block in `SetupDomainsAndGatewaysMainnetProduction`:

```solidity
    // assertions
    // for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
    //   uint32 _domainId = _supportedDomains[_i];
    //   uint256 _gasLimit = IEverclearHub(_hub).domainGasLimit(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
    //   bytes32 _gateway = _hubGateway.chainGateways(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
    //   assert(_domainId == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
    //   assert(_gasLimit == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].blockGasLimit);
    //   assert(_gateway == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].gateway);
    //
    //   console.log('==================== Added Supported Domain ====================');
    //   console.log('domain:', _domainId);
    //   console.log('block gas limit:', _gasLimit);
    //   console.log('gateway:');
    //   console.logBytes32(_gateway);
    //   console.log('================================================================================');
    // }
```

### Step 3: Generate calldata and submit via Safe

Since mainnet production Hub is owned by a Gnosis Safe, generate calldata and submit via Safe CLI.

**3a. Generate calldata for `addSupportedDomains`**

```bash
cast calldata "addSupportedDomains((uint32,uint256)[])" "[({{chainId}},{{blockGasLimit}})]"
```

Submit this calldata to EverclearHub (`0xa05A3380889115bf313f1Db9d5f335157Be4D816`) via Safe CLI using the Owner Safe (`0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8`).

**3b. Generate calldata for `updateChainGateway`**

```bash
# Get the 0-padded 32byte gateway address
cast to-uint256 {{gatewayAddress}}

# Generate calldata
cast calldata "updateChainGateway(uint32,bytes32)" {{chainId}} $(cast --to-bytes32 {{gatewayAddress}})
```

Submit this calldata to EverclearHub (`0xa05A3380889115bf313f1Db9d5f335157Be4D816`) via Safe CLI using the Owner Safe (`0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8`).

### Step 4: Verify registration

```bash
# Check domain is registered and gas limit is set
cast call 0xa05A3380889115bf313f1Db9d5f335157Be4D816 \
  "domainGasLimit(uint32)(uint256)" {{chainId}} \
  --rpc-url https://rpc.everclear.raas.gelato.cloud

# Check gateway is set on HubGateway
cast call 0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa \
  "chainGateways(uint32)(bytes32)" {{chainId}} \
  --rpc-url https://rpc.everclear.raas.gelato.cloud

# Check domain appears in supported domains list
cast call 0xa05A3380889115bf313f1Db9d5f335157Be4D816 \
  "supportedDomains()(uint32[])" \
  --rpc-url https://rpc.everclear.raas.gelato.cloud
```

### Step 5: Revert temporary changes

**IMPORTANT**: Revert all temporary modifications made in Steps 1 and 2:

- In `MainnetProduction.sol`:
  - Uncomment all `SUPPORTED_DOMAINS_AND_GATEWAYS` entries
  - Restore the full `SUPPORTED_DOMAINS` array (including the new chain)
- In `SetupDomainsAndGateways.s.sol`:
  - Uncomment the assertions block

### Step 6: Update Polymer Router on Hub (if applicable)

If the chain uses Hyperlane messaging, update the active mailbox and ISM on the Hub.

**6a. Update active mailbox on HubGateway**

```bash
cast send 0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa \
  "updateActiveMailbox(uint32,address)" \
  {{chainId}} {{hyperlaneMailboxOnEverclear}} \
  --rpc-url https://rpc.everclear.raas.gelato.cloud \
  --private-key $DEPLOYER_KEY
```

**6b. Set ISM for the domain**

Query the HubGateway to get the ISM address, then set the routing:

```bash
cast send <ISM_ADDRESS> \
  "set(uint32,address)" \
  {{chainId}} {{polymerISMOrMailboxAddress}} \
  --rpc-url https://rpc.everclear.raas.gelato.cloud \
  --private-key $DEPLOYER_KEY
```

---

## Gas Limit Reference

| Chain Type | Block Gas Limit | Examples |
|------------|----------------|----------|
| Standard EVM | 30,000,000 | Ethereum, Optimism, Base, Arbitrum |
| High Gas | 120,000,000 | BNB |
| Very High Gas | 250,000,000 | Mantle |
| Ultra High Gas | 5,000,000,000 | Sonic |
| MegaETH | 10,000,000,000 | MegaETH |

Reference transactions on the respective chain's explorer to determine the appropriate gas limit.

---

## Troubleshooting

- **`addSupportedDomains` reverts**: Check you're calling from the ADMIN address/Safe
- **`updateChainGateway` reverts**: Check you're calling from the OWNER address/Safe
- **`SupportedDomainAlreadyAdded`**: Domain was already registered; skip `addSupportedDomains`
- **Assertions fail in SetupDomainsAndGateways**: Make sure you commented out the assertions block (Step 2)
- **Wrong gateway**: The gateway must be 0-padded to bytes32; use `cast --to-bytes32` or `cast to-uint256`
