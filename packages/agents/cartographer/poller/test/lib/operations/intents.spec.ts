import { SinonStub, SinonStubbedInstance } from 'sinon';

import { updateDestinationIntents, updateOriginIntents, updateSettlementIntents } from '../../../src/lib/operations';
import { expect, mkBytes32 } from '@chimera-monorepo/utils';
import { mockAppContext } from '../../globalTestHook';
import { createDestinationIntents, createHubIntents, createOriginIntents, createSettlementIntents } from '@chimera-monorepo/database/test/mock';
import { updateHubIntents } from '../../../src/lib/operations/intents';
import { SubgraphReader } from '../../../../../../adapters/subgraph/src';
import { Database } from '@chimera-monorepo/database';

describe('Intents operations', () => {
  describe('#updateOriginIntents', () => {
    it('should work', async () => {
      const domains = Object.keys(mockAppContext.config.chains).filter(
        (domain) => domain !== mockAppContext.config.hub.domain,
      );
      const intents = createOriginIntents(domains.length, [{ origin: '1337' }, { origin: '1338' }]);
      (mockAppContext.adapters.subgraph.getOriginIntentsByNonce as SinonStub).resolves(intents);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(
        new Map(domains.map((domain) => [domain, 1])),
      );
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateOriginIntents();

      expect(mockAppContext.adapters.database.saveOriginIntents as SinonStub).callCount(1);
      expect(mockAppContext.adapters.database.saveOriginIntents as SinonStub).to.be.calledWithExactly(intents);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(domains.length);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(domains.length);
    });

    it('not proceed if latest block number not available', async () => {
      const domains = Object.keys(mockAppContext.config.chains).filter(
        (domain) => domain !== mockAppContext.config.hub.domain,
      );
      const intents = createOriginIntents(domains.length, [{ origin: '1337' }, { origin: '1338' }]);
      (mockAppContext.adapters.subgraph.getOriginIntentsByNonce as SinonStub).resolves(intents);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(new Map());
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateOriginIntents();

      expect(mockAppContext.adapters.database.saveOriginIntents as SinonStub).callCount(0);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(0);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(0);
    });
  });

  describe('#updateDestinationIntents', () => {
    it('should work', async () => {
      const domains = Object.keys(mockAppContext.config.chains).filter(
        (domain) => domain !== mockAppContext.config.hub.domain,
      );
      const intents = createDestinationIntents(domains.length, [{ destination: '1337' }, { destination: '1338' }]);
      (mockAppContext.adapters.subgraph.getDestinationIntentsByNonce as SinonStub).resolves(intents);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(
        new Map(domains.map((domain) => [domain, 1])),
      );
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateDestinationIntents();

      expect(mockAppContext.adapters.database.saveDestinationIntents as SinonStub).callCount(1);
      expect(mockAppContext.adapters.database.saveDestinationIntents as SinonStub).to.be.calledWithExactly(intents);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(domains.length);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(domains.length);
    });

    it('not proceed if latest block number not available', async () => {
      const domains = Object.keys(mockAppContext.config.chains).filter(
        (domain) => domain !== mockAppContext.config.hub.domain,
      );
      const intents = createDestinationIntents(domains.length, [{ destination: '1337' }, { destination: '1338' }]);
      (mockAppContext.adapters.subgraph.getDestinationIntentsByNonce as SinonStub).resolves(intents);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(new Map());
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateDestinationIntents();

      expect(mockAppContext.adapters.database.saveDestinationIntents as SinonStub).callCount(0);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(0);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(0);
    });
  });

  describe('#updateSettlementIntents', () => {
    it('should work', async () => {
      const domains = Object.keys(mockAppContext.config.chains).filter(
        (domain) => domain !== mockAppContext.config.hub.domain,
      );
      const intents = createSettlementIntents(domains.length);
      (mockAppContext.adapters.subgraph.getSettlementIntentsByNonce as SinonStub).resolves(intents);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(
        new Map(domains.map((domain) => [domain, 1])),
      );
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateSettlementIntents();

      expect(mockAppContext.adapters.database.saveSettlementIntents as SinonStub).callCount(1);
      expect(mockAppContext.adapters.database.saveSettlementIntents as SinonStub).to.be.calledWithExactly(intents);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(domains.length);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(1);
    });

    it('not proceed if latest block number not available', async () => {
      const domains = Object.keys(mockAppContext.config.chains).filter(
        (domain) => domain !== mockAppContext.config.hub.domain,
      );
      const intents = createSettlementIntents(domains.length);
      (mockAppContext.adapters.subgraph.getSettlementIntentsByNonce as SinonStub).resolves(intents);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(new Map());
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateDestinationIntents();

      expect(mockAppContext.adapters.database.saveSettlementIntents as SinonStub).callCount(0);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(0);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(0);
    });
  });

  describe('#updateHubIntents', () => {
    it('not proceed if latest block number not available', async () => {
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(new Map());
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateHubIntents();

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(0);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(0);
    });

    it('should work', async () => {
      const addedIntents = createHubIntents(2, [
        { status: 'ADDED', domain: '1337' },
        { status: 'SETTLED', domain: '1338' },
      ]);
      const filledIntents = createHubIntents(2, [
        { status: 'FILLED', domain: '1337' },
        { status: 'DISPATCHED', domain: '1338' },
      ]);
      const enqueuedIntents = createHubIntents(2, [
        { status: 'DISPATCHED', domain: '1337' },
        { status: 'SETTLED', domain: '1338' },
      ]);
      (mockAppContext.adapters.subgraph.getHubIntentsByNonce as SinonStub).resolves([
        addedIntents,
        filledIntents,
        enqueuedIntents,
      ]);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(
        new Map([mockAppContext.config.hub.domain].map((domain) => [domain, 1])),
      );
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateHubIntents();

      expect(mockAppContext.adapters.database.saveHubIntents as SinonStub).callCount(3);
      expect((mockAppContext.adapters.database.saveHubIntents as SinonStub).getCall(0)).to.be.calledWithExactly(
        addedIntents,
        ['added_timestamp', 'added_tx_nonce', 'status'],
      );
      expect((mockAppContext.adapters.database.saveHubIntents as SinonStub).getCall(1)).to.be.calledWithExactly(
        filledIntents,
        ['filled_timestamp', 'filled_tx_nonce', 'status'],
      );

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(3);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(3);
    });

    it('should not save checkpoint if empty', async () => {
      const addedIntents = createHubIntents(2, [
        { status: 'ADDED', domain: '1337' },
        { status: 'SETTLED', domain: '1338' },
      ]);

      (mockAppContext.adapters.subgraph.getHubIntentsByNonce as SinonStub).resolves([addedIntents, [], []]);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(
        new Map([mockAppContext.config.hub.domain].map((domain) => [domain, 1])),
      );
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateHubIntents();

      expect(mockAppContext.adapters.database.saveHubIntents as SinonStub).callCount(3);
      expect((mockAppContext.adapters.database.saveHubIntents as SinonStub).getCall(0)).to.be.calledWithExactly(
        addedIntents,
        ['added_timestamp', 'added_tx_nonce', 'status'],
      );
      expect((mockAppContext.adapters.database.saveHubIntents as SinonStub).getCall(1)).to.be.calledWithExactly(
        [],
        ['filled_timestamp', 'filled_tx_nonce', 'status'],
      );

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(3);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(1);
    });
  });
});
