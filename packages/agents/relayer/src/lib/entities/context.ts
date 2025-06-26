import { EthWallet } from '@chimera-monorepo/chainservice';
import { Web3Signer } from '@chimera-monorepo/adapters-web3signer';
import { Logger } from '@chimera-monorepo/utils';
import { StoreManager } from '@chimera-monorepo/adapters-cache';
import { ChainService } from '@chimera-monorepo/chainservice';

import { RelayerConfig } from '.';

export type AppContext = {
  logger: Logger;
  adapters: {
    // Stateful interfaces for peripherals.
    wallet: EthWallet | Web3Signer;
    cache: StoreManager; // Used to cache important data locally.
    chainservice: ChainService; // For reading blockchain using RPC providers.
  };
  config: RelayerConfig;
};
