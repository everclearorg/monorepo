import { Logger, expect, mkHash } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkDepositQueueCount } from '../../../src/checklist/queue/deposit';
import { getContextStub, mock } from '../../globalTestHook';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../../src/mockable';
import { BigNumber } from 'ethers';
import { Interface } from 'ethers/lib/utils';

describe('DepositQueueCount: Alert Resolution Bug Fix', () => {
  let chainreader: SinonStubbedInstance<ChainReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let database: SinonStubbedInstance<Database>;
  let decodeStub: SinonStub;
  let encodeStub: SinonStub;

  const USDC_TICKER_HASH = mkHash('0xabc');
  const CURRENT_EPOCH = 260800;
  const TEST_DOMAIN = '1337'; // Using the standard test domain

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    
    const config = {
      ...mock.config(),
      thresholds: {
        ...mock.config().thresholds,
        maxDepositQueueCount: 15,
      },
    };
    
    getContextStub.returns({
      ...mock.context(),
      config,
    });

    // Mock the chainreader and Interface for getCurrentEpoch
    chainreader.readTx.resolves('0x1234');
    const mockGetFunction = new Interface(['function foo()']).getFunction('foo');
    encodeStub = stub(Interface.prototype, 'encodeFunctionData').returns('0x1234');
    decodeStub = stub(Interface.prototype, 'decodeFunctionResult').returns([BigNumber.from(CURRENT_EPOCH)]);
    stub(Interface.prototype, 'getFunction').returns(mockGetFunction);

    sendAlertsStub = stub(Mockable, 'sendAlerts').resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts').resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('Bug: Alert triggered but never resolved', () => {
    it('should include resolved queue keys when calling resolveAlerts', async () => {
      // Scenario: 15 deposits were in queue for recent epoch, alert was triggered
      // Then deposits were processed, so they no longer appear in getAllEnqueuedDeposits
      // The bug was that resolveAlerts would NOT include the processed queue key

      const recentEpoch = CURRENT_EPOCH - 5; // Well within 200 epoch lookback

      // First call: deposits are unprocessed, should trigger alert
      const unprocessedDeposits = Array.from({ length: 15 }, (_, i) => 
        mock.depositQueue({
          epoch: recentEpoch,
          domain: TEST_DOMAIN,
          tickerHash: USDC_TICKER_HASH,
          enqueuedTimestamp: Date.now() / 1000 - 300,
        })
      );

      database.getAllEnqueuedDeposits.resolves(unprocessedDeposits);

      await checkDepositQueueCount();

      // Verify alert was sent with the specific queue key
      expect(sendAlertsStub.calledOnce).to.be.true;
      const sentReport = sendAlertsStub.firstCall.args[0];
      expect(sentReport.type).to.equal('DepositQueueCountExceeded');
      expect(sentReport.ids.some((id: string) => id.startsWith(`${recentEpoch}-${TEST_DOMAIN}`))).to.be.true;

      // Reset stubs for second call
      sendAlertsStub.resetHistory();
      resolveAlertsStub.resetHistory();

      // Second call: deposits have been processed, should resolve alert
      database.getAllEnqueuedDeposits.resolves([]); // No unprocessed deposits

      await checkDepositQueueCount();

      // Verify resolveAlerts was called
      expect(resolveAlertsStub.calledOnce).to.be.true;

      // THE FIX: resolveAlerts should be called with keys that include the processed epoch
      const resolvedReport = resolveAlertsStub.firstCall.args[0];
      expect(resolvedReport.type).to.equal('DepositQueueCountExceeded');

      // The bug was that ids would be [] or only current queue keys
      // The fix generates keys for recent epochs
      expect(resolvedReport.ids).to.be.an('array');
      expect(resolvedReport.ids.length).to.be.greaterThan(0);

      // Most importantly: it should include the epoch that was alerted
      const keyExists = resolvedReport.ids.some((id: string) => id.startsWith(`${recentEpoch}-${TEST_DOMAIN}`));
      expect(keyExists, `Should include epoch ${recentEpoch} for domain ${TEST_DOMAIN}`).to.be.true;
    });

    it('should generate keys for last 200 epochs when resolving', async () => {
      database.getAllEnqueuedDeposits.resolves([]); // No unprocessed deposits

      await checkDepositQueueCount();

      expect(resolveAlertsStub.calledOnce).to.be.true;
      const resolvedReport = resolveAlertsStub.firstCall.args[0];

      // With 2 domains and 1 ticker, and 200 epochs lookback:
      // Should generate 2 * 1 * 200 = 400 keys
      // (In practice there might be multiple tickers from getConfiguredTickerHashes)
      expect(resolvedReport.ids.length).to.be.greaterThan(100);

      // Should include keys from current epoch down to (current - 200)
      // Check that keys exist for these epochs
      const hasCurrentEpoch = resolvedReport.ids.some((id: string) => id.startsWith(`${CURRENT_EPOCH}-${TEST_DOMAIN}`));
      const hasMidEpoch = resolvedReport.ids.some((id: string) => id.startsWith(`${CURRENT_EPOCH - 100}-${TEST_DOMAIN}`));
      const hasOldEpoch = resolvedReport.ids.some((id: string) => id.startsWith(`${CURRENT_EPOCH - 199}-${TEST_DOMAIN}`));
      expect(hasCurrentEpoch, `Should have current epoch ${CURRENT_EPOCH}`).to.be.true;
      expect(hasMidEpoch, `Should have mid epoch ${CURRENT_EPOCH - 100}`).to.be.true;
      expect(hasOldEpoch, `Should have old epoch ${CURRENT_EPOCH - 199}`).to.be.true;
    });

    it('should fall back gracefully if getCurrentEpoch fails', async () => {
      database.getAllEnqueuedDeposits.resolves([]); // No unprocessed deposits
      
      // Make chainreader.readTx throw an error
      chainreader.readTx.rejects(new Error('RPC error'));

      await checkDepositQueueCount();

      // Should still call resolveAlerts despite error
      expect(resolveAlertsStub.calledOnce).to.be.true;

      // Should fall back to empty array (no current queue keys)
      const resolvedReport = resolveAlertsStub.firstCall.args[0];
      expect(resolvedReport.ids).to.be.an('array');
    });

    it('should not call resolveAlerts if deposits are still above threshold', async () => {
      const manyDeposits = Array.from({ length: 20 }, (_, i) => 
        mock.depositQueue({
          epoch: CURRENT_EPOCH - 1,
          domain: TEST_DOMAIN,
          tickerHash: USDC_TICKER_HASH,
          enqueuedTimestamp: Date.now() / 1000 - 100,
        })
      );

      database.getAllEnqueuedDeposits.resolves(manyDeposits);

      await checkDepositQueueCount();

      // Should send alert, not resolve
      expect(sendAlertsStub.calledOnce).to.be.true;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should handle multiple domains and tickers correctly', async () => {
      database.getAllEnqueuedDeposits.resolves([]);

      // Extend mock config with more tickers
      const extendedConfig = {
        ...mock.config(),
        chains: {
          '1': {
            network: 'evm',
            assets: {
              USDC: { address: '0x0000000000000000000000000000000000000001' },
              USDT: { address: '0x0000000000000000000000000000000000000002' },
            },
          },
          '8453': {
            network: 'evm',
            assets: {
              USDC: { address: '0x0000000000000000000000000000000000000003' },
              USDT: { address: '0x0000000000000000000000000000000000000004' },
            },
          },
          '42161': {
            network: 'evm',
            assets: {
              USDC: { address: '0x0000000000000000000000000000000000000005' },
            },
          },
        },
        thresholds: {
          ...mock.config().thresholds,
          maxDepositQueueCount: 15,
        },
      };

      getContextStub.returns({
        ...mock.context(),
        config: extendedConfig,
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
      const deposits = Array.from({ length: 15 }, (_, i) => 
        mock.depositQueue({
          epoch: oldEpoch,
          domain: TEST_DOMAIN,
          tickerHash: USDC_TICKER_HASH,
          enqueuedTimestamp: Date.now() / 1000 - 300,
        })
      );

      database.getAllEnqueuedDeposits.resolves(deposits);
      await checkDepositQueueCount();

      expect(sendAlertsStub.calledOnce).to.be.true;
      expect(sendAlertsStub.firstCall.args[0].ids.some((id: string) => id.startsWith(`${oldEpoch}-${TEST_DOMAIN}`))).to.be.true;

      sendAlertsStub.resetHistory();
      resolveAlertsStub.resetHistory();

      // Step 2: Lighthouse processes deposits (they disappear from query)
      database.getAllEnqueuedDeposits.resolves([]);
      await checkDepositQueueCount();

      expect(resolveAlertsStub.calledOnce).to.be.true;
      expect(sendAlertsStub.called).to.be.false;

      // Step 3: Verify the alert key is included in resolution
      const resolvedReport = resolveAlertsStub.firstCall.args[0];
      const hasAlertEpoch = resolvedReport.ids.some((id: string) => id.startsWith(`${oldEpoch}-${TEST_DOMAIN}`));
      expect(hasAlertEpoch, `Alert should be resolvable even after deposits are processed for epoch ${oldEpoch}`).to.be.true;
    });
  });
});

