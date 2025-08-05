import { Logger, expect, QueueType } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { 
  checkTronFillQueueCount, 
  checkTronFillQueueLatency, 
  checkTronIntentQueueCount,
  checkTronIntentQueueLatency 
} from '../../../src/checklist/queue/tron-intent';
import { getContextStub, mock } from '../../globalTestHook';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../../src/mockable';

describe('Tron Intent Queue Checklist', () => {
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

  describe('#checkTronFillQueueCount', () => {
    it('should work with Tron fill intents', async () => {
      const tronIntent = mock.destinationIntent({ destination: '1339' }); // Tron domain
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronFillQueueCount();
      expect(result.get('1339')).to.eq(1);
    });

    it('should work with no Tron intents in db', async () => {
      database.getMessageQueueContents.resolves(new Map());
      const result = await checkTronFillQueueCount();
      expect(result.get('1339')).to.eq(0);
    });

    it('should filter out non-Tron domains', async () => {
      const evmIntent = mock.destinationIntent({ destination: '1337' }); // EVM domain
      const tronIntent = mock.destinationIntent({ destination: '1339' }); // Tron domain
      const contents = new Map();
      contents.set('1337', [evmIntent]);
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronFillQueueCount();
      // Should only include Tron domain count
      expect(result.get('1339')).to.eq(1);
      expect(result.has('1337')).to.be.false;
    });

    it('should send alert when execution queue count exceeds threshold', async () => {
      const config = mock.config();
      config.thresholds.maxExecutionQueueCount = 0;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const tronIntent = mock.destinationIntent({ destination: '1339' });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronFillQueueCount();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should resolve alerts when execution queue count within threshold', async () => {
      const config = mock.config();
      config.thresholds.maxExecutionQueueCount = 10;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const tronIntent = mock.destinationIntent({ destination: '1339' });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronFillQueueCount();
      expect(resolveAlertsStub.callCount).to.eq(1);
    });
  });

  describe('#checkTronFillQueueLatency', () => {
    it('should work with no pending Tron executions', async () => {
      database.getMessageQueueContents.resolves(new Map());
      const result = await checkTronFillQueueLatency();
      expect(result).to.be.instanceOf(Map);
      expect(result.size).to.eq(0);
    });

    it('should work with pending Tron executions', async () => {
      const oldTimestamp = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      const tronIntent = mock.destinationIntent({ 
        destination: '1339', 
        timestamp: oldTimestamp 
      });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronFillQueueLatency();
      expect(result.get('1339')).to.eq(oldTimestamp);
    });

    it('should send alert when execution latency exceeds threshold', async () => {
      const config = mock.config();
      config.thresholds.maxExecutionQueueLatency = 1800; // 30 minutes
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const oldTimestamp = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      const tronIntent = mock.destinationIntent({ 
        destination: '1339', 
        timestamp: oldTimestamp 
      });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronFillQueueLatency();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should resolve alerts when execution latency within threshold', async () => {
      const config = mock.config();
      config.thresholds.maxExecutionQueueLatency = 7200; // 2 hours
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const recentTimestamp = Math.floor(Date.now() / 1000) - 1800; // 30 minutes ago
      const tronIntent = mock.destinationIntent({ 
        destination: '1339', 
        timestamp: recentTimestamp 
      });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronFillQueueLatency();
      expect(resolveAlertsStub.callCount).to.eq(1);
    });

    it('should track oldest intent for latency calculation', async () => {
      const domain = '1339';
      const oldTimestamp = Math.floor(Date.now() / 1000) - 7200; // 2 hours ago
      const newTimestamp = Math.floor(Date.now() / 1000) - 1800; // 30 minutes ago
      
      const oldIntent = mock.destinationIntent({ destination: domain, timestamp: oldTimestamp });
      const newIntent = mock.destinationIntent({ destination: domain, timestamp: newTimestamp });
      const contents = new Map();
      contents.set(domain, [newIntent, oldIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronFillQueueLatency();
      // Should use the older timestamp
      expect(result.get(domain)).to.eq(oldTimestamp);
    });
  });

  describe('#checkTronIntentQueueCount', () => {
    it('should work with Tron intent queue', async () => {
      const tronIntent = mock.destinationIntent({ destination: '1339' });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronIntentQueueCount();
      expect(result.get('1339')).to.eq(1);
    });

    it('should work with no Tron intents in queue', async () => {
      database.getMessageQueueContents.resolves(new Map());
      const result = await checkTronIntentQueueCount();
      expect(result.get('1339')).to.eq(0);
    });

    it('should filter out non-Tron domains for intent queue', async () => {
      const evmIntent = mock.destinationIntent({ destination: '1337' });
      const tronIntent = mock.destinationIntent({ destination: '1339' });
      const contents = new Map();
      contents.set('1337', [evmIntent]);
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronIntentQueueCount();
      expect(result.get('1339')).to.eq(1);
      expect(result.has('1337')).to.be.false;
    });

    it('should send alert when intent queue count exceeds threshold', async () => {
      const config = mock.config();
      config.thresholds.maxIntentQueueCount = 0;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const tronIntent = mock.destinationIntent({ destination: '1339' });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronIntentQueueCount();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should resolve alerts when intent queue count within threshold', async () => {
      const config = mock.config();
      config.thresholds.maxIntentQueueCount = 10;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const tronIntent = mock.destinationIntent({ destination: '1339' });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronIntentQueueCount();
      expect(resolveAlertsStub.callCount).to.eq(1);
    });

    it('should count multiple intents in same domain', async () => {
      const intent1 = mock.destinationIntent({ destination: '1339' });
      const intent2 = mock.destinationIntent({ destination: '1339' });
      const contents = new Map();
      contents.set('1339', [intent1, intent2]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronIntentQueueCount();
      expect(result.get('1339')).to.eq(2);
    });
  });

  describe('#checkTronIntentQueueLatency', () => {
    it('should work with no pending Tron intents', async () => {
      database.getMessageQueueContents.resolves(new Map());
      const result = await checkTronIntentQueueLatency();
      expect(result).to.be.instanceOf(Map);
      expect(result.size).to.eq(0);
    });

    it('should work with pending Tron intents', async () => {
      const oldTimestamp = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      const tronIntent = mock.destinationIntent({ 
        destination: '1339', 
        timestamp: oldTimestamp 
      });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronIntentQueueLatency();
      expect(result.get('1339')).to.eq(oldTimestamp);
    });

    it('should send alert when intent latency exceeds threshold', async () => {
      const config = mock.config();
      config.thresholds.maxIntentQueueLatency = 1800; // 30 minutes
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const oldTimestamp = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      const tronIntent = mock.destinationIntent({ 
        destination: '1339', 
        timestamp: oldTimestamp 
      });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronIntentQueueLatency();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should resolve alerts when intent latency within threshold', async () => {
      const config = mock.config();
      config.thresholds.maxIntentQueueLatency = 7200; // 2 hours
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const recentTimestamp = Math.floor(Date.now() / 1000) - 1800; // 30 minutes ago
      const tronIntent = mock.destinationIntent({ 
        destination: '1339', 
        timestamp: recentTimestamp 
      });
      const contents = new Map();
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      await checkTronIntentQueueLatency();
      expect(resolveAlertsStub.callCount).to.eq(1);
    });

    it('should track oldest intent for intent latency calculation', async () => {
      const domain = '1339';
      const oldTimestamp = Math.floor(Date.now() / 1000) - 7200; // 2 hours ago
      const newTimestamp = Math.floor(Date.now() / 1000) - 1800; // 30 minutes ago
      
      const oldIntent = mock.destinationIntent({ destination: domain, timestamp: oldTimestamp });
      const newIntent = mock.destinationIntent({ destination: domain, timestamp: newTimestamp });
      const contents = new Map();
      contents.set(domain, [newIntent, oldIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronIntentQueueLatency();
      // Should use the older timestamp
      expect(result.get(domain)).to.eq(oldTimestamp);
    });

    it('should filter out non-Tron domains for intent latency', async () => {
      const evmIntent = mock.destinationIntent({ destination: '1337', timestamp: 123 });
      const tronIntent = mock.destinationIntent({ destination: '1339', timestamp: 456 });
      const contents = new Map();
      contents.set('1337', [evmIntent]);
      contents.set('1339', [tronIntent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronIntentQueueLatency();
      expect(result.get('1339')).to.eq(456);
      expect(result.has('1337')).to.be.false;
    });

    it('should handle intent without enqueuedTimestamp', async () => {
      const intent = mock.destinationIntent({ 
        destination: '1339',
        enqueuedTimestamp: undefined // Missing timestamp
      });
      const contents = new Map();
      contents.set('1339', [intent]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronIntentQueueLatency();
      expect(result).to.be.instanceOf(Map);
    });

    it('should handle multiple intents with same key', async () => {
      const intent1 = mock.destinationIntent({ 
        destination: '1339', 
        enqueuedTimestamp: 1000 
      });
      const intent2 = mock.destinationIntent({ 
        destination: '1339', 
        enqueuedTimestamp: 2000 
      });
      const contents = new Map();
      contents.set('1339', [intent1, intent2]);
      database.getMessageQueueContents.resolves(contents);
      
      const result = await checkTronIntentQueueLatency();
      expect(result.size).to.be.greaterThan(0);
    });
  });

  describe('Additional branch coverage tests', () => {
    it('should handle zero threshold for fill queue count', async () => {
      const config = mock.config();
      config.thresholds.maxFillQueueCount = 0;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      await checkTronFillQueueCount();
      expect(resolveAlertsStub.callCount).to.eq(1);
    });

    it('should handle undefined threshold for intent queue count', async () => {
      const config = mock.config();
      config.thresholds.maxIntentQueueCount = undefined;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      await checkTronIntentQueueCount();
      // Should use default threshold value and complete
    });

    it('should handle edge case with no execution data available', async () => {
      // Just check that the function completes without error
      const result = await checkTronFillQueueLatency();
      expect(result).to.be.instanceOf(Map);
    });

    it('should handle very large threshold values', async () => {
      const config = mock.config();
      config.thresholds.maxFillQueueCount = 999999;
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      await checkTronFillQueueCount();
      expect(resolveAlertsStub.called).to.be.true;
    });


  });
});