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
  HubTokenUpdateLog,
  HubAssetUpdateLog,
  Message,
  ProtocolUpdateLog,
  SpokeMeta,
  TIntentStatus,
  TMessageType,
  TSettlementMessageType,
  expect,
  HyperlaneStatus,
  SOLANA_CHAINID,
  mkBytes32,
} from '@chimera-monorepo/utils';
import { mockAppContext } from '../../globalTestHook';
import { mockable as coreMockable } from '@chimera-monorepo/cartographer-core';
import { createHubMessages, createMessages, createQueues } from '@chimera-monorepo/database/test/mock';

describe('Monitor operations', () => {
  describe('#updateMessages', () => {
    it('should work', async () => {
      const getHyperlaneMsgDelivered = stub(coreMockable, 'getHyperlaneMsgDelivered');
      getHyperlaneMsgDelivered.resolves(false);

      const domains = Object.keys(mockAppContext.config.chains).filter((d) => mockAppContext.config.chains[d].network === 'evm').concat(mockAppContext.config.hub.domain);
      const spokeMessages = createMessages(5);
      const hubMessages = createHubMessages(5);
      (mockAppContext.adapters.subgraph.getSpokeMessagesWithCheckpoints as SinonStub).resolves([spokeMessages, { goldsky: 1 }]);
      (mockAppContext.adapters.subgraph.getHubMessagesWithCheckpoints as SinonStub).resolves([hubMessages, { goldsky: 1 }]);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateMessages(mockAppContext);

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
      // loadReaderCheckpoints: 2 calls per domain (legacy + goldsky)
      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(domains.length * 2);
      expect((mockAppContext.adapters.database.saveCheckPoint as SinonStub).called).to.be.true;
    });

    it('saves messages with updated status', async () => {
      stub(coreMockable, 'getHyperlaneMsgDelivered').resolves(true);
      const hubMessages = createHubMessages(5);
      const spokeMessages = createMessages(5);
      (mockAppContext.adapters.subgraph.getHubMessagesWithCheckpoints as SinonStub).resolves([hubMessages, { goldsky: 1 }]);
      (mockAppContext.adapters.subgraph.getSpokeMessagesWithCheckpoints as SinonStub).resolves([spokeMessages, { goldsky: 1 }]);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateMessages(mockAppContext);

      const resolvedHubMessages = createHubMessages(5, Array(5).fill({ status: HyperlaneStatus.delivered }));
      expect(mockAppContext.adapters.database.saveMessages as SinonStub).calledWith(resolvedHubMessages);
    });

    it('does not call getHyperlaneMsgDelivered for hub messages with destinationDomain Solana', async () => {
      const getHyperlaneMsgDeliveredStub = stub(coreMockable, 'getHyperlaneMsgDelivered').resolves(false);
      // 2 to Solana (skip contract read), 2 to EVM (call getMessageStatus)
      const hubMessages = createHubMessages(4, [
        { destinationDomain: SOLANA_CHAINID },
        { destinationDomain: SOLANA_CHAINID },
        { destinationDomain: '1337' },
        { destinationDomain: '1338' },
      ]);
      (mockAppContext.adapters.subgraph.getHubMessagesWithCheckpoints as SinonStub).resolves([hubMessages, { goldsky: 1 }]);
      (mockAppContext.adapters.subgraph.getSpokeMessagesWithCheckpoints as SinonStub).resolves([[], {}]);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateMessages(mockAppContext);

      // Only EVM-dest hub messages trigger getHyperlaneMsgDelivered (2 calls for domain 1337 and 1338)
      expect(getHyperlaneMsgDeliveredStub).to.have.callCount(2);
      const saveMessagesCall = (mockAppContext.adapters.database.saveMessages as SinonStub).getCalls().find(
        (c) => c.args[0]?.length === 4 && c.args[0][0].destinationDomain === SOLANA_CHAINID,
      );
      expect(saveMessagesCall).to.exist;
      const savedHubMessages = saveMessagesCall!.args[0] as Message[];
      expect(savedHubMessages[0].status).to.equal(HyperlaneStatus.pending);
      expect(savedHubMessages[1].status).to.equal(HyperlaneStatus.pending);
      expect(savedHubMessages[2].status).to.equal(HyperlaneStatus.pending);
      expect(savedHubMessages[3].status).to.equal(HyperlaneStatus.pending);
    });

    it('should not save checkpoint if empty', async () => {
      const getHyperlaneMsgDelivered = stub(coreMockable, 'getHyperlaneMsgDelivered');
      getHyperlaneMsgDelivered.resolves(false);

      const domains = Object.keys(mockAppContext.config.chains).filter((d) => mockAppContext.config.chains[d].network === 'evm').concat(mockAppContext.config.hub.domain);
      const hubMessages = createHubMessages(5);
      (mockAppContext.adapters.subgraph.getSpokeMessagesWithCheckpoints as SinonStub).resolves([[], {}]);
      (mockAppContext.adapters.subgraph.getHubMessagesWithCheckpoints as SinonStub).resolves([hubMessages, { goldsky: 1 }]);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateMessages(mockAppContext);

      expect(mockAppContext.adapters.database.saveMessages as SinonStub).callCount(domains.length);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(domains.length * 2);
      // Only hub messages have results, spoke messages are empty
      expect((mockAppContext.adapters.database.saveCheckPoint as SinonStub).called).to.be.true;
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

      await updateQueues(mockAppContext);

      expect(mockAppContext.adapters.database.saveQueues as SinonStub).callCount(1);
    });
  });

  describe('#updateMessageStatus', () => {
    it('should work', async () => {
      stub(coreMockable, 'getHyperlaneMsgDelivered').resolves(true);
      // should work for both hub and spoke destination domain
      const messages = createMessages(5, [{ destinationDomain: mockAppContext.config.hub.domain }]);
      (mockAppContext.adapters.database.getMessagesByStatus as SinonStub).resolves(messages);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      expect(await updateMessageStatus(mockAppContext)).to.not.throws;

      expect(mockAppContext.adapters.database.updateMessageStatus as SinonStub).callCount(5);
    });

    it('should use Polymer API for Polymer-routed messages and return delivered', async () => {
      const getPolymerStub = stub(coreMockable, 'getPolymerMsgDelivered').resolves(HyperlaneStatus.delivered);
      stub(coreMockable, 'getHyperlaneMsgDelivered').resolves(false);

      // Make hub domain 25327 so Ethereum (1) -> Hub (25327) is both a Polymer route and a configured destination
      mockAppContext.config.hub.domain = '25327';

      const messages: Message[] = [
        {
          id: mkBytes32('0xa1'),
          type: 'INTENT',
          domain: '1',
          originDomain: '1',
          destinationDomain: '25327',
          quote: '100',
          first: 1,
          last: 2,
          intentIds: [mkBytes32('0xa1')],
          status: HyperlaneStatus.pending,
          txOrigin: '0x',
          transactionHash: '0x',
          timestamp: 1,
          blockNumber: 1,
          txNonce: 1,
        },
      ];
      (mockAppContext.adapters.database.getMessagesByStatus as SinonStub)
        .onFirstCall().resolves(messages)
        .onSecondCall().resolves([]);

      await updateMessageStatus(mockAppContext);

      expect(getPolymerStub).to.have.been.calledOnceWith(mkBytes32('0xa1'));
      expect(mockAppContext.adapters.database.updateMessageStatus as SinonStub).to.have.been.calledOnceWith(
        mkBytes32('0xa1'),
        HyperlaneStatus.delivered,
      );
    });

    it('should return pending when Polymer API throws', async () => {
      const getPolymerStub = stub(coreMockable, 'getPolymerMsgDelivered').rejects(new Error('API down'));
      stub(coreMockable, 'getHyperlaneMsgDelivered').resolves(false);

      // Make hub domain 25327 so Base (8453) -> Hub (25327) is both a Polymer route and a configured destination
      mockAppContext.config.hub.domain = '25327';

      const messages: Message[] = [
        {
          id: mkBytes32('0xb1'),
          type: 'INTENT',
          domain: '8453',
          originDomain: '8453',
          destinationDomain: '25327',
          quote: '100',
          first: 1,
          last: 2,
          intentIds: [mkBytes32('0xb1')],
          status: HyperlaneStatus.pending,
          txOrigin: '0x',
          transactionHash: '0x',
          timestamp: 1,
          blockNumber: 1,
          txNonce: 1,
        },
      ];
      (mockAppContext.adapters.database.getMessagesByStatus as SinonStub)
        .onFirstCall().resolves(messages)
        .onSecondCall().resolves([]);

      await updateMessageStatus(mockAppContext);

      expect(getPolymerStub).to.have.been.calledOnce;
      expect(mockAppContext.adapters.database.updateMessageStatus as SinonStub).to.have.been.calledOnceWith(
        mkBytes32('0xb1'),
        HyperlaneStatus.pending,
      );
    });

    it('should use Hyperlane for non-Polymer routes', async () => {
      const getPolymerStub = stub(coreMockable, 'getPolymerMsgDelivered');
      stub(coreMockable, 'getHyperlaneMsgDelivered').resolves(true);

      // 1337 -> 1339 is not a Polymer route
      const messages = createMessages(1, [{ originDomain: '1337', destinationDomain: mockAppContext.config.hub.domain }]);
      (mockAppContext.adapters.database.getMessagesByStatus as SinonStub)
        .onFirstCall().resolves(messages)
        .onSecondCall().resolves([]);

      await updateMessageStatus(mockAppContext);

      expect(getPolymerStub).to.not.have.been.called;
      expect(mockAppContext.adapters.database.updateMessageStatus as SinonStub).to.have.been.calledOnce;
    });
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

      await updateProtocolUpdateLogs(mockAppContext);

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

      await updateProtocolUpdateLogs(mockAppContext);

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

      await updateProtocolUpdateLogs(mockAppContext);

      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).to.have.been.calledWith(
        'spoke_meta_log_block_1337',
        200,
      );
    });

    it('saves hub token + asset update logs and advances checkpoints', async () => {
      // No meta updates anywhere
      const getSpokeMetaUpdates = mockAppContext.adapters.subgraph.getSpokeMetaUpdates as SinonStub;
      getSpokeMetaUpdates.onCall(0).resolves([]);
      getSpokeMetaUpdates.onCall(1).resolves([]);
      (mockAppContext.adapters.subgraph.getHubMetaUpdates as SinonStub).resolves([]);

      const tokenUpdate: HubTokenUpdateLog = {
        id: 'hub-token-log-1',
        domain: mockAppContext.config.hub.domain,
        tickerHash: '0xticker',
        kind: 'TOKEN_CONFIGS_SET',
        feeRecipients: ['0xaaa'],
        feeAmounts: ['1', '2'],
        maxDiscountBps: 100,
        discountPerEpoch: 5,
        prioritizedStrategy: 'DEFAULT',
        transactionHash: '0xtx',
        timestamp: 1,
        blockNumber: 111,
        txOrigin: '0x1',
        txNonce: 1,
      };
      const assetUpdate: HubAssetUpdateLog = {
        id: 'hub-asset-log-1',
        domain: mockAppContext.config.hub.domain,
        assetId: '0xasset',
        tokenId: '0xticker',
        tickerHash: '0xticker',
        assetDomain: '1337',
        kind: 'ASSET_CONFIG_SET',
        assetHash: '0xhash',
        adopted: '0xadopted',
        approval: true,
        strategy: 'DEFAULT',
        transactionHash: '0xtx2',
        timestamp: 2,
        blockNumber: 222,
        txOrigin: '0x2',
        txNonce: 2,
      };

      (mockAppContext.adapters.subgraph.getHubTokenUpdates as SinonStub).resolves([tokenUpdate]);
      (mockAppContext.adapters.subgraph.getHubAssetUpdates as SinonStub).resolves([assetUpdate]);

      // Start checkpoints at 0
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateProtocolUpdateLogs(mockAppContext);

      expect(mockAppContext.adapters.database.saveHubTokenUpdateLogs as SinonStub).to.have.been.calledOnceWith([
        tokenUpdate,
      ]);
      expect(mockAppContext.adapters.database.saveHubAssetUpdateLogs as SinonStub).to.have.been.calledOnceWith([
        assetUpdate,
      ]);

      // Checkpoints advanced to max block per log type
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).to.have.been.calledWith(
        'hub_token_log_block',
        111,
      );
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).to.have.been.calledWith(
        'hub_asset_log_block',
        222,
      );
    });

    it('does not save hub token/asset logs when none found', async () => {
      const getSpokeMetaUpdates = mockAppContext.adapters.subgraph.getSpokeMetaUpdates as SinonStub;
      getSpokeMetaUpdates.resolves([]);
      (mockAppContext.adapters.subgraph.getHubMetaUpdates as SinonStub).resolves([]);
      (mockAppContext.adapters.subgraph.getHubTokenUpdates as SinonStub).resolves([]);
      (mockAppContext.adapters.subgraph.getHubAssetUpdates as SinonStub).resolves([]);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateProtocolUpdateLogs(mockAppContext);

      expect(mockAppContext.adapters.database.saveHubTokenUpdateLogs as SinonStub).to.not.have.been.called;
      expect(mockAppContext.adapters.database.saveHubAssetUpdateLogs as SinonStub).to.not.have.been.called;
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

      await updateHubSpokeMeta(mockAppContext);

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

      await updateHubSpokeMeta(mockAppContext);

      expect(mockAppContext.adapters.database.saveHubMeta as SinonStub).to.not.have.been.called;
      expect(mockAppContext.adapters.database.saveSpokeMeta as SinonStub).to.have.been.calledOnce;
      expect((mockAppContext.adapters.database.saveSpokeMeta as SinonStub).firstCall.args[0]).to.deep.equal([
        spokeMeta,
      ]);
    });

    it('does not save when no meta found', async () => {
      (mockAppContext.adapters.subgraph.getHubMeta as SinonStub).resolves(undefined);
      (mockAppContext.adapters.subgraph.getSpokeMeta as SinonStub).resolves(undefined);

      await updateHubSpokeMeta(mockAppContext);

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

      await updateHubSpokeMeta(mockAppContext);

      expect(mockAppContext.adapters.database.saveHubMeta as SinonStub).to.have.been.calledOnceWith([hubMeta]);
      expect(mockAppContext.adapters.database.saveSpokeMeta as SinonStub).to.have.been.calledOnce;
      expect((mockAppContext.adapters.database.saveSpokeMeta as SinonStub).firstCall.args[0]).to.deep.equal([
        spokeMeta,
      ]);
    });
  });
});
