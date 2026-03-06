/* eslint-disable @typescript-eslint/no-explicit-any */
import { SubgraphReader as _SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { AppContext } from '@chimera-monorepo/cartographer-core';

export type { AppContext } from '@chimera-monorepo/cartographer-core';

export const SubgraphReader = _SubgraphReader;

export const context: AppContext = {} as any;
export const getContext = () => context;
