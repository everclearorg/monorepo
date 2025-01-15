import { HubIntent, Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import {
  checkSettlementQueueStatusCount,
  checkSettlementQueueAmount,
  checkSettlementQueueLatency,
} from '../../../src/checklist/queue';
import { getContextStub, mock } from '../../globalTestHook';
import { Database } from '@chimera-monorepo/database';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../../mock';
import * as Mockable from '../../../src/mockable';

describe('Checklist - Settlement Queue', () => {
  let database: SinonStubbedInstance<Database>;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;

  let queuedSettlements: Map<string, HubIntent[]>;
  let settlementDomain: string;

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
    settlementDomain = Object.keys(mock.chains())[0];
    queuedSettlements = new Map();
    queuedSettlements.set(settlementDomain, []);
    database.getAllQueuedSettlements.resolves(queuedSettlements);
    sendAlertsStub = stub(Mockable, 'sendAlerts');
    stub(Mockable, 'resolveAlerts').resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkSettlementQueueStatusCount', () => {
    it('should work with no pending settlements', async () => {
      const result = await checkSettlementQueueStatusCount();
      const expectedResult = new Map([[settlementDomain, new Map()]]);
      expect(result).to.deep.eq(expectedResult);
    });

    it('should work with pending settlements', async () => {
      sendAlertsStub.resolves();
      queuedSettlements.set(settlementDomain, [mock.hubIntent({ status: 'SETTLED' })]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      const result = await checkSettlementQueueStatusCount();
      expect(sendAlertsStub.callCount).to.eq(1);

      const expectedResult = new Map([[settlementDomain, new Map([['SETTLED', 1]])]]);
      expect(result).to.deep.eq(expectedResult);
    });

    it('should fail', async () => {
      expect(checkSettlementQueueStatusCount()).to.be.rejected;
    });
  });

  describe('#checkSettlementQueueAmount', () => {
    it('should work with no pending settlements', async () => {
      const result = await checkSettlementQueueAmount();
      const expectedResult = new Map();
      expect(result).to.deep.eq(expectedResult);
    });

    it('should work with pending settlements', async () => {
      sendAlertsStub.resolves();
      const originIntent = mock.originIntent({ status: 'DISPATCHED' });
      queuedSettlements.set(settlementDomain, [mock.hubIntent({ id: originIntent.id, status: 'SETTLED' })]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      database.getOriginIntentsById.resolves(originIntent);
      const result = await checkSettlementQueueAmount();
      expect(sendAlertsStub.callCount).to.eq(1);
      expect(result?.size).to.eq(1);
      expect(result?.get(settlementDomain)?.toString()).to.eq(queuedSettlements.get('1337')![0].settlementAmount);
    });

    it('should fail', async () => {
      expect(checkSettlementQueueAmount()).to.be.rejected;
    });
  });

  describe('#checkSettlementQueueLatency', () => {
    it('should work with no pending settlements', async () => {
      const result = await checkSettlementQueueLatency();
      const expectedResult = new Map();
      expect(result).to.deep.eq(expectedResult);
    });

    it('should work with pending settlements', async () => {
      sendAlertsStub.resolves();
      queuedSettlements.set(settlementDomain, [mock.hubIntent({ status: 'SETTLED', settlementEnqueuedTimestamp: 0 })]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      await checkSettlementQueueLatency();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should fail', async () => {
      expect(checkSettlementQueueLatency()).to.be.rejected;
    });
  });
});
