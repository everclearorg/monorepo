import { keccak256, toUtf8Bytes } from 'ethers/lib/utils';
import { SinonStub, stub, SinonStubbedInstance } from 'sinon';

import * as PriceLib from '../../src/libs/price';
import * as IntentHelpers from '../../src/helpers/intent';
import { expect, Logger } from '@chimera-monorepo/utils';
import { mock, getContextStub } from '../globalTestHook';
import { Database } from '@chimera-monorepo/database';
import { createProcessEnv } from '../mock';
import { checkElapsedEpochsByTickerHash } from '../../src/checklist/epochs';
import { NoTokenConfigurationFound } from '../../src/types';
import * as Mockable from '../../src/mockable';

describe('Checklist - epochs', () => {
  let database: SinonStubbedInstance<Database>;
  let getCurrentEpochStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;
  let alertStub: SinonStub;
  let priceStub: SinonStub;
  let config;

  describe('#checkElapsedEpochsByTickerHash', () => {
    const tickerHashes = [keccak256(toUtf8Bytes('ETH')), keccak256(toUtf8Bytes('WETH'))];
    const invoices = new Map();

    beforeEach(() => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
      });
      config = { ...mock.config() };
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
      tickerHashes.forEach((tickerHash) => {
        invoices.set(tickerHash, [
          mock.invoice({ hubInvoiceTickerHash: tickerHash, hubInvoiceEntryEpoch: 1_000, hubStatus: "INVOICED" }),
        ]);
      })
      database = mock.instances.database() as SinonStubbedInstance<Database>;
      database.getLatestInvoicesByTickerHash.resolves(invoices);
      database.getTokens.resolves(
        tickerHashes.map(
          (tickerHash) => ({
            id: tickerHash,
            feeAmounts: [],
            feeRecipients: [],
            maxDiscountBps: 10_000,
            discountPerEpoch: 1_000,
            prioritizedStrategy: '0',
          })
        )
      );

      getCurrentEpochStub = stub(IntentHelpers, 'getCurrentEpoch');
      getCurrentEpochStub.resolves(2_000);

      alertStub = stub(Mockable, 'sendAlerts');

      priceStub = stub(PriceLib, 'getTokenPrice');
      priceStub.resolves(100.01);
    });

    it('should fail if db.getLatestInvoicesByTickerHash fails', async () => {
      database.getLatestInvoicesByTickerHash.rejects(new Error('fail'));
      await expect(checkElapsedEpochsByTickerHash(false)).to.be.rejectedWith('fail');
    });

    it('should fail if getCurrentEpoch fails', async () => {
      getCurrentEpochStub.rejects(new Error('fail'));
      await expect(checkElapsedEpochsByTickerHash(false)).to.be.rejectedWith('fail');
    });

    it('should fail if db.getTokens fails', async () => {
      database.getTokens.rejects(new Error('fail'));
      await expect(checkElapsedEpochsByTickerHash(false)).to.be.rejectedWith('fail');
    });

    it('should fail if the tokenConfig is not found for registered ticker hash', async () => {
      database.getTokens.resolves([]);
      await expect(checkElapsedEpochsByTickerHash(false)).to.be.rejectedWith(NoTokenConfigurationFound);
    });

    it('should work if no thresholds exceeded', async () => {
      config.thresholds.averageElapsedEpochs = 1_000;
      await checkElapsedEpochsByTickerHash(false);
      expect(logger.info.calledWith('Average elapsed epochs below threshold')).to.be.true;
    });

    it('should alert if thresholds exceeded', async () => {
      config.thresholds.averageElapsedEpochs = 0;
      config.thresholds.averageElapsedEpochsAlertAmount = 0;
      await checkElapsedEpochsByTickerHash(true);
      expect(logger.info.calledWith('Average elapsed epochs below threshold')).to.be.false;
      // TODO: enable the alert test when its back enabled after testing
      // expect(alertStub.calledOnce).to.be.true;
      // const [report] = alertStub.firstCall.args;
      // expect(report).to.containSubset({
      //   severity: Severity.Warning,
      //   type: 'AverageElapsedEpochsAboveThreshold',
      //   ids: tickerHashes,
      //   reason: 'Average elapsed epochs above thresholds: \n' + `  - ticker: ${tickerHashes[0]}, average: 1000\n` + ` - ticker: ${tickerHashes[1]}, average: 1000`,
      //   logger,
      //   env: 'staging',
      // });
    });

    it('should not alert if amount threshold not exceeded', async () => {
      config.thresholds.averageElapsedEpochs = 6;
      config.thresholds.averageElapsedEpochsAlertAmount = 100;
      priceStub.resolves(100);
      tickerHashes.forEach((tickerHash) => {
        invoices.set(tickerHash, [
          mock.invoice({ 
            hubInvoiceTickerHash: tickerHash,
            hubInvoiceEntryEpoch: 1_000,
            hubStatus: "INVOICED",
            originIntent: mock.originIntent({ amount: '900000000000000000' }) // 18 decimals, corresponding to 0.9 ETH, = 90 USD here.
          }),
        ]);
      })
      await checkElapsedEpochsByTickerHash(true);
      expect(logger.info.calledWith('Average elapsed epochs below threshold')).to.be.true;
    });

    it('should alert if amount threshold exceeded', async () => {
      config.thresholds.averageElapsedEpochs = 6;
      config.thresholds.averageElapsedEpochsAlertAmount = 10;
      priceStub.resolves(100);
      tickerHashes.forEach((tickerHash) => {
        invoices.set(tickerHash, [
          mock.invoice({
            hubInvoiceTickerHash: tickerHash,
            hubInvoiceEntryEpoch: 1_000,
            hubStatus: "INVOICED",
            originIntent: mock.originIntent({ origin: "1338", amount: "1000000000000000000" }) // 18 decimals corresponding to 1 ETH.
          }),
        ]);
      })
      await checkElapsedEpochsByTickerHash(true);
      expect(priceStub.getCall(0).args[0]).to.be.eq("1338");
      expect(logger.info.calledWith('Average elapsed epochs below threshold')).to.be.false;
      // TODO: enable the alert test when its back enabled after testing
      // expect(alertStub.calledOnce).to.be.true;
      // const [report] = alertStub.firstCall.args;
      // expect(report).to.containSubset({
      //   severity: Severity.Warning,
      //   type: 'AverageElapsedEpochsAboveThreshold',
      //   ids: tickerHashes,
      //   reason: 'Average elapsed epochs above thresholds: \n' + `  - ticker: ${tickerHashes[0]}, average: 1000\n` + ` - ticker: ${tickerHashes[1]}, average: 1000`,
      //   logger,
      //   env: 'staging',
      // });
    });
  });
});
