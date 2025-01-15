import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkDepositQueueCount, checkDepositQueueLatency } from '../../../src/checklist/queue/deposit';
import { getContextStub, mock } from '../../globalTestHook';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import { mkHash } from '@chimera-monorepo/utils';
import * as Mockable from '../../../src/mockable';

describe('checkDepositQueueState', () => {
  let chainreader: SinonStubbedInstance<ChainReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let database: SinonStubbedInstance<Database>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    const enqueuedDeposit = mock.depositQueue();
    database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
    sendAlertsStub = stub(Mockable, 'sendAlerts');
    stub(Mockable, 'resolveAlerts').resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkDepositQueueCount', () => {
    it('should work', async () => {
      const epoch = 100;
      const domain = '1337';
      const tickerHash = mkHash('0x1234');
      const enqueuedDeposit = mock.depositQueue({ epoch, domain, tickerHash });
      database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
      const result = await checkDepositQueueCount();
      const validResult = new Map([[`100-1337-${tickerHash}`, 1]]);
      expect(result).to.deep.equal(validResult);
    });
    it('should work with no data in db', async () => {
      database.getAllEnqueuedDeposits.resolves([]);
      const result = await checkDepositQueueCount();
      const validEmptyResult = new Map();
      expect(result).to.deep.equal(validEmptyResult);
    });

    it('should send alert', async () => {
      await checkDepositQueueCount();
      expect(sendAlertsStub.callCount).to.eq(1);
    });
  });

  describe('#checkDepositQueueLatency', () => {
    it('should work with no pending deposits', async () => {
      const result = await checkDepositQueueLatency();
      expect(Object.keys(result.keys()).length).to.eq(0);
    });

    it('should work with pending deposits', async () => {
      sendAlertsStub.resolves();
      const epoch = 100;
      const domain = '1337';
      const tickerHash = mkHash('0x1234');
      const enqueuedDeposit = mock.depositQueue({ epoch, domain, tickerHash, enqueuedTimestamp: 1 });
      database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
      await checkDepositQueueLatency();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should fail', async () => {
      expect(checkDepositQueueLatency()).to.be.rejected;
    });
  });
});
