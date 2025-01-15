import { SinonStub, stub } from 'sinon';

import { updateMessages, updateMessageStatus, updateQueues } from '../../../src/lib/operations';
import {
  Message,
  TIntentStatus,
  TMessageType,
  TSettlementMessageType,
  expect,
  HyperlaneStatus
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
      const messages = createMessages(5, [{  destinationDomain: mockAppContext.config.hub.domain }]);
      (mockAppContext.adapters.database.getMessagesByStatus as SinonStub).resolves(messages);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      expect(await updateMessageStatus()).to.not.throws;

      expect(mockAppContext.adapters.database.updateMessageStatus as SinonStub).callCount(5);
    })
  })
});
