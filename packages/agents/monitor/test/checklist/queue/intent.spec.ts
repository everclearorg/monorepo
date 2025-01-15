import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkFillQueueCount, checkFillQueueLatency, checkIntentQueueCount } from '../../../src/checklist/queue/intent';
import { getContextStub, mock } from '../../globalTestHook';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../../src/mockable';

describe('Queue Checklist - intent', () => {
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
    const intent = mock.destinationIntent({ destination: '1337' });
    const contents = new Map();
    contents.set(intent.destination, [intent]);
    database.getMessageQueueContents.resolves(contents);
    sendAlertsStub = stub(Mockable, 'sendAlerts');
    stub(Mockable, 'resolveAlerts').resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkFillQueueCount', () => {
    it('should work', async () => {
      const result = await checkFillQueueCount();
      const validResult = new Map([
        ['1337', 1],
        ['1338', 0],
      ]);
      expect(result).to.deep.equal(validResult);
    });
    it('should work with no data in db', async () => {
      database.getMessageQueueContents.resolves(new Map());
      const result = await checkFillQueueCount();
      const validEmptyResult = new Map([
        ['1337', 0],
        ['1338', 0],
      ]);
      expect(result).to.deep.equal(validEmptyResult);
    });

    it('should send alert', async () => {
      await checkFillQueueCount();
      expect(sendAlertsStub.callCount).to.eq(1);
    });
  });

  describe('#checkFillQueueLatency', () => {
    it('should work with no pending executions', async () => {
      const result = await checkFillQueueLatency();
      expect(Object.keys(result.keys()).length).to.eq(0);
    });

    it('should work with pending executions', async () => {
      sendAlertsStub.resolves();
      const intent = mock.destinationIntent({ destination: '1337', timestamp: 1 });
      const contents = new Map();
      contents.set(intent.destination, [intent]);
      database.getMessageQueueContents.resolves(contents);
      await checkFillQueueLatency();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should fail', async () => {
      expect(checkFillQueueLatency()).to.be.rejected;
    });
  });

  describe('#checkIntentQueueCount', () => {
    it('should work', async () => {
      const result = await checkIntentQueueCount();
      const validResult = new Map([
        ['1337', 1],
        ['1338', 0],
      ]);
      expect(result).to.deep.equal(validResult);
    });
  });
});
