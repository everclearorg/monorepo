import { reset, restore } from 'sinon';

export const mochaHooks = {
  beforeEach() {},

  afterEach() {
    restore();
    reset();
  },
};
