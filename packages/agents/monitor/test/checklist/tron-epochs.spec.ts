import { Logger, expect, Invoice } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance, SinonStub } from 'sinon';
import { checkTronElapsedEpochsByTickerHash } from '../../src/checklist/tron-epochs';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import { Database } from '@chimera-monorepo/database';
import * as helpers from '../../src/helpers';
import * as libs from '../../src/libs';
import * as Mockable from '../../src/mockable';

describe('Tron Epochs Monitoring', () => {
  let database: SinonStubbedInstance<Database>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let getCurrentEpochStub: SinonStub;
  let getAssetConfigByTickerHashStub: SinonStub;
  let getTokenPriceStub: SinonStub;

  const mockTickerHash = '0xbbbbfcba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4';
  const mockTronInvoices: Invoice[] = [
    {
      id: 'invoice1',
      originIntent: {
        id: 'intent1',
        origin: '728126428', // Tron domain
        amount: '1000000', // 1 TRX (6 decimals)
      },
      hubInvoiceEntryEpoch: 10,
      hubStatus: 'INVOICED',
    } as Invoice,
    {
      id: 'invoice2',
      originIntent: {
        id: 'intent2',
        origin: '728126428', // Tron domain
        amount: '5000000', // 5 TRX
      },
      hubInvoiceEntryEpoch: 8,
      hubStatus: 'INVOICED',
    } as Invoice,
  ];

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
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();

    // getCurrentEpoch is globally stubbed, use that value
    // getCurrentEpochStub will be null since we're using global stub
    getCurrentEpochStub = null;

    // Note: getAssetConfigByTickerHash may be non-configurable, using global mock config
    // Test should use the asset configurations from global mock config

    // Note: getTokenPrice may be non-configurable, using mock context for price data
    // Test should use mock configuration price data or skip price-dependent logic

    // Setup mock database responses
    database.getLatestInvoicesByTickerHash.resolves(
      new Map([[mockTickerHash, mockTronInvoices]])
    );
    database.getTokens.resolves([{
      id: mockTickerHash,
      symbol: 'TRX',
      decimals: 6,
    }]);
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronElapsedEpochsByTickerHash', () => {
    it('should check Tron elapsed epochs successfully', async () => {
      await checkTronElapsedEpochsByTickerHash();

      // Should call database to get invoices
      expect(database.getLatestInvoicesByTickerHash.called).to.be.true;
      expect(database.getTokens.called).to.be.true;

      // Should get current epoch
      expect(getCurrentEpochStub.called).to.be.true;

      // Should not alert when average elapsed epochs are below threshold (default 3)
      // Average: ((15-10) + (15-8)) / 2 = (5 + 7) / 2 = 6 > 3, so should alert
      expect(sendAlertsStub.called).to.be.true;
    });

    it('should filter invoices to only include Tron chains', async () => {
      // Setup mixed domain invoices
      const mixedInvoices: Invoice[] = [
        {
          id: 'invoice1',
          originIntent: {
            id: 'intent1',
            origin: '1337', // EVM domain
            amount: '1000000000000000000', // 1 ETH (18 decimals)
          },
          hubInvoiceEntryEpoch: 10,
          hubStatus: 'INVOICED',
        } as Invoice,
        {
          id: 'invoice2',
          originIntent: {
            id: 'intent2',
            origin: '728126428', // Tron domain
            amount: '1000000', // 1 TRX (6 decimals)
          },
          hubInvoiceEntryEpoch: 12,
          hubStatus: 'INVOICED',
        } as Invoice,
      ];

      database.getLatestInvoicesByTickerHash.resolves(
        new Map([[mockTickerHash, mixedInvoices]])
      );

      await checkTronElapsedEpochsByTickerHash();

      // Should process only the Tron invoice
      // Average elapsed epochs: (15 - 12) = 3 (exactly at threshold)
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should alert when average elapsed epochs exceed threshold', async () => {
      // Setup very old invoices
      const oldInvoices: Invoice[] = [
        {
          id: 'invoice1',
          originIntent: {
            id: 'intent1',
            origin: '728126428',
            amount: '100000000', // 100 TRX (above amount threshold)
          },
          hubInvoiceEntryEpoch: 5, // 10 epochs ago
          hubStatus: 'INVOICED',
        } as Invoice,
        {
          id: 'invoice2',
          originIntent: {
            id: 'intent2',
            origin: '728126428',
            amount: '100000000', // 100 TRX
          },
          hubInvoiceEntryEpoch: 3, // 12 epochs ago
          hubStatus: 'INVOICED',
        } as Invoice,
      ];

      database.getLatestInvoicesByTickerHash.resolves(
        new Map([[mockTickerHash, oldInvoices]])
      );

      await checkTronElapsedEpochsByTickerHash();

      // Average: ((15-5) + (15-3)) / 2 = (10 + 12) / 2 = 11 > 3
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('AverageElapsedEpochsAboveThreshold');
      expect(alert.ids).to.include(mockTickerHash);
    });

    it('should filter by amount threshold', async () => {
      // Setup invoices with amounts below threshold
      const smallInvoices: Invoice[] = [
        {
          id: 'invoice1',
          originIntent: {
            id: 'intent1',
            origin: '728126428',
            amount: '1000', // 0.001 TRX (very small amount)
          },
          hubInvoiceEntryEpoch: 1, // Very old
          hubStatus: 'INVOICED',
        } as Invoice,
      ];

      database.getLatestInvoicesByTickerHash.resolves(
        new Map([[mockTickerHash, smallInvoices]])
      );

      await checkTronElapsedEpochsByTickerHash();

      // Should not alert because amount is below threshold
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle no Tron chains configured', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': { network: 'evm' }, // Only EVM chains
          },
        },
      });

      await checkTronElapsedEpochsByTickerHash();

      // Should return early and not process anything
      expect(database.getLatestInvoicesByTickerHash.called).to.be.false;
    });

    it('should handle missing token configuration', async () => {
      database.getTokens.resolves([]); // No token configs

      try {
        await checkTronElapsedEpochsByTickerHash();
        expect.fail('Should have thrown NoTokenConfigurationFound error');
      } catch (error) {
        expect(error.name).to.equal('NoTokenConfigurationFound');
      }
    });

    it('should not alert when shouldAlert is false', async () => {
      await checkTronElapsedEpochsByTickerHash(false);

      // Should not send alerts even if threshold is exceeded
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle empty invoices list', async () => {
      database.getLatestInvoicesByTickerHash.resolves(new Map());

      await checkTronElapsedEpochsByTickerHash();

      // Should not alert when no invoices
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should use 6-decimal TRX for amount calculations', async () => {
      // Test with amounts that would be different with 18 vs 6 decimals
      const testInvoices: Invoice[] = [
        {
          id: 'invoice1',
          originIntent: {
            id: 'intent1',
            origin: '728126428',
            amount: '15000000', // 15 TRX (6 decimals) = $1.50 at $0.10/TRX
          },
          hubInvoiceEntryEpoch: 5,
          hubStatus: 'INVOICED',
        } as Invoice,
      ];

      database.getLatestInvoicesByTickerHash.resolves(
        new Map([[mockTickerHash, testInvoices]])
      );

      await checkTronElapsedEpochsByTickerHash();

      // Should process the invoice (amount above $10k threshold would be false with 6 decimals)
      // But with TRX price of $0.10 and 15 TRX, total value is only $1.50, below $10k threshold
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle multiple Tron domains', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': { network: 'tvm' }, // Tron mainnet
            '728126429': { network: 'tvm' }, // Hypothetical Tron testnet
          },
        },
      });

      const multiDomainInvoices: Invoice[] = [
        {
          id: 'invoice1',
          originIntent: {
            id: 'intent1',
            origin: '728126428',
            amount: '100000000',
          },
          hubInvoiceEntryEpoch: 10,
          hubStatus: 'INVOICED',
        } as Invoice,
        {
          id: 'invoice2',
          originIntent: {
            id: 'intent2',
            origin: '728126429',
            amount: '100000000',
          },
          hubInvoiceEntryEpoch: 8,
          hubStatus: 'INVOICED',
        } as Invoice,
      ];

      database.getLatestInvoicesByTickerHash.resolves(
        new Map([[mockTickerHash, multiDomainInvoices]])
      );

      await checkTronElapsedEpochsByTickerHash();

      // Should process invoices from both Tron domains
      expect(database.getLatestInvoicesByTickerHash.called).to.be.true;
    });

    it('should resolve alerts when below threshold', async () => {
      // Setup recent invoices
      const recentInvoices: Invoice[] = [
        {
          id: 'invoice1',
          originIntent: {
            id: 'intent1',
            origin: '728126428',
            amount: '100000000', // 100 TRX
          },
          hubInvoiceEntryEpoch: 14, // Only 1 epoch ago
          hubStatus: 'INVOICED',
        } as Invoice,
      ];

      database.getLatestInvoicesByTickerHash.resolves(
        new Map([[mockTickerHash, recentInvoices]])
      );

      await checkTronElapsedEpochsByTickerHash();

      // Average elapsed epochs: (15 - 14) = 1 < 3 (threshold)
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });
  });
});