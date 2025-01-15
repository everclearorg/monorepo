import { reset, restore, stub } from 'sinon';
import { createAppContext } from './mock';
import { AppContext } from '../src/shared';

import * as ChimeraDatabase from '@chimera-monorepo/database';
import * as Shared from '../src/shared';

export let mockAppContext: AppContext;

export const mochaHooks = {
  beforeEach() {
    mockAppContext = createAppContext();

    stub(ChimeraDatabase, 'getDatabase').resolves(mockAppContext.adapters.database);
    stub(Shared, 'getContext').returns(mockAppContext);
  },

  afterEach() {
    restore();
    reset();
  },
};
