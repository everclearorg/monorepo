import { Logger, mkAddress } from '@chimera-monorepo/utils';
import { CachedTaskData, TasksCache } from '@chimera-monorepo/adapters-cache';
import { Wallet } from 'ethers';
import { createStubInstance } from 'sinon';

import { AppContext, RelayerConfig } from '../src/lib/entities';
import { ChainService } from '@chimera-monorepo/chainservice';

export const createRelayerConfig = (overrides: Partial<RelayerConfig> = {}) => {
  const config = {
    chains: {
      '1337': {
        providers: ['http://rpc-1337:8545'],
        deployments: {
          everclear: mkAddress('0x1337ccc'),
          gateway: mkAddress('0x1337fff'),
        },
        minGasPrice: '3',
      },
      '1338': {
        providers: ['http://rpc-1338:8545'],
        deployments: {
          everclear: mkAddress('0x1338ccc'),
          gateway: mkAddress('0x1338fff'),
        },
        minGasPrice: '3',
      },
    },
    hub: {
      domain: '6398',
      // NOTE: changing ^^ will require updating the `getDefaultABIConfig`
      // function, or its invocation within the config.ts file.
      providers: ['http://rpc-6398:8545'],
      deployments: {
        everclear: mkAddress('0x6398ccc'),
        gateway: mkAddress('0x6398fff'),
        gauge: mkAddress('0x6398eee'),
        rewardDistributor: mkAddress('0x6398bbb'),
        tokenomicsHubGateway: mkAddress('0x6398aaaa'),
      },
      minGasPrice: '3',
    },
    web3SignerUrl: 'http://web3-signer:8080',
    server: {
      adminToken: 'foobar',
    },
    redis: {
      host: 'http://redis:8080',
    },
    ...overrides,
  };
  return config;
};

export const createProcessEnv = (overrides: Partial<RelayerConfig> = {}) => {
  return {
    RELAYER_CONFIG: JSON.stringify(createRelayerConfig(overrides)),
    RELAYER_CONFIG_FILE: 'test-config.json',
  };
};

export const createAppContext = (overrides: Partial<RelayerConfig> = {}): AppContext => {
  return {
    logger: createStubInstance(Logger),
    config: createRelayerConfig({
      poller: { port: 8080, host: 'http://localhost', interval: 1000 },
      ...overrides,
    }) as RelayerConfig,
    adapters: {
      wallet: createStubInstance(Wallet),
      cache: {
        tasks: createStubInstance(TasksCache),
      },
      chainservice: createStubInstance(ChainService),
    },
  };
};

export const createTask = (overrides: Partial<CachedTaskData> = {}): CachedTaskData => {
  return {
    to: mkAddress('0x1234'),
    data: '0xencoded',
    chain: 1337,
    fee: {
      amount: '100',
      token: mkAddress(),
      chain: 1338,
    },
    ...overrides,
  };
};
