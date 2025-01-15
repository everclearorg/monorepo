import { Address, Hash } from 'viem';

/**
 * @dev These enum values must match the values in:
 * - `domains.json`
 * - `assets/${env}/..`
 * - the contract script postfixes (i.e. `SetupDomainsAndGatewaysStaging.s.sol`, etc.)
 */
export enum Environment {
  TESTNET_STAGING = 'TestnetStaging',
  MAINNET_STAGING = 'MainnetStaging',
  TESTNET_PRODUCTION = 'TestnetProduction',
  MAINNET_PRODUCTION = 'MainnetProduction',
}

export enum Realm {
  HUB = 'hub',
  SPOKE = 'spoke',
}

enum Strategy {
  DEFAULT,
  XERC20,
}

export interface Contract {
  address: Address;
  domainName: string;
  domainId: number;
  environment: Environment;
}

export interface Domain {
  name: string;
  id: number;
  rpc: string;
  verifierUrl?: string;
  verifierAPIKey?: string;
  maxBlockGasLimit?: number;
  environments: Environment[];
  realm: Realm;
  owner?: Address;
}

interface Fees {
  recipient: Address;
  fee: number;
}

interface Adopted {
  tickerHash: Hash;
  adopted: Hash;
  domain: number;
  approved: boolean;
  straegy: Strategy;
}

export interface AssetConfiguration {
  ticker: string;
  tickerHash: Hash;
  initLastClosedEpoch: boolean;
  prioritizedStrategy: Strategy;
  maxDiscountBPS: number;
  discountPerEpoch: number;
  fees: Fees[];
  adopted: Adopted[];
}
