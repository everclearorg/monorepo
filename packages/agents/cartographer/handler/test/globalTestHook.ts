import { reset, restore } from 'sinon';

export const mochaHooks = {
  afterEach() {
    restore();
    reset();
  },
};
