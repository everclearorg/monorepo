import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub } from 'sinon';
import { checkAgents } from '../../src/checklist/agent';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import * as mockFunctions from '../../src/mockable';

describe('checkAgents', () => {
  let axiosGetStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    axiosGetStub = stub(mockFunctions, 'axiosGet');
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkAgents', () => {
    it('should work', async () => {
      axiosGetStub.resolves({ status: 200, data: { agents: { 1337: 1, 1338: 1 } } });
      expect(checkAgents()).to.be.returned;
      expect(axiosGetStub.callCount).to.eq(1);
    });

    it('should return false if status code is not 200', async () => {
      axiosGetStub.resolves({ status: 201, data: { agents: { 1337: 1, 1338: 1 } } });
      expect(checkAgents()).to.be.returned;
      expect(axiosGetStub.callCount).to.eq(1);
    });

    it('should catch error', async () => {
      axiosGetStub.throws('error');
      expect(checkAgents()).to.be.returned;
      expect(axiosGetStub.callCount).to.eq(1);
    });
  });
});
