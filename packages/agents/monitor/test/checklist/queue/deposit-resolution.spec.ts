import { mkAddress, mkBytes32 } from '@chimera-monorepo/utils';
import { expect } from 'chai';
import { stub, restore, SinonStub } from 'sinon';

import { checkDepositQueueCount } from '../../../src/checklist/queue/deposit';
import { getContext } from '../../../src/context';
import { sendAlerts, resolveAlerts } from '../../../src/mockable';
import { getCurrentEpoch } from '../../../src/helpers';

const mockRequestContext = { id: 'mock-request-id', origin: 'test' };
const mockLogger = {
  debug: stub(),
  info: stub(),
  warn: stub(),
  error: stub(),
};

describe('DepositQueueCount: Alert Resolution Bug Fix', () => {
  let getContextStub: SinonStub;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let getCurrentEpochStub: SinonStub;
  let getAllEnqueuedDepositsStub: SinonStub;

  const mockConfig = {
    chains: {
      '1': { network: 'evm', assets: { USDC: { address: mkAddress('0x1') } } },
      '8453': { network: 'evm', assets: { USDC: { address: mkAddress('0x2') } } },
    },
    thresholds: {
      maxDepositQueueCount: 15,
    },
    environment: 'test',
    network: 'testnet',
  };

  const USDC_TICKER_HASH = mkBytes32('0xabc');
  const CURRENT_EPOCH = 260800;

  beforeEach(() => {
    sendAlertsStub = stub();
    resolveAlertsStub = stub();
    getCurrentEpochStub = stub().resolves(CURRENT_EPOCH);
    getAllEnqueuedDepositsStub = stub();

    getContextStub = stub().returns({
      config: mockConfig,
      logger: mockLogger,
      adapters: {
        database: {
          getAllEnqueuedDeposits: getAllEnqueuedDepositsStub,
        },
      },
    });

    // Stub the imported functions
    stub(require('../../../src/context'), 'getContext').callsFake(getContextStub);
    stub(require('../../../src/mockable'), 'sendAlerts').callsFake(sendAlertsStub);
    stub(require('../../../src/mockable'), 'resolveAlerts').callsFake(resolveAlertsStub);
    stub(require('../../../src/helpers'), 'getCurrentEpoch').callsFake(getCurrentEpochStub);
  });

  afterEach(() => {
    restore();
  });

  describe('Bug: Alert triggered but never resolved', () => {
    it('should include resolved queue keys when calling resolveAlerts', async () => {
      // Scenario: 15 deposits were in queue for epoch 260645, alert was triggered
      // Then deposits were processed, so they no longer appear in getAllEnqueuedDeposits
      // The bug was that resolveAlerts would NOT include the 260645 queue key

      // First call: deposits are unprocessed, should trigger alert
      const unprocessedDeposits = Array.from({ length: 15 }, (_, i) => ({
        id: mkBytes32(`0x${i}`),
        intentId: mkBytes32(`0xintent${i}`),
        epoch: 260645,
        domain: '8453',
        tickerHash: USDC_TICKER_HASH,
        amount: '1000000',
        enqueuedTimestamp: Date.now() / 1000 - 300,
        enqueuedTxNonce: 1000 + i,
      }));

      getAllEnqueuedDepositsStub.resolves(unprocessedDeposits);

      await checkDepositQueueCount();

      // Verify alert was sent with the specific queue key
      expect(sendAlertsStub.calledOnce).to.be.true;
      const sentReport = sendAlertsStub.firstCall.args[0];
      expect(sentReport.ids).to.include(`260645-8453-${USDC_TICKER_HASH}`);
      expect(sentReport.type).to.equal('DepositQueueCountExceeded');

      // Reset stubs for second call
      sendAlertsStub.resetHistory();
      resolveAlertsStub.resetHistory();

      // Second call: deposits have been processed, should resolve alert
      getAllEnqueuedDepositsStub.resolves([]); // No unprocessed deposits

      await checkDepositQueueCount();

      // Verify resolveAlerts was called
      expect(resolveAlertsStub.calledOnce).to.be.true;

      // THE FIX: resolveAlerts should be called with keys that include the processed epoch
      const resolvedReport = resolveAlertsStub.firstCall.args[0];
      expect(resolvedReport.type).to.equal('DepositQueueCountExceeded');

      // The bug was that ids would be [] or only current queue keys
      // The fix generates keys for recent epochs including 260645
      expect(resolvedReport.ids).to.be.an('array');
      expect(resolvedReport.ids.length).to.be.greaterThan(0);

      // Most importantly: it should include the specific queue key that was alerted
      const resolvedKey = `260645-8453-${USDC_TICKER_HASH}`;
      expect(resolvedReport.ids).to.include(
        resolvedKey,
        `Resolution should include the processed queue key ${resolvedKey}`,
      );
    });

    it('should generate keys for last 200 epochs when resolving', async () => {
      getAllEnqueuedDepositsStub.resolves([]); // No unprocessed deposits

      await checkDepositQueueCount();

      expect(resolveAlertsStub.calledOnce).to.be.true;
      const resolvedReport = resolveAlertsStub.firstCall.args[0];

      // With 2 domains and 1 ticker, and 200 epochs lookback:
      // Should generate 2 * 1 * 200 = 400 keys
      // (In practice there might be multiple tickers from getConfiguredTickerHashes)
      expect(resolvedReport.ids.length).to.be.greaterThan(100);

      // Should include keys from current epoch down to (current - 200)
      expect(resolvedReport.ids).to.include(`${CURRENT_EPOCH}-8453-${USDC_TICKER_HASH}`);
      expect(resolvedReport.ids).to.include(`${CURRENT_EPOCH - 100}-8453-${USDC_TICKER_HASH}`);
      expect(resolvedReport.ids).to.include(`${CURRENT_EPOCH - 199}-8453-${USDC_TICKER_HASH}`);
    });

    it('should fall back gracefully if getCurrentEpoch fails', async () => {
      getAllEnqueuedDepositsStub.resolves([]); // No unprocessed deposits
      getCurrentEpochStub.rejects(new Error('RPC error'));

      await checkDepositQueueCount();

      // Should still call resolveAlerts despite error
      expect(resolveAlertsStub.calledOnce).to.be.true;

      // Should log a warning about the failure
      expect(mockLogger.warn.calledWith('Failed to get current epoch for resolution, using current queue keys only')).to.be
        .true;

      // Should fall back to empty array (no current queue keys)
      const resolvedReport = resolveAlertsStub.firstCall.args[0];
      expect(resolvedReport.ids).to.be.an('array');
    });

    it('should not call resolveAlerts if deposits are still above threshold', async () => {
      const manyDeposits = Array.from({ length: 20 }, (_, i) => ({
        id: mkBytes32(`0x${i}`),
        intentId: mkBytes32(`0xintent${i}`),
        epoch: CURRENT_EPOCH - 1,
        domain: '8453',
        tickerHash: USDC_TICKER_HASH,
        amount: '1000000',
        enqueuedTimestamp: Date.now() / 1000 - 100,
        enqueuedTxNonce: 1000 + i,
      }));

      getAllEnqueuedDepositsStub.resolves(manyDeposits);

      await checkDepositQueueCount();

      // Should send alert, not resolve
      expect(sendAlertsStub.calledOnce).to.be.true;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should handle multiple domains and tickers correctly', async () => {
      getAllEnqueuedDepositsStub.resolves([]);

      // Extend mock config with more tickers
      const extendedConfig = {
        ...mockConfig,
        chains: {
          '1': {
            network: 'evm',
            assets: {
              USDC: { address: mkAddress('0x1') },
              USDT: { address: mkAddress('0x2') },
            },
          },
          '8453': {
            network: 'evm',
            assets: {
              USDC: { address: mkAddress('0x3') },
              USDT: { address: mkAddress('0x4') },
            },
          },
          '42161': {
            network: 'evm',
            assets: {
              USDC: { address: mkAddress('0x5') },
            },
          },
        },
      };

      getContextStub.returns({
        config: extendedConfig,
        logger: mockLogger,
        adapters: {
          database: {
            getAllEnqueuedDeposits: getAllEnqueuedDepositsStub,
          },
        },
      });

      await checkDepositQueueCount();

      expect(resolveAlertsStub.calledOnce).to.be.true;
      const resolvedReport = resolveAlertsStub.firstCall.args[0];

      // Should generate keys for all domain-ticker combinations
      // 3 domains * 2 unique tickers * 200 epochs
      // Note: actual ticker count depends on getConfiguredTickerHashes implementation
      expect(resolvedReport.ids.length).to.be.greaterThan(200);
    });
  });

  describe('Integration: Full alert lifecycle', () => {
    it('should properly handle alert trigger -> process -> resolve cycle', async () => {
      const oldEpoch = CURRENT_EPOCH - 5;

      // Step 1: Deposits accumulate, trigger alert
      const deposits = Array.from({ length: 15 }, (_, i) => ({
        id: mkBytes32(`0x${i}`),
        intentId: mkBytes32(`0xintent${i}`),
        epoch: oldEpoch,
        domain: '8453',
        tickerHash: USDC_TICKER_HASH,
        amount: '1000000',
        enqueuedTimestamp: Date.now() / 1000 - 300,
        enqueuedTxNonce: 1000 + i,
      }));

      getAllEnqueuedDepositsStub.resolves(deposits);
      await checkDepositQueueCount();

      expect(sendAlertsStub.calledOnce).to.be.true;
      const alertKey = `${oldEpoch}-8453-${USDC_TICKER_HASH}`;
      expect(sendAlertsStub.firstCall.args[0].ids).to.include(alertKey);

      sendAlertsStub.resetHistory();
      resolveAlertsStub.resetHistory();

      // Step 2: Lighthouse processes deposits (they disappear from query)
      getAllEnqueuedDepositsStub.resolves([]);
      await checkDepositQueueCount();

      expect(resolveAlertsStub.calledOnce).to.be.true;
      expect(sendAlertsStub.called).to.be.false;

      // Step 3: Verify the alert key is included in resolution
      const resolvedReport = resolveAlertsStub.firstCall.args[0];
      expect(resolvedReport.ids).to.include(alertKey, 'Alert should be resolvable even after deposits are processed');
    });
  });
});

