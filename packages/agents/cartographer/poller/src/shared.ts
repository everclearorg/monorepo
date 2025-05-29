/* eslint-disable @typescript-eslint/no-explicit-any */
import { ChainData, Logger } from '@chimera-monorepo/utils';
import { SubgraphReader as _SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { Database } from '@chimera-monorepo/database';

import { CartographerConfig } from './config';

export const SubgraphReader = _SubgraphReader;

export type AppContext = {
  logger: Logger;
  adapters: {
    subgraph: _SubgraphReader; // Subgraph adapter.
    database: Database; // Database adapter.
  };
  config: CartographerConfig;
  chainData: Map<string, ChainData>;
  domains: string[]; // List of all supported domains.
};

export const context: AppContext = {} as any;
export const getContext = () => context;
