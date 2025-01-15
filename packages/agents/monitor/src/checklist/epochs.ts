import { BigNumber } from 'ethers';
import { createLoggingContext, getConfiguredTickerHashes, RequestContext } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { getCurrentEpoch } from '../helpers';
import { NoTokenConfigurationFound, Report, Severity } from '../types';
import { getAssetConfigByTickerHash, getTokenPrice } from '../libs';
import { resolveAlerts } from '../mockable';

const DEFAULT_INVOICE_PEEK = 100;
const DEFAULT_ELAPSED_EPOCHS_THRESHOLD = 3;
const DEFAULT_ELAPSED_EPOCHS_AMOUNT_THRESHOLD = 10_000;

/**
 * @notice Calculates the elapsed epochs for each ticker hash.
 * @dev Will alert on ticker if the average elapsed epochs is above the threshold.
 * @dev Using epochs because if the discount changes on the token config, alerts will
 *      automatically fire.
 * @dev This will only consider intents where discounts will or have been applied, will ignore
 *      intents that skip the `invoice` period and are immediately settled.
 */
export const checkElapsedEpochsByTickerHash = async (
  shouldAlert = true,
  _requestContext?: RequestContext,
): Promise<void> => {
  const {
    logger,
    config,
    adapters: { database },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(checkElapsedEpochsByTickerHash.name, _requestContext);
  logger.debug('Method started', requestContext, methodContext, { shouldAlert });

  // Get the ticker hashes
  const tickerHashes = getConfiguredTickerHashes(config.chains);
  logger.debug('Retrieved configured ticker hashes', requestContext, methodContext, { tickerHashes });

  // Get the latest `n` INVOICED hub invoices by the ticker hash
  const invoices = await database.getLatestInvoicesByTickerHash(tickerHashes, ['INVOICED'], DEFAULT_INVOICE_PEEK);
  logger.debug('Retrieved invoices for tickers', requestContext, methodContext, { peak: DEFAULT_INVOICE_PEEK });

  // Get the current epoch
  const currentEpoch = await getCurrentEpoch();
  logger.debug('Calculated current epoch', requestContext, methodContext, { currentEpoch });

  // Get all the token configs
  const tokenConfigs = await database.getTokens(tickerHashes);

  // Calculate the average discount by ticker hash, push if above thresholds
  const threshold = config.thresholds.averageElapsedEpochs ?? DEFAULT_ELAPSED_EPOCHS_THRESHOLD;
  const amountThreshold = config.thresholds.averageElapsedEpochsAlertAmount ?? DEFAULT_ELAPSED_EPOCHS_AMOUNT_THRESHOLD;
  logger.debug('Checking for invoices with elapsed epochs', requestContext, methodContext, { threshold, tickerHashes });

  const aboveThreshold: { tickerHash: string; averageElapsed: number }[] = [];
  for (const [tickerHash, existingInvoices] of invoices.entries()) {
    if (existingInvoices.length === 0) {
      continue;
    }
    const tokenConfig = tokenConfigs.find((t) => t.id.toLowerCase() === tickerHash.toLowerCase());
    if (!tokenConfig) {
      throw new NoTokenConfigurationFound(tickerHash, config.chains);
    }

    // assume price is same in any origin for same token.
    const domain = existingInvoices[0].originIntent.origin;
    const assetConfig = getAssetConfigByTickerHash(tickerHash, domain);
    const assetPrice = await getTokenPrice(domain, assetConfig);
    // scale up the assetPrice by 6 decimals and round. This makes us have 6 d.p. accuracy.
    const weightedAssetPrice = Math.round(assetPrice * 1000000);
    const assetPriceDecimals = 6;

    // We only check when their amount is greater than the alert threshold
    const filteredInvoices = existingInvoices.filter((i) => {
      // as origin might have different decimals, have to resolve the corresponding configs for correctly compare amount to threshold
      const assetConfig = getAssetConfigByTickerHash(tickerHash, i.originIntent.origin);
      const amount = BigNumber.from(i.originIntent.amount);
      const amountInUSD = amount.mul(weightedAssetPrice);
      const totalDecimals = (assetConfig.decimals + assetPriceDecimals).toFixed(0);
      const multiplier = BigNumber.from(10).pow(totalDecimals);
      const multipliedAmountThreshold = multiplier.mul(Math.round(amountThreshold));
      return amountInUSD.gte(multipliedAmountThreshold);
    });

    const averageElapsed =
      filteredInvoices.map((i) => currentEpoch - i.hubInvoiceEntryEpoch).reduce((prev, curr) => prev + curr, 0) /
      filteredInvoices.length;
    if (averageElapsed > threshold) {
      aboveThreshold.push({ tickerHash, averageElapsed });
    }
    logger.debug('Calculated average elapsed epochs', requestContext, methodContext, {
      averageElapsed,
      tickerHash,
      threshold,
      peak: DEFAULT_INVOICE_PEEK,
    });
  }

  const report: Report = {
    severity: Severity.Warning,
    type: 'AverageElapsedEpochsAboveThreshold',
    ids: aboveThreshold.map((t) => t.tickerHash),
    reason: `Average elapsed epochs above thresholds: \n ${aboveThreshold.map((a) => ` - ticker: ${a.tickerHash}, average: ${a.averageElapsed}`).join('\n')}`,
    timestamp: Date.now(),
    logger,
    env: config.environment,
  };

  if (!aboveThreshold.length) {
    await resolveAlerts(report, logger, config, requestContext);
    logger.info('Average elapsed epochs below threshold', requestContext, methodContext, { tickerHashes });
    return;
  }

  logger.warn('Average elapsed epochs above threshold', requestContext, methodContext, { report });

  if (!shouldAlert) {
    return;
  }

  // TODO: only push alert after sufficient testing
  // await sendAlerts(report, logger, config, requestContext);
};
