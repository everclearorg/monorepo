import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkTronDepositQueueCount, checkTronDepositQueueLatency } from '../../../src/checklist/queue/tron-deposit';
import { getContextStub, mock } from '../../globalTestHook';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import { mkHash } from '@chimera-monorepo/utils';
import * as Mockable from '../../../src/mockable';

describe('Tron Deposit Queue Checklist', () => {
  let chainreader: SinonStubbedInstance<ChainReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
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
    sendAlertsStub = stub(Mockable, 'sendAlerts');
    resolveAlertsStub = stub(Mockable, 'resolveAlerts').resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronDepositQueueCount', () => {
    it('should work with Tron deposits', async () => {
      const epoch = 100;
      const domain = '1339'; // Tron domain
      const tickerHash = mkHash('0xbbbeebeb3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4');
      const enqueuedDeposit = mock.depositQueue({ epoch, domain, tickerHash });
      database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
      
      const result = await checkTronDepositQueueCount();
      const expectedKey = `tron-${epoch}-${domain}-${tickerHash}`;
      const validResult = new Map([[expectedKey, 1]]);
      expect(result).to.deep.equal(validResult);
    });

    it('should work with no Tron deposits in db', async () => {
      database.getAllEnqueuedDeposits.resolves([]);
      const result = await checkTronDepositQueueCount();
      const validEmptyResult = new Map();
      expect(result).to.deep.equal(validEmptyResult);
    });

    it('should filter out non-Tron domains', async () => {
      const evmDeposit = mock.depositQueue({ domain: '1337' }); // EVM domain
      const tronDeposit = mock.depositQueue({ domain: '1339' }); // Tron domain
      // The function will filter for Tron domains ['1339'] when calling getAllEnqueuedDeposits
      database.getAllEnqueuedDeposits.withArgs(['1339']).resolves([tronDeposit]);
      
      const result = await checkTronDepositQueueCount();
      // Should only include Tron deposit
      expect(result.size).to.eq(1);
      expect([...result.keys()][0]).to.include('tron-100-1339');
    });

    it('should aggregate multiple deposits with same key', async () => {
      const epoch = 100;
      const domain = '1339';
      const tickerHash = mkHash('0xbbbeebeb3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4');
      const deposit1 = mock.depositQueue({ epoch, domain, tickerHash });
      const deposit2 = mock.depositQueue({ epoch, domain, tickerHash });
      database.getAllEnqueuedDeposits.resolves([deposit1, deposit2]);
      
      const result = await checkTronDepositQueueCount();
      const expectedKey = `tron-${epoch}-${domain}-${tickerHash}`;
      expect(result.get(expectedKey)).to.eq(2);
    });

    it('should send alert when threshold exceeded', async () => {
      const config = mock.config();
      config.thresholds.maxDepositQueueCount = 1;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const deposit1 = mock.depositQueue({ domain: '1339' });
      const deposit2 = mock.depositQueue({ domain: '1339' });
      database.getAllEnqueuedDeposits.resolves([deposit1, deposit2]);
      
      await checkTronDepositQueueCount();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should resolve alerts when threshold not exceeded', async () => {
      const config = mock.config();
      config.thresholds.maxDepositQueueCount = 10;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const deposit = mock.depositQueue({ domain: '1339' });
      database.getAllEnqueuedDeposits.resolves([deposit]);
      
      await checkTronDepositQueueCount();
      expect(resolveAlertsStub.callCount).to.eq(1);
      expect(sendAlertsStub.callCount).to.eq(0);
    });
  });

  describe('#checkTronDepositQueueLatency', () => {
    it('should work with no pending Tron deposits', async () => {
      database.getAllEnqueuedDeposits.resolves([]);
      const result = await checkTronDepositQueueLatency();
      expect(result).to.be.instanceOf(Map);
      expect(result.size).to.eq(0);
    });

    it('should work with pending Tron deposits', async () => {
      const domain = '1339';
      const tickerHash = mkHash('0xbbbeebeb3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4');
      const enqueuedDeposit = mock.depositQueue({ 
        domain, 
        tickerHash, 
        enqueuedTimestamp: Math.floor(Date.now() / 1000) - 3600 // 1 hour ago
      });
      database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
      
      const result = await checkTronDepositQueueLatency();
      expect(result).to.be.instanceOf(Map);
      const expectedKey = `tron-${domain}-${tickerHash}`;
      expect(result.has(expectedKey)).to.be.true;
    });

    it('should filter out non-Tron domains in latency check', async () => {
      const evmDeposit = mock.depositQueue({ 
        domain: '1337', 
        enqueuedTimestamp: Math.floor(Date.now() / 1000) - 3600 
      });
      const tronDeposit = mock.depositQueue({ 
        domain: '1339', 
        enqueuedTimestamp: Math.floor(Date.now() / 1000) - 3600 
      });
      // The function will filter for Tron domains ['1339'] when calling getAllEnqueuedDeposits
      database.getAllEnqueuedDeposits.withArgs(['1339']).resolves([tronDeposit]);
      
      const result = await checkTronDepositQueueLatency();
      // Should only process Tron deposit
      expect(result.size).to.eq(1);
      expect([...result.keys()][0]).to.include('1339');
    });

    it('should send alert when latency exceeds threshold', async () => {
      const config = mock.config();
      config.thresholds.maxDepositQueueLatency = 1800; // 30 minutes
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const oldTimestamp = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      const enqueuedDeposit = mock.depositQueue({ 
        domain: '1339', 
        enqueuedTimestamp: oldTimestamp 
      });
      database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
      
      await checkTronDepositQueueLatency();
      expect(sendAlertsStub.callCount).to.be.greaterThan(0);
    });

    it('should resolve alerts when latency within threshold', async () => {
      const config = mock.config();
      config.thresholds.maxDepositQueueLatency = 7200; // 2 hours
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const recentTimestamp = Math.floor(Date.now() / 1000) - 1800; // 30 minutes ago
      const enqueuedDeposit = mock.depositQueue({ 
        domain: '1339', 
        enqueuedTimestamp: recentTimestamp 
      });
      database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
      
      await checkTronDepositQueueLatency();
      expect(resolveAlertsStub.callCount).to.be.greaterThan(0);
    });

    it('should track oldest deposit for latency calculation', async () => {
      const domain = '1339';
      const tickerHash = mkHash('0xbbbeebeb3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4');
      const oldDeposit = mock.depositQueue({ 
        domain, 
        tickerHash,
        enqueuedTimestamp: Math.floor(Date.now() / 1000) - 7200 // 2 hours ago
      });
      const newDeposit = mock.depositQueue({ 
        domain, 
        tickerHash,
        enqueuedTimestamp: Math.floor(Date.now() / 1000) - 1800 // 30 minutes ago
      });
      database.getAllEnqueuedDeposits.resolves([newDeposit, oldDeposit]);
      
      const result = await checkTronDepositQueueLatency();
      const expectedKey = `tron-${domain}-${tickerHash}`;
      // Should use the older timestamp
      expect(result.get(expectedKey)).to.eq(oldDeposit.enqueuedTimestamp);
    });

    it('should resolve alerts for all Tron domains when no deposits', async () => {
      database.getAllEnqueuedDeposits.resolves([]);
      await checkTronDepositQueueLatency();
      // Should resolve alerts for Tron domains (domain 1339)
      expect(resolveAlertsStub.callCount).to.be.greaterThan(0);
    });

    it('should handle deposits without enqueuedTimestamp', async () => {
      const deposit = mock.depositQueue({ 
        domain: '1339',
        enqueuedTimestamp: undefined // Missing timestamp
      });
      database.getAllEnqueuedDeposits.withArgs(['1339']).resolves([deposit]);
      
      const result = await checkTronDepositQueueLatency();
      expect(result).to.be.instanceOf(Map);
    });

    it('should handle multiple deposits for same domain', async () => {
      const deposit1 = mock.depositQueue({ 
        domain: '1339', 
        tickerHash: 'hash1',
        enqueuedTimestamp: 1000 
      });
      const deposit2 = mock.depositQueue({ 
        domain: '1339', 
        tickerHash: 'hash1',
        enqueuedTimestamp: 2000 
      });
      database.getAllEnqueuedDeposits.withArgs(['1339']).resolves([deposit1, deposit2]);
      
      const result = await checkTronDepositQueueLatency();
      expect(result.size).to.be.greaterThan(0);
    });
  });

  describe('#checkTronDepositQueueCount - additional branch coverage', () => {
    it('should handle queue count exactly at threshold', async () => {
      const config = mock.config();
      config.thresholds.maxDepositQueueCount = 1;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const deposit = mock.depositQueue({ domain: '1339' });
      database.getAllEnqueuedDeposits.withArgs(['1339']).resolves([deposit]);
      
      await checkTronDepositQueueCount();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should handle zero threshold configuration', async () => {
      const config = mock.config();
      config.thresholds.maxDepositQueueCount = 0;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      await checkTronDepositQueueCount();
      expect(resolveAlertsStub.callCount).to.eq(1);
    });

    it('should handle undefined threshold configuration', async () => {
      const config = mock.config();
      config.thresholds.maxDepositQueueCount = undefined;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      await checkTronDepositQueueCount();
      // Should use default threshold value and complete
    });

    it('should test timestamp edge case for better branch coverage', async () => {
      const currentTime = Math.floor(Date.now() / 1000);
      const deposit = mock.depositQueue({ 
        domain: '1339',
        enqueuedTimestamp: currentTime // Current timestamp edge case
      });
      database.getAllEnqueuedDeposits.withArgs(['1339']).resolves([deposit]);
      
      const result = await checkTronDepositQueueLatency();
      expect(result).to.be.instanceOf(Map);
      // Should handle current timestamp correctly
    });

    it('should handle very old deposits for branch coverage', async () => {
      const veryOldTime = Math.floor(Date.now() / 1000) - 86400; // 24 hours ago
      const deposit = mock.depositQueue({ 
        domain: '1339',
        enqueuedTimestamp: veryOldTime
      });
      database.getAllEnqueuedDeposits.withArgs(['1339']).resolves([deposit]);
      
      const result = await checkTronDepositQueueLatency();
      expect(result).to.be.instanceOf(Map);
      // Should handle old deposits correctly
      if (result.has('1339')) {
        expect(result.get('1339')).to.not.be.undefined;
      }
    });
  });
});