import { reset, restore, stub } from 'sinon';
import { AppContext } from '../src/lib/entities';
import * as Make from '../src/watcher';

import { createAppContext } from './mock';

export let mockAppContext: AppContext;

export const mochaHooks = {
  beforeEach() {
    mockAppContext = createAppContext();

    stub(Make, 'getContext').returns(mockAppContext);
  },

  afterEach() {
    restore();
    reset();
  },
};
