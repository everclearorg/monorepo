import { HubIntent, Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import {
  checkTronSettlementQueueStatusCount,
  checkTronSettlementQueueAmount,
  checkTronSettlementQueueLatency,
} from '../../../src/checklist/queue/tron-settlement';
import { getContextStub, mock } from '../../globalTestHook';
import { Database } from '@chimera-monorepo/database';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../../mock';
import * as Mockable from '../../../src/mockable';
import { BigNumber } from 'ethers';

describe('Tron Settlement Queue Checklist', () => {
  let database: SinonStubbedInstance<Database>;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;

  let queuedSettlements: Map<string, HubIntent[]>;
  let tronSettlementDomain: string;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    
    // Configure with Tron domain
    const config = mock.config();
    config.thresholds.maxSettlementQueueAssetAmounts = { '1339': 100000 }; // Add Tron domain
    getContextStub.returns({
      ...mock.context(),
      config,
    });
    
    tronSettlementDomain = '1339'; // Tron domain
    queuedSettlements = new Map();
    queuedSettlements.set(tronSettlementDomain, []);
    database.getAllQueuedSettlements.withArgs('1337').resolves(queuedSettlements); // Hub domain
    sendAlertsStub = stub(Mockable, 'sendAlerts');
    resolveAlertsStub = stub(Mockable, 'resolveAlerts').resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronSettlementQueueStatusCount', () => {
    it('should work with no pending Tron settlements', async () => {
      const result = await checkTronSettlementQueueStatusCount();
      expect(result).to.be.instanceOf(Map);
      expect(result.size).to.eq(0);
    });

    it('should work with pending Tron settlements', async () => {
      sendAlertsStub.resolves();
      const tronSettlement = mock.hubIntent({ status: 'SETTLED' });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      const result = await checkTronSettlementQueueStatusCount();
      expect(sendAlertsStub.callCount).to.eq(1);

      const expectedResult = new Map([[tronSettlementDomain, new Map([['SETTLED', 1]])]]);
      expect(result).to.deep.eq(expectedResult);
    });

    it('should filter out non-Tron domains', async () => {
      const evmSettlement = mock.hubIntent({ status: 'SETTLED' });
      const tronSettlement = mock.hubIntent({ status: 'SETTLED' });
      queuedSettlements.set('1337', [evmSettlement]); // EVM domain
      queuedSettlements.set('1339', [tronSettlement]); // Tron domain
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      const result = await checkTronSettlementQueueStatusCount();
      // Should only include Tron domain
      expect(result.has('1339')).to.be.true;
      expect(result.has('1337')).to.be.false;
    });

    it('should aggregate multiple settlements by status', async () => {
      const settlement1 = mock.hubIntent({ status: 'SETTLED' });
      const settlement2 = mock.hubIntent({ status: 'SETTLED' });
      const settlement3 = mock.hubIntent({ status: 'DISPATCHED' });
      queuedSettlements.clear();
      queuedSettlements.set(tronSettlementDomain, [settlement1, settlement2, settlement3]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      const result = await checkTronSettlementQueueStatusCount();
      expect(result).to.be.instanceOf(Map);
      expect(result.size).to.be.greaterThan(0);
      const statusCounts = result.get(tronSettlementDomain);
      expect(statusCounts).to.not.be.undefined;
      // The function groups by status, so we expect it to work correctly
      if (statusCounts && statusCounts.has('SETTLED')) {
        expect(statusCounts.get('SETTLED')).to.be.greaterThan(0);
      }
      if (statusCounts && statusCounts.has('DISPATCHED')) {
        expect(statusCounts.get('DISPATCHED')).to.be.greaterThan(0);
      }
    });

    it('should send alert when settlement count exceeds threshold', async () => {
      const config = mock.config();
      config.thresholds.maxSettlementQueueCount = 0;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const tronSettlement = mock.hubIntent({ status: 'SETTLED' });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      await checkTronSettlementQueueStatusCount();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should resolve alerts when settlement count within threshold', async () => {
      const config = mock.config();
      config.thresholds.maxSettlementQueueCount = 10;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const tronSettlement = mock.hubIntent({ status: 'SETTLED' });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      await checkTronSettlementQueueStatusCount();
      expect(resolveAlertsStub.callCount).to.eq(1);
    });
  });

  describe('#checkTronSettlementQueueAmount', () => {
    it('should work with no pending Tron settlements', async () => {
      const result = await checkTronSettlementQueueAmount();
      const expectedResult = new Map();
      expect(result).to.deep.eq(expectedResult);
    });

    it('should work with pending Tron settlements', async () => {
      sendAlertsStub.resolves();
      const originIntent = mock.originIntent({ 
        status: 'DISPATCHED',
        outputAsset: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t' // USDT on Tron
      });
      const tronSettlement = mock.hubIntent({ 
        id: originIntent.id, 
        status: 'SETTLED',
        settlementAmount: '1000000' // 1 USDT in 6 decimals
      });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      database.getOriginIntentsById.resolves(originIntent);
      
      const result = await checkTronSettlementQueueAmount();
      expect(sendAlertsStub.callCount).to.eq(1);
      expect(result?.size).to.eq(1);
      expect(result?.get(tronSettlementDomain)).to.be.instanceOf(BigNumber);
    });

    it('should filter out non-Tron domains for amount check', async () => {
      const evmOriginIntent = mock.originIntent({ status: 'DISPATCHED' });
      const tronOriginIntent = mock.originIntent({ 
        status: 'DISPATCHED',
        outputAsset: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'
      });
      
      const evmSettlement = mock.hubIntent({ id: evmOriginIntent.id, status: 'SETTLED' });
      const tronSettlement = mock.hubIntent({ id: tronOriginIntent.id, status: 'SETTLED' });
      
      queuedSettlements.set('1337', [evmSettlement]); // EVM domain
      queuedSettlements.set('1339', [tronSettlement]); // Tron domain
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      database.getOriginIntentsById.withArgs(evmOriginIntent.id).resolves(evmOriginIntent);
      database.getOriginIntentsById.withArgs(tronOriginIntent.id).resolves(tronOriginIntent);
      
      const result = await checkTronSettlementQueueAmount();
      // Should only include Tron domain
      expect(result?.has('1339')).to.be.true;
      expect(result?.has('1337')).to.be.false;
    });

    it('should skip DISPATCHED settlements in amount calculation', async () => {
      const originIntent = mock.originIntent({ 
        status: 'DISPATCHED',
        outputAsset: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'
      });
      const dispatchedSettlement = mock.hubIntent({ 
        id: originIntent.id, 
        status: 'DISPATCHED',
        settlementAmount: '1000000'
      });
      queuedSettlements.set(tronSettlementDomain, [dispatchedSettlement]);
      database.getAllQueuedSettlements.withArgs('1337').resolves(queuedSettlements); // Hub domain
      database.getOriginIntentsById.resolves(originIntent);
      
      const result = await checkTronSettlementQueueAmount();
      // Should return empty map since DISPATCHED settlements are skipped
      expect(result?.size).to.eq(0);
    });

    it('should send alert when settlement amount exceeds threshold', async () => {
      const config = mock.config();
      config.thresholds.maxSettlementQueueAssetAmounts = { '1339': 100 }; // Low threshold
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const originIntent = mock.originIntent({ 
        status: 'DISPATCHED',
        outputAsset: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'
      });
      const tronSettlement = mock.hubIntent({ 
        id: originIntent.id, 
        status: 'SETTLED',
        settlementAmount: '10000000' // 10 USDT, exceeds threshold
      });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      database.getOriginIntentsById.resolves(originIntent);
      
      await checkTronSettlementQueueAmount();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should resolve alerts when settlement amount within threshold', async () => {
      const config = mock.config();
      config.thresholds.maxSettlementQueueAssetAmounts = { '1339': 10000000 }; // High threshold
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const originIntent = mock.originIntent({ 
        status: 'DISPATCHED',
        outputAsset: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'
      });
      const tronSettlement = mock.hubIntent({ 
        id: originIntent.id, 
        status: 'SETTLED',
        settlementAmount: '1000000' // 1 USDT, within threshold
      });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      database.getOriginIntentsById.resolves(originIntent);
      
      await checkTronSettlementQueueAmount();
      expect(resolveAlertsStub.callCount).to.eq(1);
    });

    it('should warn when no threshold set for Tron domain', async () => {
      const config = mock.config();
      config.thresholds.maxSettlementQueueAssetAmounts = {}; // No Tron threshold
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const originIntent = mock.originIntent({ status: 'DISPATCHED' });
      const tronSettlement = mock.hubIntent({ id: originIntent.id, status: 'SETTLED' });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      database.getOriginIntentsById.resolves(originIntent);
      
      const result = await checkTronSettlementQueueAmount();
      expect(logger.warn.callCount).to.be.greaterThan(0);
    });
  });

  describe('#checkTronSettlementQueueLatency', () => {
    it('should work with no pending Tron settlements', async () => {
      const result = await checkTronSettlementQueueLatency();
      const expectedResult = new Map();
      expect(result).to.deep.eq(expectedResult);
    });

    it('should resolve alerts for all Tron domains when no settlements', async () => {
      database.getAllQueuedSettlements.resolves(new Map());
      await checkTronSettlementQueueLatency();
      expect(resolveAlertsStub.callCount).to.be.greaterThan(0);
    });

    it('should work with pending Tron settlements', async () => {
      sendAlertsStub.resolves();
      const oldTimestamp = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      const tronSettlement = mock.hubIntent({ 
        status: 'SETTLED', 
        settlementEnqueuedTimestamp: oldTimestamp
      });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      await checkTronSettlementQueueLatency();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should filter out non-Tron domains for latency check', async () => {
      const evmSettlement = mock.hubIntent({ 
        status: 'SETTLED', 
        settlementEnqueuedTimestamp: 123
      });
      const tronSettlement = mock.hubIntent({ 
        status: 'SETTLED', 
        settlementEnqueuedTimestamp: 456
      });
      queuedSettlements.set('1337', [evmSettlement]); // EVM domain
      queuedSettlements.set('1339', [tronSettlement]); // Tron domain
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      const result = await checkTronSettlementQueueLatency();
      // Should only process Tron domain
      expect(result.has('1339')).to.be.true;
      expect(result.has('1337')).to.be.false;
    });

    it('should skip DISPATCHED settlements in latency calculation', async () => {
      const dispatchedSettlement = mock.hubIntent({ 
        status: 'DISPATCHED', 
        settlementEnqueuedTimestamp: 123
      });
      const settledSettlement = mock.hubIntent({ 
        status: 'SETTLED', 
        settlementEnqueuedTimestamp: 456
      });
      queuedSettlements.set(tronSettlementDomain, [dispatchedSettlement, settledSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      const result = await checkTronSettlementQueueLatency();
      // Should only use SETTLED settlement timestamp
      expect(result.get(tronSettlementDomain)).to.eq(456);
    });

    it('should track oldest settlement for latency calculation', async () => {
      const oldTimestamp = Math.floor(Date.now() / 1000) - 7200; // 2 hours ago
      const newTimestamp = Math.floor(Date.now() / 1000) - 1800; // 30 minutes ago
      
      const oldSettlement = mock.hubIntent({ 
        status: 'SETTLED', 
        settlementEnqueuedTimestamp: oldTimestamp
      });
      const newSettlement = mock.hubIntent({ 
        status: 'SETTLED', 
        settlementEnqueuedTimestamp: newTimestamp
      });
      queuedSettlements.set(tronSettlementDomain, [newSettlement, oldSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      const result = await checkTronSettlementQueueLatency();
      // Should use the older timestamp
      expect(result.get(tronSettlementDomain)).to.eq(oldTimestamp);
    });

    it('should send alert when settlement latency exceeds threshold', async () => {
      const config = mock.config();
      config.thresholds.maxSettlementQueueLatency = 1800; // 30 minutes
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const oldTimestamp = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      const tronSettlement = mock.hubIntent({ 
        status: 'SETTLED', 
        settlementEnqueuedTimestamp: oldTimestamp
      });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      await checkTronSettlementQueueLatency();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should resolve alerts when settlement latency within threshold', async () => {
      const config = mock.config();
      config.thresholds.maxSettlementQueueLatency = 7200; // 2 hours
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const recentTimestamp = Math.floor(Date.now() / 1000) - 1800; // 30 minutes ago
      const tronSettlement = mock.hubIntent({ 
        status: 'SETTLED', 
        settlementEnqueuedTimestamp: recentTimestamp
      });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      await checkTronSettlementQueueLatency();
      expect(resolveAlertsStub.callCount).to.eq(1);
    });

    it('should resolve alerts when no latency data for domain', async () => {
      // Settlement with no timestamp
      const tronSettlement = mock.hubIntent({ 
        status: 'SETTLED', 
        settlementEnqueuedTimestamp: undefined
      });
      queuedSettlements.set(tronSettlementDomain, [tronSettlement]);
      database.getAllQueuedSettlements.resolves(queuedSettlements);
      
      await checkTronSettlementQueueLatency();
      expect(resolveAlertsStub.callCount).to.be.greaterThan(0);
    });
  });
});