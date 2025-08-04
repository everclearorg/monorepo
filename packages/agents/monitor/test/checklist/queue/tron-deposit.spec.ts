import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { 
  checkTronDepositQueueCount,
  checkTronDepositQueueLatency
} from '../../../src/checklist/queue/tron-deposit';
import { getContextStub, mock } from '../../globalTestHook';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../../src/mockable';

describe('Tron Queue Checklist - Deposit', () => {
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
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    
    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();
    
    // Setup default mock data for Tron deposits
    database.getAllEnqueuedDeposits.resolves([
      mock.depositQueue({
        domain: '728126428', // Tron domain
        epoch: 100,
        tickerHash: '0xbbbbfcba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4',
        enqueuedTimestamp: Math.floor(Date.now() / 1000) - 3600, // 1 hour ago
      }),
    ]);
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronDepositQueueCount', () => {
    it('should count Tron deposit queue successfully', async () => {
      const result = await checkTronDepositQueueCount();
      
      // Should return a Map with one entry for Tron
      expect(result).to.be.instanceOf(Map);
      expect(result.size).to.equal(1);
      const keys = Array.from(result.keys());
      expect(keys[0]).to.include('tron-100-728126428');
      expect(result.get(keys[0])).to.equal(1);
    });

    it('should filter out non-Tron domains', async () => {
      database.getAllEnqueuedDeposits.resolves([
        mock.depositQueue({ domain: '1337', epoch: 100 }), // EVM
        mock.depositQueue({ domain: '728126428', epoch: 100 }), // Tron
        mock.depositQueue({ domain: '1151111081099710', epoch: 100 }), // Solana
      ]);
      
      const result = await checkTronDepositQueueCount();
      
      // Should only include Tron domain
      expect(result.size).to.equal(1);
      const keys = Array.from(result.keys());
      expect(keys[0]).to.include('tron-100-728126428');
    });

    it('should group by epoch, domain, and ticker hash', async () => {
      database.getAllEnqueuedDeposits.resolves([
        mock.depositQueue({ 
          domain: '728126428', 
          epoch: 100, 
          tickerHash: '0xaaa',
        }),
        mock.depositQueue({ 
          domain: '728126428', 
          epoch: 100, 
          tickerHash: '0xaaa',
        }),
        mock.depositQueue({ 
          domain: '728126428', 
          epoch: 101, 
          tickerHash: '0xaaa',
        }),
        mock.depositQueue({ 
          domain: '728126428', 
          epoch: 100, 
          tickerHash: '0xbbb',
        }),
      ]);
      
      const result = await checkTronDepositQueueCount();
      
      // Should have 3 different queue groups
      expect(result.size).to.equal(3);
      
      // Check grouping keys and counts
      expect(result.has('tron-100-728126428-0xaaa')).to.be.true;
      expect(result.has('tron-101-728126428-0xaaa')).to.be.true;
      expect(result.has('tron-100-728126428-0xbbb')).to.be.true;
      
      // Check counts
      expect(result.get('tron-100-728126428-0xaaa')).to.equal(2);
    });

    it('should send alert when queue count exceeds threshold', async () => {
      // Setup config with low threshold
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          thresholds: {
            ...mock.config().thresholds,
            maxDepositQueueCount: 0, // Very low threshold
          },
        },
      });

      await checkTronDepositQueueCount();
      
      // Should send alert when count (1) > threshold (0)
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('TronDepositQueueCountExceedsThreshold');
    });

    it('should resolve alerts when within threshold', async () => {
      // Setup config with high threshold
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          thresholds: {
            ...mock.config().thresholds,
            maxDepositQueueCount: 10, // High threshold
          },
        },
      });

      await checkTronDepositQueueCount();
      
      // Should resolve alerts when count (1) <= threshold (10)
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle empty deposit queue', async () => {
      database.getAllEnqueuedDeposits.resolves([]);
      
      const result = await checkTronDepositQueueCount();
      
      expect(result.size).to.equal(0);
    });
  });

  describe('#checkTronDepositQueueLatency', () => {
    it('should check Tron deposit queue latency successfully', async () => {
      // Setup old deposit
      database.getAllEnqueuedDeposits.resolves([
        mock.depositQueue({
          domain: '728126428',
          tickerHash: '0xaaa',
          enqueuedTimestamp: 1, // Very old timestamp
        }),
      ]);
      
      await checkTronDepositQueueLatency();
      
      // Should send alert for old deposit
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('TronDepositQueueLatencyExceedsThreshold');
    });

    it('should resolve alerts when latency is within threshold', async () => {
      // Setup recent deposit
      database.getAllEnqueuedDeposits.resolves([
        mock.depositQueue({
          domain: '728126428',
          enqueuedTimestamp: Math.floor(Date.now() / 1000), // Current timestamp
        }),
      ]);
      
      await checkTronDepositQueueLatency();
      
      // Should resolve alerts when within threshold
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle no pending Tron deposits', async () => {
      database.getAllEnqueuedDeposits.resolves([]);
      
      await checkTronDepositQueueLatency();
      
      // Should not send any alerts
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should only process Tron domains', async () => {
      database.getAllEnqueuedDeposits.resolves([
        mock.depositQueue({ domain: '1337', enqueuedTimestamp: 1 }), // EVM
        mock.depositQueue({ domain: '728126428', enqueuedTimestamp: 1 }), // Tron
      ]);
      
      await checkTronDepositQueueLatency();
      
      // Should only alert for Tron domain
      expect(sendAlertsStub.calledOnce).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.reason).to.include('tron-728126428');
      expect(alert.reason).to.not.include('1337');
    });

    it('should group deposits by domain and ticker hash', async () => {
      database.getAllEnqueuedDeposits.resolves([
        mock.depositQueue({ 
          domain: '728126428', 
          tickerHash: '0xaaa',
          enqueuedTimestamp: 1 
        }),
        mock.depositQueue({ 
          domain: '728126428', 
          tickerHash: '0xaaa',
          enqueuedTimestamp: 2 
        }),
        mock.depositQueue({ 
          domain: '728126428', 
          tickerHash: '0xbbb',
          enqueuedTimestamp: 1 
        }),
      ]);
      
      await checkTronDepositQueueLatency();
      
      // Should alert for both ticker groups
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.reason).to.include('tron-728126428-0xaaa');
      expect(alert.reason).to.include('tron-728126428-0xbbb');
    });

    it('should handle multiple Tron domains', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': { network: 'tvm' }, // Tron mainnet
            '728126429': { network: 'tvm' }, // Hypothetical Tron testnet
          },
        },
      });

      database.getAllEnqueuedDeposits.resolves([
        mock.depositQueue({ domain: '728126428', enqueuedTimestamp: 1 }),
        mock.depositQueue({ domain: '728126429', enqueuedTimestamp: 1 }),
      ]);
      
      await checkTronDepositQueueLatency();
      
      // Should alert for both Tron domains
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.reason).to.include('tron-728126428');
      expect(alert.reason).to.include('tron-728126429');
    });
  });

  describe('Tron-specific behavior', () => {
    it('should only process chains with network: "tvm"', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': { network: 'evm' },
            '728126428': { network: 'tvm' },
            '1151111081099710': { network: 'svm' },
          },
        },
      });

      database.getAllEnqueuedDeposits.resolves([
        mock.depositQueue({ domain: '1337' }),
        mock.depositQueue({ domain: '728126428' }),
        mock.depositQueue({ domain: '1151111081099710' }),
      ]);

      const result = await checkTronDepositQueueCount();
      
      // Should only include Tron domain
      expect(result.size).to.equal(1);
      const firstKey = Array.from(result.keys())[0];
      expect(firstKey).to.include('728126428');
    });

    it('should handle no Tron chains configured', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': { network: 'evm' }, // Only EVM chains
          },
        },
      });

      const result = await checkTronDepositQueueCount();
      
      // Should return empty result
      expect(result.size).to.equal(0);
    });

    it('should use "tron-" prefix in queue keys', async () => {
      const result = await checkTronDepositQueueCount();
      
      const firstKey = Array.from(result.keys())[0];
      expect(firstKey).to.match(/^tron-/);
    });
  });
});