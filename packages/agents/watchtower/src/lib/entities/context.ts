import { Wallet } from 'ethers';
import { Web3Signer } from '@chimera-monorepo/adapters-web3signer';
import { ChainData, Logger } from '@chimera-monorepo/utils';
import { ChainService } from '@chimera-monorepo/chainservice';
import { StoreManager } from '@chimera-monorepo/adapters-cache';

import { WatcherConfig } from '.';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';

export type AppContext = {
  config: WatcherConfig;
  adapters: {
    wallet: Wallet | Web3Signer;
    cache: StoreManager; // Used to cache important data locally.
    chainservice: ChainService; // For reading blockchain using RPC providers.
    subgraph: SubgraphReader;
  };
  logger: Logger;
  chainData: Map<string, ChainData>;
};
