import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkShadowExportStatus, checkShadowExportLatency } from '../../src/checklist/shadow';
import { getContextStub, mock } from '../globalTestHook';
import { Database } from '@chimera-monorepo/database';
import { createProcessEnv } from '../mock';
import * as Mockable from '../../src/mockable';

describe('shadow data export', () => {
  let sendAlertsStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;
  let database: SinonStubbedInstance<Database>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    stub(Mockable, 'resolveAlerts').resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkShadowExportStatus', () => {
    it('should send alert if exceeds threshold', async () => {
      database.getCheckPoint.resolves(Date.now());
      database.getLatestTimestamp.resolves(new Date(Date.now() - 30 * 60 * 1000));

      await checkShadowExportStatus();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should not send alert if threshold not exceeded', async () => {
      database.getCheckPoint.resolves(Date.now() - 10 * 1000);
      database.getLatestTimestamp.resolves(new Date());

      await checkShadowExportStatus();
      expect(sendAlertsStub.callCount).to.eq(0);
    });

    it('should not send alert if status not changed', async () => {
      const now = new Date();
      database.getCheckPoint.resolves(now.getTime());
      database.getLatestTimestamp.resolves(now);

      await checkShadowExportStatus();
      expect(sendAlertsStub.callCount).to.eq(0);
    });
  });

  describe('#checkShadowExportLatency', () => {
    it('should send alert if exceeds threshold', async () => {
      database.getCheckPoint.resolves(Date.now());
      database.getShadowEvents.resolves([ mock.shadowEvent({ blockTimestamp: new Date(Date.now() - 20 * 1000) }) ]);

      await checkShadowExportLatency();
      expect(sendAlertsStub.callCount).to.eq(1);
    });
  });
});
