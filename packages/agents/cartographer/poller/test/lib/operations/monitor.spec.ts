import { SinonStub, stub } from 'sinon';

import {
  updateMessages,
  updateMessageStatus,
  updateQueues,
  updateProtocolUpdateLogs,
  updateHubSpokeMeta,
} from '../../../src/lib/operations';
import {
  HubMeta,
  Message,
  ProtocolUpdateLog,
  SpokeMeta,
  TIntentStatus,
  TMessageType,
  TSettlementMessageType,
  expect,
  HyperlaneStatus,
} from '@chimera-monorepo/utils';
import { mockAppContext } from '../../globalTestHook';
import * as mockable from '../../../src/mockable';
import { createHubMessages, createMessages, createQueues } from '@chimera-monorepo/database/test/mock';

describe('Monitor operations', () => {
  describe('#updateMessages', () => {
    it('should work', async () => {
      const domains = Object.keys(mockAppContext.config.chains).concat(mockAppContext.config.hub.domain);
      const spokeMessages = createMessages(5);
      const hubMessages = createHubMessages(5);
      (mockAppContext.adapters.subgraph.getSpokeMessages as SinonStub).resolves(spokeMessages);
      (mockAppContext.adapters.subgraph.getHubMessages as SinonStub).resolves(hubMessages);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateMessages();

      expect(mockAppContext.adapters.database.saveMessages as SinonStub).callCount(domains.length);

      const hubIntentUpdates = hubMessages
        .filter((m) => m.type === TMessageType.Settlement)
        .flatMap((m) => {
          return m.intentIds.map((id) => ({
            id,
            messageId: m.id,
            settlementDomain: m.settlementDomain,
            status:
              m.settlementType === TSettlementMessageType.Settled
                ? TIntentStatus.Dispatched
                : TIntentStatus.DispatchedUnsupported,
          }));
        });
      expect(mockAppContext.adapters.database.saveMessages as SinonStub).to.be.calledWith(
        hubMessages as Message[],
        [],
        [],
        hubIntentUpdates,
      );
      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(domains.length);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(domains.length);
    });

    it('saves messages with updated status', async () => {
      const getHyperlaneMsgDelivered = stub(mockable, 'getHyperlaneMsgDelivered');
      getHyperlaneMsgDelivered.resolves(true);

      const hubMessages = createHubMessages(5);
      const spokeMessages = createMessages(5);
      (mockAppContext.adapters.subgraph.getHubMessages as SinonStub).resolves(hubMessages);
      (mockAppContext.adapters.subgraph.getSpokeMessages as SinonStub).resolves(spokeMessages);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateMessages();

      const resolvedHubMessages = createHubMessages(5, Array(5).fill({ status: HyperlaneStatus.delivered }));
      expect(mockAppContext.adapters.database.saveMessages as SinonStub).calledWith(resolvedHubMessages);
    });

    it('should not save checkpoint if empty', async () => {
      const domains = Object.keys(mockAppContext.config.chains).concat(mockAppContext.config.hub.domain);
      const hubMessages = createHubMessages(5);
      (mockAppContext.adapters.subgraph.getSpokeMessages as SinonStub).resolves([]);
      (mockAppContext.adapters.subgraph.getHubMessages as SinonStub).resolves(hubMessages);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateMessages();

      expect(mockAppContext.adapters.database.saveMessages as SinonStub).callCount(domains.length);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(domains.length);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(1);
    });
  });

  describe('#updateQueues', () => {
    it('should work', async () => {
      const depositQueues = createQueues(5);
      const settlementQueues = createQueues(5);
      const spokeQueues = createQueues(5);
      (mockAppContext.adapters.subgraph.getDepositQueues as SinonStub).resolves(depositQueues);
      (mockAppContext.adapters.subgraph.getSettlementQueues as SinonStub).resolves(settlementQueues);
      (mockAppContext.adapters.subgraph.getSpokeQueues as SinonStub).resolves(spokeQueues);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateQueues();

      expect(mockAppContext.adapters.database.saveQueues as SinonStub).callCount(1);
    });
  });

  describe('#updateMessageStatus', () => {
    let getHyperlaneMsgDelivered: SinonStub;

    beforeEach(() => {
      getHyperlaneMsgDelivered = stub(mockable, 'getHyperlaneMsgDelivered');
      getHyperlaneMsgDelivered.resolves(true);
    });

    it('should work', async () => {
      const domains = Object.keys(mockAppContext.config.chains).concat(mockAppContext.config.hub.domain);
      // should work for both hub and spoke destination domain
      const messages = createMessages(5, [{ destinationDomain: mockAppContext.config.hub.domain }]);
      (mockAppContext.adapters.database.getMessagesByStatus as SinonStub).resolves(messages);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      expect(await updateMessageStatus()).to.not.throws;

      expect(mockAppContext.adapters.database.updateMessageStatus as SinonStub).callCount(5);
    })
  })

  describe('#updateProtocolUpdateLogs', () => {
    it('saves hub and spoke meta updates', async () => {
      const spokeUpdate: ProtocolUpdateLog = {
        id: 'spoke-log-1',
        domain: '1337',
        chainId: '1337',
        event: 'GATEWAY_UPDATED',
        key: 'gateway',
        updated: '0x1234',
        transactionHash: '0xabc',
        timestamp: 1,
        blockNumber: 100,
        txOrigin: '0x1',
        txNonce: 1,
      };
      const hubUpdate: ProtocolUpdateLog = {
        id: 'hub-log-1',
        domain: mockAppContext.config.hub.domain,
        chainId: mockAppContext.config.hub.domain,
        event: 'PAUSED',
        key: 'paused',
        updated: '1',
        transactionHash: '0xdef',
        timestamp: 2,
        blockNumber: 200,
        txOrigin: '0x2',
        txNonce: 2,
      };
      const getSpokeMetaUpdates = mockAppContext.adapters.subgraph.getSpokeMetaUpdates as SinonStub;
      getSpokeMetaUpdates.onCall(0).resolves([spokeUpdate]);
      getSpokeMetaUpdates.onCall(1).resolves([]);
      (mockAppContext.adapters.subgraph.getHubMetaUpdates as SinonStub).resolves([hubUpdate]);

      await updateProtocolUpdateLogs();

      const saveProtocolLogs = mockAppContext.adapters.database.saveProtocolUpdateLogs as SinonStub;
      expect(saveProtocolLogs.callCount).to.equal(2);

      expect(saveProtocolLogs.getCall(0).args[0]).to.deep.equal([spokeUpdate]);
      expect(saveProtocolLogs.getCall(1).args[0]).to.deep.equal([hubUpdate]);

      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).calledWith(
        'spoke_meta_log_block_1337',
        spokeUpdate.blockNumber,
      );
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).calledWith(
        'hub_meta_log_block',
        hubUpdate.blockNumber,
      );
    });

    it('does not call saveProtocolUpdateLogs when no domains have updates', async () => {
      const getSpokeMetaUpdates = mockAppContext.adapters.subgraph.getSpokeMetaUpdates as SinonStub;
      getSpokeMetaUpdates.resolves([]);
      (mockAppContext.adapters.subgraph.getHubMetaUpdates as SinonStub).resolves([]);

      await updateProtocolUpdateLogs();

      expect(mockAppContext.adapters.database.saveProtocolUpdateLogs as SinonStub).to.not.have.been.called;
    });

    it('updates checkpoint to max block when multiple updates in one domain', async () => {
      const updates: ProtocolUpdateLog[] = [
        {
          id: 'log-1',
          domain: '1337',
          chainId: '1337',
          event: 'GATEWAY_UPDATED',
          key: 'gateway',
          updated: '0xa',
          transactionHash: '0x1',
          timestamp: 1,
          blockNumber: 100,
          txOrigin: '0x1',
          txNonce: 1,
        },
        {
          id: 'log-2',
          domain: '1337',
          chainId: '1337',
          event: 'PAUSED',
          key: 'paused',
          updated: '1',
          transactionHash: '0x2',
          timestamp: 2,
          blockNumber: 200,
          txOrigin: '0x2',
          txNonce: 2,
        },
      ];
      (mockAppContext.adapters.subgraph.getSpokeMetaUpdates as SinonStub).onCall(0).resolves(updates);
      (mockAppContext.adapters.subgraph.getSpokeMetaUpdates as SinonStub).onCall(1).resolves([]);
      (mockAppContext.adapters.subgraph.getHubMetaUpdates as SinonStub).resolves([]);

      await updateProtocolUpdateLogs();

      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).to.have.been.calledWith(
        'spoke_meta_log_block_1337',
        200,
      );
    });
  });

  describe('#updateHubSpokeMeta', () => {
    it('saves hub meta when present', async () => {
      const hubMeta: HubMeta = {
        id: '1339',
        domain: mockAppContext.config.hub.domain,
        acceptanceDelay: '1',
        gateway: '0xgateway',
        watchtower: '0xwatchtower',
        manager: '0xmanager',
        settler: '0xsettler',
        proposedOwnershipTimestamp: '0',
        mailbox: '0xmailbox',
        securityModule: '0xsecurity',
        minSolverSupportedDomains: '1',
        expiryTimeBuffer: '0',
        discountPerEpoch: '0',
        epochLength: '1',
        supportedDomains: [],
        chainGateways: [],
      };
      (mockAppContext.adapters.subgraph.getHubMeta as SinonStub).resolves(hubMeta);
      (mockAppContext.adapters.subgraph.getSpokeMeta as SinonStub).resolves(undefined);

      await updateHubSpokeMeta();

      expect(mockAppContext.adapters.database.saveHubMeta as SinonStub).to.have.been.calledOnceWith([hubMeta]);
      expect(mockAppContext.adapters.database.saveSpokeMeta as SinonStub).to.not.have.been.called;
    });

    it('saves spoke meta when present', async () => {
      const spokeMeta: SpokeMeta = {
        id: '1337',
        domain: '1337',
        messageReceiver: '0xreceiver',
        watchtower: '0xwatchtower',
        messageGasLimit: '100000',
        feeAdapter: '0xfeeAdapter',
        feeAdapterRecipient: '0xrecipient',
        fillSigner: '0xfillSigner',
        feeSigner: '0xfeeSigner',
        mailbox: '0xmailbox',
        securityModule: '0xsecurity',
        moduleForStrategies: [],
      };
      (mockAppContext.adapters.subgraph.getHubMeta as SinonStub).resolves(undefined);
      (mockAppContext.adapters.subgraph.getSpokeMeta as SinonStub)
        .onFirstCall()
        .resolves(spokeMeta)
        .onSecondCall()
        .resolves(undefined);

      await updateHubSpokeMeta();

      expect(mockAppContext.adapters.database.saveHubMeta as SinonStub).to.not.have.been.called;
      expect(mockAppContext.adapters.database.saveSpokeMeta as SinonStub).to.have.been.calledOnce;
      expect((mockAppContext.adapters.database.saveSpokeMeta as SinonStub).firstCall.args[0]).to.deep.equal([
        spokeMeta,
      ]);
    });

    it('does not save when no meta found', async () => {
      (mockAppContext.adapters.subgraph.getHubMeta as SinonStub).resolves(undefined);
      (mockAppContext.adapters.subgraph.getSpokeMeta as SinonStub).resolves(undefined);

      await updateHubSpokeMeta();

      expect(mockAppContext.adapters.database.saveHubMeta as SinonStub).to.not.have.been.called;
      expect(mockAppContext.adapters.database.saveSpokeMeta as SinonStub).to.not.have.been.called;
    });

    it('saves both hub and spoke meta when both present', async () => {
      const hubMeta: HubMeta = {
        id: '1339',
        domain: mockAppContext.config.hub.domain,
        gateway: '0xgateway',
      };
      const spokeMeta: SpokeMeta = {
        id: '1337',
        domain: '1337',
        messageReceiver: '0xreceiver',
      };
      (mockAppContext.adapters.subgraph.getHubMeta as SinonStub).resolves(hubMeta);
      (mockAppContext.adapters.subgraph.getSpokeMeta as SinonStub)
        .onFirstCall()
        .resolves(spokeMeta)
        .onSecondCall()
        .resolves(undefined);

      await updateHubSpokeMeta();

      expect(mockAppContext.adapters.database.saveHubMeta as SinonStub).to.have.been.calledOnceWith([hubMeta]);
      expect(mockAppContext.adapters.database.saveSpokeMeta as SinonStub).to.have.been.calledOnce;
      expect((mockAppContext.adapters.database.saveSpokeMeta as SinonStub).firstCall.args[0]).to.deep.equal([
        spokeMeta,
      ]);
    });
  });
});
