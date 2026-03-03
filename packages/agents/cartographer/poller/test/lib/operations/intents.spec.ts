import { SinonStub } from 'sinon';

import { updateDestinationIntents, updateOriginIntents, updateSettlementIntents } from '../../../src/lib/operations';
import { expect, mkAddress } from '@chimera-monorepo/utils';
import { mockAppContext } from '../../globalTestHook';
import { createDestinationIntents, createHubIntents, createOriginIntents, createSettlementIntents } from '@chimera-monorepo/database/test/mock';
import { updateHubIntents } from '../../../src/lib/operations';

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

      await updateOriginIntents(mockAppContext);

      // Intents are now modified to include isSwap flag (defaults to false when asset configs not found)
      const expectedIntents = intents.map(intent => ({ ...intent, isSwap: false }));

      expect(mockAppContext.adapters.database.saveOriginIntents as SinonStub).callCount(1);
      expect(mockAppContext.adapters.database.saveOriginIntents as SinonStub).to.be.calledWithExactly(expectedIntents);

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

      await updateOriginIntents(mockAppContext);

      expect(mockAppContext.adapters.database.saveOriginIntents as SinonStub).callCount(0);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(0);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(0);
    });

    it('should set isSwap to false when input and output assets have same ticker hash', async () => {
      // Setup config with assets having same ticker hash (bridge scenario)
      const usdcTickerHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      mockAppContext.config.chains['1337'].assets = {
        USDC: {
          symbol: 'USDC',
          address: mkAddress('0xa0b86991'),
          decimals: 6,
          isNative: false,
          price: { isStable: true },
          tickerHash: usdcTickerHash,
        },
      };
      mockAppContext.config.chains['1338'].assets = {
        USDC: {
          symbol: 'USDC',
          address: mkAddress('0xaf88d065'),
          decimals: 6,
          isNative: false,
          price: { isStable: true },
          tickerHash: usdcTickerHash, // Same ticker hash
        },
      };

      const domains = Object.keys(mockAppContext.config.chains).filter(
        (domain) => domain !== mockAppContext.config.hub.domain,
      );
      const intents = createOriginIntents(1, [{
        origin: '1337',
        inputAsset: mkAddress('0xa0b86991'),
        outputAsset: mkAddress('0xaf88d065'),
        destinations: ['1338'],
      }]);

      (mockAppContext.adapters.subgraph.getOriginIntentsByNonce as SinonStub).resolves(intents);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(
        new Map(domains.map((domain) => [domain, 1])),
      );
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateOriginIntents(mockAppContext);

      const savedIntents = (mockAppContext.adapters.database.saveOriginIntents as SinonStub).getCall(0).args[0];
      expect(savedIntents[0].isSwap).to.equal(false);
    });

    it('should set isSwap to true when input and output assets have different ticker hashes', async () => {
      // Setup config with assets having different ticker hashes (swap scenario)
      const usdcTickerHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      const wethTickerHash = '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

      mockAppContext.config.chains['1337'].assets = {
        USDC: {
          symbol: 'USDC',
          address: mkAddress('0xa0b86991'),
          decimals: 6,
          isNative: false,
          price: { isStable: true },
          tickerHash: usdcTickerHash,
        },
      };
      mockAppContext.config.chains['1338'].assets = {
        WETH: {
          symbol: 'WETH',
          address: mkAddress('0x82af4944'),
          decimals: 18,
          isNative: false,
          price: { isStable: false },
          tickerHash: wethTickerHash, // Different ticker hash
        },
      };

      const domains = Object.keys(mockAppContext.config.chains).filter(
        (domain) => domain !== mockAppContext.config.hub.domain,
      );
      const intents = createOriginIntents(1, [{
        origin: '1337',
        inputAsset: mkAddress('0xa0b86991'),
        outputAsset: mkAddress('0x82af4944'),
        destinations: ['1338'],
      }]);

      (mockAppContext.adapters.subgraph.getOriginIntentsByNonce as SinonStub).resolves(intents);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(
        new Map(domains.map((domain) => [domain, 1])),
      );
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateOriginIntents(mockAppContext);

      const savedIntents = (mockAppContext.adapters.database.saveOriginIntents as SinonStub).getCall(0).args[0];
      expect(savedIntents[0].isSwap).to.equal(true);
    });

    it('should set isSwap to false when asset configs are not found', async () => {
      // No assets configured - should default to false
      mockAppContext.config.chains['1337'].assets = {};
      mockAppContext.config.chains['1338'].assets = {};

      const domains = Object.keys(mockAppContext.config.chains).filter(
        (domain) => domain !== mockAppContext.config.hub.domain,
      );
      const intents = createOriginIntents(1, [{
        origin: '1337',
        inputAsset: mkAddress('0xa0b86991'),
        outputAsset: mkAddress('0xaf88d065'),
        destinations: ['1338'],
      }]);

      (mockAppContext.adapters.subgraph.getOriginIntentsByNonce as SinonStub).resolves(intents);
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(
        new Map(domains.map((domain) => [domain, 1])),
      );
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateOriginIntents(mockAppContext);

      const savedIntents = (mockAppContext.adapters.database.saveOriginIntents as SinonStub).getCall(0).args[0];
      expect(savedIntents[0].isSwap).to.equal(false);
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

      await updateDestinationIntents(mockAppContext);

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

      await updateDestinationIntents(mockAppContext);

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

      await updateSettlementIntents(mockAppContext);

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

      await updateDestinationIntents(mockAppContext);

      expect(mockAppContext.adapters.database.saveSettlementIntents as SinonStub).callCount(0);

      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(0);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(0);
    });
  });

  describe('#updateHubIntents', () => {
    it('not proceed if latest block number not available', async () => {
      (mockAppContext.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(new Map());
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateHubIntents(mockAppContext);

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

      await updateHubIntents(mockAppContext);

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

      await updateHubIntents(mockAppContext);

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
