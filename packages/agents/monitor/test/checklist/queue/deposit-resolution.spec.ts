import { Logger, expect, mkHash } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkDepositQueueCount } from '../../../src/checklist/queue/deposit';
import { getContextStub, mock } from '../../globalTestHook';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../../src/mockable';

describe('DepositQueueCount: Alert Resolution with Simplified Keys', () => {
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let database: SinonStubbedInstance<Database>;

  const USDC_TICKER_HASH = mkHash('0xabc');
  const USDT_TICKER_HASH = mkHash('0xdef');
  const TEST_DOMAIN = '1337'; // Using the standard test domain
  const TEST_EPOCH = 260800;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    
    database = mock.instances.database() as SinonStubbedInstance<Database>;
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

    sendAlertsStub = stub(Mockable, 'sendAlerts').resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts').resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('Simplified Key Format: ${domain}-${tickerHash}', () => {
    it('should use domain-tickerHash key format without epoch', async () => {
      // First call: deposits are unprocessed, should trigger alert
      const unprocessedDeposits = Array.from({ length: 15 }, (_, i) => 
        mock.depositQueue({
          epoch: TEST_EPOCH,
          domain: TEST_DOMAIN,
          tickerHash: USDC_TICKER_HASH,
          enqueuedTimestamp: Date.now() / 1000 - 300,
        })
      );

      database.getAllEnqueuedDeposits.resolves(unprocessedDeposits);

      await checkDepositQueueCount();

      // Verify alert was sent with the simplified key format (no epoch)
      expect(sendAlertsStub.calledOnce).to.be.true;
      const sentReport = sendAlertsStub.firstCall.args[0];
      expect(sentReport.type).to.equal('DepositQueueCountExceeded');
      expect(sentReport.ids).to.include(`${TEST_DOMAIN}-${USDC_TICKER_HASH}`);
    });

    it('should automatically resolve when queue clears', async () => {
      // First call: deposits are unprocessed, should trigger alert
      const unprocessedDeposits = Array.from({ length: 15 }, (_, i) => 
        mock.depositQueue({
          epoch: TEST_EPOCH,
          domain: TEST_DOMAIN,
          tickerHash: USDC_TICKER_HASH,
          enqueuedTimestamp: Date.now() / 1000 - 300,
        })
      );

      database.getAllEnqueuedDeposits.resolves(unprocessedDeposits);
      await checkDepositQueueCount();

      expect(sendAlertsStub.calledOnce).to.be.true;

      // Reset stubs for second call
      sendAlertsStub.resetHistory();
      resolveAlertsStub.resetHistory();

      // Second call: deposits have been processed, should resolve alert
      database.getAllEnqueuedDeposits.resolves([]);

      await checkDepositQueueCount();

      // Verify resolveAlerts was called with the same key format
      expect(resolveAlertsStub.calledOnce).to.be.true;
      const resolvedReport = resolveAlertsStub.firstCall.args[0];
      expect(resolvedReport.type).to.equal('DepositQueueCountExceeded');
      expect(resolvedReport.ids).to.include(`${TEST_DOMAIN}-${USDC_TICKER_HASH}`);
    });

    it('should generate keys for all configured domain-ticker combinations', async () => {
      database.getAllEnqueuedDeposits.resolves([]);

      await checkDepositQueueCount();

      expect(resolveAlertsStub.calledOnce).to.be.true;
      const resolvedReport = resolveAlertsStub.firstCall.args[0];

      // With 2 domains and configured tickers, should generate domain-ticker keys
      expect(resolvedReport.ids).to.be.an('array');
      expect(resolvedReport.ids.length).to.be.greaterThan(0);

      // All keys should follow ${domain}-${tickerHash} format (no epoch)
      resolvedReport.ids.forEach((id: string) => {
        expect(id).to.match(/^\d+-0x[0-9a-f]+$/);
      });
    });

    it('should not call resolveAlerts if deposits are still above threshold', async () => {
      const manyDeposits = Array.from({ length: 20 }, (_, i) => 
        mock.depositQueue({
          epoch: TEST_EPOCH,
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
      // 3 domains * unique tickers (depends on getConfiguredTickerHashes)
      expect(resolvedReport.ids.length).to.be.greaterThan(0);

      // Verify format: all keys should be ${domain}-${tickerHash}
      resolvedReport.ids.forEach((id: string) => {
        expect(id).to.match(/^\d+-0x[0-9a-f]+$/);
      });
    });
  });

  describe('Integration: Full alert lifecycle', () => {
    it('should properly handle alert trigger -> process -> resolve cycle', async () => {
      // Step 1: Deposits accumulate, trigger alert
      const deposits = Array.from({ length: 15 }, (_, i) => 
        mock.depositQueue({
          epoch: TEST_EPOCH,
          domain: TEST_DOMAIN,
          tickerHash: USDC_TICKER_HASH,
          enqueuedTimestamp: Date.now() / 1000 - 300,
        })
      );

      database.getAllEnqueuedDeposits.resolves(deposits);
      await checkDepositQueueCount();

      expect(sendAlertsStub.calledOnce).to.be.true;
      expect(sendAlertsStub.firstCall.args[0].ids).to.include(`${TEST_DOMAIN}-${USDC_TICKER_HASH}`);

      sendAlertsStub.resetHistory();
      resolveAlertsStub.resetHistory();

      // Step 2: Lighthouse processes deposits (they disappear from query)
      database.getAllEnqueuedDeposits.resolves([]);
      await checkDepositQueueCount();

      expect(resolveAlertsStub.calledOnce).to.be.true;
      expect(sendAlertsStub.called).to.be.false;

      // Step 3: Verify the alert key is included in resolution
      const resolvedReport = resolveAlertsStub.firstCall.args[0];
      expect(resolvedReport.ids).to.include(`${TEST_DOMAIN}-${USDC_TICKER_HASH}`);
    });

    it('should handle multiple deposits across different epochs for same domain-ticker', async () => {
      // Multiple deposits from different epochs, same domain-ticker
      const deposits = [
        ...Array.from({ length: 10 }, (_, i) => 
          mock.depositQueue({
            epoch: TEST_EPOCH,
            domain: TEST_DOMAIN,
            tickerHash: USDC_TICKER_HASH,
            enqueuedTimestamp: Date.now() / 1000 - 300,
          })
        ),
        ...Array.from({ length: 8 }, (_, i) => 
          mock.depositQueue({
            epoch: TEST_EPOCH + 1,
            domain: TEST_DOMAIN,
            tickerHash: USDC_TICKER_HASH,
            enqueuedTimestamp: Date.now() / 1000 - 200,
          })
        ),
      ];

      database.getAllEnqueuedDeposits.resolves(deposits);
      await checkDepositQueueCount();

      // Should aggregate count across epochs and trigger alert (18 total > 15 threshold)
      expect(sendAlertsStub.calledOnce).to.be.true;
      const sentReport = sendAlertsStub.firstCall.args[0];
      expect(sentReport.ids).to.include(`${TEST_DOMAIN}-${USDC_TICKER_HASH}`);
    });
  });
});

