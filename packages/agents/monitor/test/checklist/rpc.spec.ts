import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub } from 'sinon';
import { checkRpcs } from '../../src/checklist/rpc';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import * as Mockable from '../../src/mockable';

describe('checkRpcs', () => {
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;

  beforeEach(() => {
    reset();
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkRpcs', () => {
    it('should not leak api key to alert', async () => {
      await checkRpcs();
      expect(sendAlertsStub.callCount).to.be.eq(4);
      expect((sendAlertsStub.getCall(0).args[0] as any).reason).to.not.contain("mock_api_key");
    });
  });
});
