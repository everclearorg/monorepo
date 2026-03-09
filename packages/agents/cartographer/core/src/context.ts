import { ChainData, Logger } from '@chimera-monorepo/utils';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { Database } from '@chimera-monorepo/database';

import { CartographerConfig } from './config';

export type AppContext = {
  logger: Logger;
  adapters: {
    subgraph: SubgraphReader;
    chainreader: ChainReader;
    database: Database;
  };
  config: CartographerConfig;
  chainData: Map<string, ChainData>;
  domains: string[];
};
