import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { 
  checkTronFillQueueCount, 
  checkTronFillQueueLatency, 
  checkTronIntentQueueCount,
  checkTronIntentQueueLatency 
} from '../../../src/checklist/queue/tron-intent';
import { getContextStub, mock } from '../../globalTestHook';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../../src/mockable';

describe('Tron Queue Checklist - Intent', () => {
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
    
    // Setup default mock data for Tron intents
    const tronIntent = mock.destinationIntent({ destination: '728126428' });
    const contents = new Map();
    contents.set('728126428', [tronIntent]);
    database.getMessageQueueContents.resolves(contents);
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronFillQueueCount', () => {
    it('should count Tron fill queue successfully', async () => {
      const result = await checkTronFillQueueCount();
      
      // Should only include Tron domain
      expect(result).to.deep.equal(new Map([
        ['728126428', 1], // Tron domain with 1 intent
      ]));
    });

    it('should work with no Tron data in database', async () => {
      database.getMessageQueueContents.resolves(new Map());
      
      const result = await checkTronFillQueueCount();
      
      // Should return 0 for Tron domain when no data
      expect(result).to.deep.equal(new Map([
        ['728126428', 0],
      ]));
    });

    it('should filter out non-Tron domains', async () => {
      // Setup mixed domain data
      const evmIntent = mock.destinationIntent({ destination: '1337' });
      const tronIntent = mock.destinationIntent({ destination: '728126428' });
      const solanaIntent = mock.destinationIntent({ destination: '1151111081099710' });
      
      const contents = new Map();
      contents.set('1337', [evmIntent]); // EVM
      contents.set('728126428', [tronIntent]); // Tron
      contents.set('1151111081099710', [solanaIntent]); // Solana
      
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronFillQueueCount();
      
      // Should only include Tron domain
      expect(result).to.deep.equal(new Map([
        ['728126428', 1],
      ]));
      expect(result.has('1337')).to.be.false;
      expect(result.has('1151111081099710')).to.be.false;
    });

    it('should send alert when queue count exceeds threshold', async () => {
      // Setup config with low threshold
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          thresholds: {
            ...mock.config().thresholds,
            maxExecutionQueueCount: 0, // Very low threshold
          },
        },
      });

      await checkTronFillQueueCount();
      
      // Should send alert when count (1) > threshold (0)
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('TronExecutionQueueCountExceedsThreshold');
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
            maxExecutionQueueCount: 10, // High threshold
          },
        },
      });

      await checkTronFillQueueCount();
      
      // Should resolve alerts when count (1) <= threshold (10)
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });
  });

  describe('#checkTronFillQueueLatency', () => {
    it('should work with no pending Tron executions', async () => {
      database.getMessageQueueContents.resolves(new Map());
      
      const result = await checkTronFillQueueLatency();
      
      expect(Object.keys(result.keys()).length).to.eq(0);
    });

    it('should work with pending Tron executions', async () => {
      const oldTronIntent = mock.destinationIntent({ 
        destination: '728126428', 
        timestamp: 1 // Very old timestamp
      });
      const contents = new Map();
      contents.set('728126428', [oldTronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronFillQueueLatency();
      
      // Should send alert for old execution
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('TronExecutionQueueLatencyExceedsThreshold');
    });

    it('should only process Tron domains', async () => {
      const evmIntent = mock.destinationIntent({ destination: '1337', timestamp: 1 });
      const tronIntent = mock.destinationIntent({ destination: '728126428', timestamp: 1 });
      
      const contents = new Map();
      contents.set('1337', [evmIntent]);
      contents.set('728126428', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronFillQueueLatency();
      
      // Should only alert for Tron domain
      expect(sendAlertsStub.calledOnce).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.ids).to.include('728126428');
      expect(alert.ids).to.not.include('1337');
    });
  });

  describe('#checkTronIntentQueueCount', () => {
    beforeEach(() => {
      // Mock origin intents data
      database.getOriginIntentsByStatus.resolves([
        mock.originIntent({ origin: '728126428' }),
        mock.originIntent({ origin: '728126428' }),
      ]);
    });

    it('should count Tron intent queue successfully', async () => {
      const result = await checkTronIntentQueueCount();
      
      // Should only include Tron domain
      expect(result).to.deep.equal(new Map([
        ['728126428', 2], // 2 Tron intents
      ]));
    });

    it('should filter by Tron domains in database query', async () => {
      await checkTronIntentQueueCount();
      
      // Should call database with Tron domains filter
      expect(database.getOriginIntentsByStatus.called).to.be.true;
      const callArgs = database.getOriginIntentsByStatus.firstCall.args;
      expect(callArgs[1]).to.deep.equal(['728126428']); // Tron domains filter
    });

    it('should send alert when intent queue count exceeds threshold', async () => {
      // Setup config with low threshold
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          thresholds: {
            ...mock.config().thresholds,
            maxIntentQueueCount: 1, // Low threshold
          },
        },
      });

      await checkTronIntentQueueCount();
      
      // Should send alert when count (2) > threshold (1)
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('TronIntentQueueCountExceedsThreshold');
    });

    it('should work with no Tron intents', async () => {
      database.getOriginIntentsByStatus.resolves([]);
      
      const result = await checkTronIntentQueueCount();
      
      expect(result).to.deep.equal(new Map([
        ['728126428', 0],
      ]));
    });
  });

  describe('#checkTronIntentQueueLatency', () => {
    beforeEach(() => {
      database.getOriginIntentsByStatus.resolves([
        mock.originIntent({ 
          origin: '728126428',
          timestamp: 1, // Very old timestamp
        }),
      ]);
    });

    it('should check Tron intent queue latency', async () => {
      await checkTronIntentQueueLatency();
      
      // Should send alert for old intent
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('TronIntentQueueLatencyExceedsThreshold');
      expect(alert.ids).to.include('728126428');
    });

    it('should resolve alerts when latency is within threshold', async () => {
      database.getOriginIntentsByStatus.resolves([
        mock.originIntent({ 
          origin: '728126428',
          timestamp: Math.floor(Date.now() / 1000), // Recent timestamp
        }),
      ]);
      
      await checkTronIntentQueueLatency();
      
      // Should resolve alerts when within threshold
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should work with no pending Tron intents', async () => {
      database.getOriginIntentsByStatus.resolves([]);
      
      await checkTronIntentQueueLatency();
      
      // Should not send any alerts
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should only process Tron domains', async () => {
      // Verify that database query filters for Tron domains
      await checkTronIntentQueueLatency();
      
      expect(database.getOriginIntentsByStatus.called).to.be.true;
      const callArgs = database.getOriginIntentsByStatus.firstCall.args;
      expect(callArgs[1]).to.deep.equal(['728126428']); // Should filter by Tron domain
    });
  });

  describe('Tron-specific behavior', () => {
    it('should handle multiple Tron domains if configured', async () => {
      // Mock additional Tron domain
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

      database.getOriginIntentsByStatus.resolves([
        mock.originIntent({ origin: '728126428' }),
        mock.originIntent({ origin: '728126429' }),
      ]);

      const result = await checkTronIntentQueueCount();
      
      // Should include both Tron domains
      expect(result).to.deep.equal(new Map([
        ['728126428', 1],
        ['728126429', 1],
      ]));
    });

    it('should not process chains with network !== "tvm"', async () => {
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

      await checkTronIntentQueueCount();
      
      // Should only query for Tron domain
      const callArgs = database.getOriginIntentsByStatus.firstCall.args;
      expect(callArgs[1]).to.deep.equal(['728126428']);
    });
  });
});