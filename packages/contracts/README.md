# Chimera Smart Contracts Package

## Prerequisites

Install foundry or update with `foundryup`.

Run:
- `yarn workspace @chimera-monorepo/contracts forge clean`
- `yarn workspace @chimera-monorepo/contracts forge install`
- `yarn workspace @chimera-monorepo/contracts forge build`

## Scripts configuration

### Protocol variables

The protocol variables for contracts deployment and configuration are fetched from the environment files located at `script/<environment>` (e.g. `TestnetStaging.sol`).

The `TestnetStaging.sol` environment file defines the following contracts:

- `DefaultValues` for the default protocol variables (e.g. epoch length, expiry time buffer, etc)
- `TestnetAssets` for the staging assets addresses
- `TestnetStagingDomains` for the environment domains and their details and addresses
- `TestnetStagingEnvironment` for defining the `EverclearHub` initialization parameters

### Domains

The domains to be used must be configured in:

- `script/<environment>.sol` (the domains for a specific environment)
- `cli/config/domains.json` (all the domains for all environments)

In `domains.json`, the declared domains follow the following interface:

```typescript
interface Domain {
  name: string;
  id: number;
  rpc: string;
  verifierUrl?: string;
  verifierAPIKey?: string;
  maxBlockGasLimit: number;
  environment: Environment;
  realm: Realm;
  owner?: Address; // viem address type
}

enum Environment {
  TESTNET_STAGING = 'TestnetStaging',
  MAINNET_STAGING = 'MainnetStaging',
  TESTNET_PRODUCTION = 'TestnetProduction',
  MAINNET_PRODUCTION = 'MainnetProduction',
}

enum Realm {
  HUB = 'hub',
  SPOKE = 'spoke',
}
```

### Deployments

To be able to interact with deployed contracts these must be declared in:

- `cli/config/hub.json` for the `EverclearHub` contracts
- `cli/config/spoke.json` for the `EverclearSpoke` contracts

Both follow the following interface:

```typescript
interface Contract {
  address: Address; // viem address type
  domainName: string;
  domainId: number;
}
```

### Assets

To whitelist and update asset configurations these must be declared in:

- `cli/config/assets/<environment>.json` for listing all the assets for an environment
- `script/assets/<environment>/<asset_symbol>.sol` for the actual adopted and fees configuration

In `cli/config/assets/<environment>.json` the assets follow the interface:

```typescript
interface Asset {
  symbol: string;
  contractName: string;
}
```

## Using the script CLI

For each task, the CLI will ask the user to select options or input values.
In order for it to work properly, the necessary domains, contracts and protocol arguments must be previously configured in the files explained _ut supra_.

Before running each script, the user will be asked to choose the account to broadcast from. All private keys defined in `.env` will be fetched no matter their variable name (without exposing any value) and shown as options to choose from.

To start the CLI tool run:

```console
$ yarn cli
```

This will show the user the following options:

- deploy Hub or Spoke contracts
- setup domains and gateways
- update protocol variables
- set / update asset configuration

### Deploy Contracts

Steps:

- choose between Hub or Spoke contracts
- choose environment
- choose domain to deploy to (if there is only one domain, that one will be used)
- choose the private key to broadcast from
- choose if the run must be broadcasted or dry ran
- after deployment, update the `deployments/<environment>/<domain>/<contract>.json` file with the new `address`, `startBlock`, and `abi` (usually in `out/<contract>.sol`)

Note: if deployments fail, it may be due to an out of gas error. This can be resolved by running the `forge script` command with the `--gas-estimate-multiplier` set higher (e.g. 300 for 3x the estimate, default is 130).

### Setup hub domains and gateways

Steps:

- Deploy the hub contracts
- Update the environment file in `script/<environment>.sol`

### Update protocol variable

Steps:

- choose between Hub or Spoke contracts
- choose environment
- choose domain
- choose the variable to update and input the required arguments
- choose the private key to broadcast from
- choose if the run must be broadcasted or dry ran

### Set / update asset configuration

Steps:

- choose environment
- choose the asset to setup or update (fetched from `cli/config/assets/<environment>.json`)
- choose the private key to broadcast from
- choose if the run must be broadcasted or dry ran
