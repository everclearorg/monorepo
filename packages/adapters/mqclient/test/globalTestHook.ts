import { restore, reset } from 'sinon';

export const mochaHooks = {
  afterEach() {
    restore();
    reset();
  },
};
