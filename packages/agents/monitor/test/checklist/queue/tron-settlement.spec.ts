import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { 
  checkTronSettlementQueueStatusCount,
  checkTronSettlementQueueLatency
} from '../../../src/checklist/queue/tron-settlement';
import { getContextStub, mock } from '../../globalTestHook';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../../src/mockable';

describe('Tron Queue Checklist - Settlement', () => {
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let database: SinonStubbedInstance<Database>;
  let queuedSettlements: Map<string, any[]>;

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
    
    // Setup default mock data for Tron settlements - getAllQueuedSettlements returns a Map
    queuedSettlements = new Map();
    queuedSettlements.set('728126428', [
      {
        domain: '728126428', // Tron domain
        status: 'PENDING',
        enqueuedTimestamp: Math.floor(Date.now() / 1000) - 3600, // 1 hour ago
        settlementEnqueuedTimestamp: Math.floor(Date.now() / 1000) - 3600,
      },
    ]);
    database.getAllQueuedSettlements.resolves(queuedSettlements);
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronSettlementQueueStatusCount', () => {
    it('should count Tron settlement queue status successfully', async () => {
      const result = await checkTronSettlementQueueStatusCount();
      
      // Should only include Tron domain
      expect(result).to.have.property('728126428');
      expect(result['728126428']).to.equal(1);
    });

    it('should filter out non-Tron domains', async () => {
      const mixedSettlements = new Map();
      mixedSettlements.set('1337', [{ domain: '1337', status: 'PENDING' }]); // EVM
      mixedSettlements.set('728126428', [{ domain: '728126428', status: 'PENDING' }]); // Tron
      mixedSettlements.set('1151111081099710', [{ domain: '1151111081099710', status: 'PENDING' }]); // Solana
      database.getAllQueuedSettlements.resolves(mixedSettlements);
      
      const result = await checkTronSettlementQueueStatusCount();
      
      // Should only include Tron domain
      expect(result).to.have.property('728126428');
      expect(result).to.not.have.property('1337');
      expect(result).to.not.have.property('1151111081099710');
    });

    it('should send alert when queue count exceeds threshold', async () => {
      // Setup config with low threshold
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          thresholds: {
            ...mock.config().thresholds,
            maxSettlementQueueCount: 0, // Very low threshold
          },
        },
      });

      await checkTronSettlementQueueStatusCount();
      
      // Should send alert when count (1) > threshold (0)
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('TronSettlementQueueCountExceedsThreshold');
      expect(alert.ids).to.include('728126428');
    });

    it('should resolve alerts when within threshold', async () => {
      // Setup config with high threshold
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          thresholds: {
            ...mock.config().thresholds,
            maxSettlementQueueCount: 10, // High threshold
          },
        },
      });

      await checkTronSettlementQueueStatusCount();
      
      // Should resolve alerts when count (1) <= threshold (10)
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle empty settlement queue', async () => {
      database.getAllQueuedSettlements.resolves(new Map());
      
      const result = await checkTronSettlementQueueStatusCount();
      
      expect(result).to.have.property('728126428');
      expect(result['728126428']).to.equal(0);
    });
  });

  describe('#checkTronSettlementQueueLatency', () => {
    it('should check Tron settlement queue latency successfully', async () => {
      // Setup old settlement
      const mockSettlements = new Map();
      mockSettlements.set('728126428', [
        {
          domain: '728126428',
          status: 'PENDING',
          enqueuedTimestamp: 1, // Very old timestamp
          settlementEnqueuedTimestamp: 1,
        },
      ]);
      database.getAllQueuedSettlements.resolves(mockSettlements);
      
      await checkTronSettlementQueueLatency();
      
      // Should send alert for old settlement
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('TronSettlementQueueLatencyExceedsThreshold');
      expect(alert.ids).to.include('728126428');
    });

    it('should resolve alerts when latency is within threshold', async () => {
      // Setup recent settlement
      const mockSettlements = new Map();
      mockSettlements.set('728126428', [
        {
          domain: '728126428',
          status: 'PENDING',
          enqueuedTimestamp: Math.floor(Date.now() / 1000), // Current timestamp
          settlementEnqueuedTimestamp: Math.floor(Date.now() / 1000),
        },
      ]);
      database.getAllQueuedSettlements.resolves(mockSettlements);
      
      await checkTronSettlementQueueLatency();
      
      // Should resolve alerts when within threshold
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle no pending Tron settlements', async () => {
      database.getAllQueuedSettlements.resolves(new Map());
      
      await checkTronSettlementQueueLatency();
      
      // Should not send any alerts
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should only process Tron domains', async () => {
      const mixedSettlements = new Map();
      mixedSettlements.set('1337', [{ domain: '1337', status: 'PENDING', enqueuedTimestamp: 1, settlementEnqueuedTimestamp: 1 }]); // EVM
      mixedSettlements.set('728126428', [{ domain: '728126428', status: 'PENDING', enqueuedTimestamp: 1, settlementEnqueuedTimestamp: 1 }]); // Tron
      database.getAllQueuedSettlements.resolves(mixedSettlements);
      
      await checkTronSettlementQueueLatency();
      
      // Should only alert for Tron domain
      expect(sendAlertsStub.calledOnce).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.ids).to.include('728126428');
      expect(alert.ids).to.not.include('1337');
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

      const tronSettlements = new Map();
      tronSettlements.set('728126428', [{ domain: '728126428', status: 'PENDING', enqueuedTimestamp: 1, settlementEnqueuedTimestamp: 1 }]);
      tronSettlements.set('728126429', [{ domain: '728126429', status: 'PENDING', enqueuedTimestamp: 1, settlementEnqueuedTimestamp: 1 }]);
      database.getAllQueuedSettlements.resolves(tronSettlements);
      
      await checkTronSettlementQueueLatency();
      
      // Should alert for both Tron domains
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.ids).to.include('728126428');
      expect(alert.ids).to.include('728126429');
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

      const allDomainsSettlements = new Map();
      allDomainsSettlements.set('1337', [{ domain: '1337', status: 'PENDING' }]);
      allDomainsSettlements.set('728126428', [{ domain: '728126428', status: 'PENDING' }]);
      allDomainsSettlements.set('1151111081099710', [{ domain: '1151111081099710', status: 'PENDING' }]);
      database.getAllQueuedSettlements.resolves(allDomainsSettlements);

      const result = await checkTronSettlementQueueStatusCount();
      
      // Should only include Tron domain
      expect(Object.keys(result)).to.deep.equal(['728126428']);
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

      const result = await checkTronSettlementQueueStatusCount();
      
      // Should return empty result
      expect(Object.keys(result)).to.have.length(0);
    });
  });
});