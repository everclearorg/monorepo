import { expect } from '@chimera-monorepo/utils';
import { makeLighthouse } from '../../src/tasks';

describe('Make Lighthouse', () => {
  describe('#makeLighthouse', () => {
    it('should work', async () => {
      await expect(makeLighthouse()).to.be.ok;
    });
  });
});
