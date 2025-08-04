import { Logger, expect, HyperlaneStatus, getNtpTimeSeconds } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance, SinonStub } from 'sinon';
import { checkTronMessageStatus, getTronIntentStatus } from '../../src/checklist/tron-message';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import { Database } from '@chimera-monorepo/database';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import * as Mockable from '../../src/mockable';
import * as helpers from '../../src/helpers';

describe('Tron Message Status Monitoring', () => {
  let database: SinonStubbedInstance<Database>;
  let subgraph: SinonStubbedInstance<SubgraphReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let getMessageStatusStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    subgraph = mock.instances.subgraph() as SinonStubbedInstance<SubgraphReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();
    // getMessageStatus is globally stubbed, use that value
    // getMessageStatusStub will be null since we're using global stub  
    getMessageStatusStub = null;
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#getTronIntentStatus', () => {
    beforeEach(() => {
      // Mock subgraph responses for Tron intent tracking
      subgraph.getOriginIntentById.resolves({
        messageId: '0xorigin123',
        id: 'intent123',
        origin: '728126428',
      });
      
      subgraph.getHubIntentById.resolves({
        messageId: '0xhub123',
        id: 'intent123',
        domain: '1337', // Hub domain
      });
      
      subgraph.getDestinationIntentById.resolves({
        messageId: '0xdest123',
        id: 'intent123',
        destination: '1338',
      });
    });

    it('should get Tron intent status successfully', async () => {
      const result = await getTronIntentStatus('728126428', ['1338'], 'intent123');
      
      expect(result).to.deep.equal({
        settlement: {
          messageId: '0xhub123',
          status: HyperlaneStatus.delivered,
        },
        fill: {
          messageId: '0xdest123',
          status: HyperlaneStatus.delivered,
        },
        add: {
          messageId: '0xorigin123',
          status: HyperlaneStatus.delivered,
        },
      });
      
      // Should call subgraph for all relevant intents
      expect(subgraph.getOriginIntentById.calledWith('728126428', 'intent123')).to.be.true;
      expect(subgraph.getHubIntentById.calledWith('1337', 'intent123')).to.be.true;
      expect(subgraph.getDestinationIntentById.calledWith('1338', 'intent123')).to.be.true;
    });

    it('should handle missing message IDs', async () => {
      subgraph.getOriginIntentById.resolves({
        messageId: null, // Missing message ID
        id: 'intent123',
        origin: '728126428',
      });
      
      const result = await getTronIntentStatus('728126428', ['1338'], 'intent123');
      
      expect(result.add).to.deep.equal({
        messageId: '',
        status: 'N/A',
      });
    });

    it('should handle multiple destination domains', async () => {
      subgraph.getDestinationIntentById.onFirstCall().resolves({
        messageId: '0xdest1',
        id: 'intent123',
        destination: '1338',
      });
      subgraph.getDestinationIntentById.onSecondCall().resolves({
        messageId: '0xdest2',
        id: 'intent123',
        destination: '1339',
      });
      
      const result = await getTronIntentStatus('728126428', ['1338', '1339'], 'intent123');
      
      // Should use the first available message ID
      expect(result.fill.messageId).to.equal('0xdest1');
      expect(result.fill.status).to.equal(HyperlaneStatus.delivered);
    });
  });

  describe('#checkTronMessageStatus', () => {
    beforeEach(() => {
      // Mock uncompleted messages from database
      database.getMessagesByStatus.resolves([
        {
          id: '0xmsg1',
          domain: '728126428', // Tron domain
          timestamp: getNtpTimeSeconds() - 3600, // 1 hour old
        },
        {
          id: '0xmsg2',
          domain: '1337', // EVM domain
          timestamp: getNtpTimeSeconds() - 3600,
        },
        {
          id: '0xmsg3',
          domain: '728126428', // Another Tron message
          timestamp: getNtpTimeSeconds() - 7200, // 2 hours old
        },
      ]);
    });

    it('should check Tron message status and filter by domain', async () => {
      await checkTronMessageStatus();
      
      // Should call getMessageStatus only for Tron messages
      expect(getMessageStatusStub.callCount).to.equal(2); // Only 2 Tron messages
      expect(getMessageStatusStub.calledWith('0xmsg1')).to.be.true;
      expect(getMessageStatusStub.calledWith('0xmsg3')).to.be.true;
      expect(getMessageStatusStub.calledWith('0xmsg2')).to.be.false; // EVM message should be filtered out
    });

    it('should alert on delayed Tron messages', async () => {
      // Mock messages that exceed delay threshold
      getMessageStatusStub.resolves({ status: HyperlaneStatus.pending });
      
      // Mock config with short delay threshold
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          thresholds: {
            ...mock.config().thresholds,
            messageMaxDelay: 1800, // 30 minutes
          },
        },
      });

      await checkTronMessageStatus();
      
      // Should send alert for delayed messages
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('HyperlaneMessagesProcessingDelayed');
      expect(alert.ids).to.include('0xmsg1'); // 1 hour old message
      expect(alert.ids).to.include('0xmsg3'); // 2 hour old message
    });

    it('should resolve alerts when all Tron messages are delivered', async () => {
      // All messages are delivered
      getMessageStatusStub.resolves({ status: HyperlaneStatus.delivered });
      
      await checkTronMessageStatus();
      
      // Should resolve alerts when all messages are delivered
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle pagination correctly', async () => {
      // Mock paginated responses
      database.getMessagesByStatus.onFirstCall().resolves([
        { id: '0xmsg1', domain: '728126428', timestamp: getNtpTimeSeconds() - 3600 },
        { id: '0xmsg2', domain: '728126428', timestamp: getNtpTimeSeconds() - 3600 },
        // ... simulate 100 messages for first page
        ...Array(98).fill(null).map((_, i) => ({
          id: `0xmsg${i + 3}`,
          domain: '728126428',
          timestamp: getNtpTimeSeconds() - 3600,
        })),
      ]);
      
      database.getMessagesByStatus.onSecondCall().resolves([
        { id: '0xmsg101', domain: '728126428', timestamp: getNtpTimeSeconds() - 3600 },
        // Only 1 message on second page
      ]);

      await checkTronMessageStatus();
      
      // Should call database twice for pagination
      expect(database.getMessagesByStatus.calledTwice).to.be.true;
      expect(database.getMessagesByStatus.firstCall.args[1]).to.equal(0); // First offset
      expect(database.getMessagesByStatus.secondCall.args[1]).to.equal(100); // Second offset
    });

    it('should only process chains with network: "tvm"', async () => {
      database.getMessagesByStatus.resolves([
        { id: '0xmsg1', domain: '1337', timestamp: getNtpTimeSeconds() - 3600 }, // EVM
        { id: '0xmsg2', domain: '728126428', timestamp: getNtpTimeSeconds() - 3600 }, // Tron
        { id: '0xmsg3', domain: '1151111081099710', timestamp: getNtpTimeSeconds() - 3600 }, // Solana
      ]);
      
      await checkTronMessageStatus();
      
      // Should only process Tron message
      expect(getMessageStatusStub.calledOnce).to.be.true;
      expect(getMessageStatusStub.calledWith('0xmsg2')).to.be.true;
    });

    it('should not alert when shouldAlert is false', async () => {
      getMessageStatusStub.resolves({ status: HyperlaneStatus.pending });
      
      await checkTronMessageStatus(false);
      
      // Should not send alerts when disabled
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle empty message list', async () => {
      database.getMessagesByStatus.resolves([]);
      
      await checkTronMessageStatus();
      
      // Should resolve alerts when no messages
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle mixed message statuses', async () => {
      database.getMessagesByStatus.resolves([
        { id: '0xmsg1', domain: '728126428', timestamp: getNtpTimeSeconds() - 3600 },
        { id: '0xmsg2', domain: '728126428', timestamp: getNtpTimeSeconds() - 3600 },
        { id: '0xmsg3', domain: '728126428', timestamp: getNtpTimeSeconds() - 3600 },
      ]);
      
      // Mock different statuses for different messages
      getMessageStatusStub.onFirstCall().resolves({ status: HyperlaneStatus.delivered });
      getMessageStatusStub.onSecondCall().resolves({ status: HyperlaneStatus.pending });
      getMessageStatusStub.onThirdCall().resolves({ status: HyperlaneStatus.relayable });
      
      await checkTronMessageStatus();
      
      // Should only alert on non-delivered messages that exceed threshold
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.ids).to.include('0xmsg2'); // pending
      expect(alert.ids).to.include('0xmsg3'); // relayable
      expect(alert.ids).to.not.include('0xmsg1'); // delivered
    });
  });
});