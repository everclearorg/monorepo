import { Logger, RelayerType } from '@chimera-monorepo/utils';
import { StoreManager } from '@chimera-monorepo/adapters-cache';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { Database } from '@chimera-monorepo/database';
import { MonitorConfig } from './types';
import { Relayer } from '@chimera-monorepo/adapters-relayer';

export type AppContext = {
  logger: Logger;
  adapters: {
    chainreader: ChainReader;
    cache: StoreManager;
    subgraph: SubgraphReader;
    database: Database;
    relayers: { instance: Relayer; apiKey: string; type: RelayerType }[];
  };
  config: MonitorConfig;
};

const context: AppContext = {} as AppContext;
export const getContext = () => context;
