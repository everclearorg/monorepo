import { createLoggingContext, getNtpTimeSeconds, Invoice } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { Severity, Report } from '../../types';
import { getCurrentEpoch, getCustodiedAssetsFromHubContract } from '../../helpers';
import { BigNumber } from 'ethers';
import { resolveAlerts, sendAlerts } from '../../mockable';

export const checkInvoices = async () => {
  const {
    logger,
    config,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkInvoices.name);
  logger.info('Checking oldest invoices', requestContext, methodContext);
  const invoicedIntents = await database.getHubIntentsByStatus('INVOICED', [config.hub.domain]);
  const invoices = await database.getHubInvoicesByIntentIds(invoicedIntents.map((it) => it.id));

  const curTime = getNtpTimeSeconds();
  const reportInvoiceNotProcessedYet: Report = {
    severity: Severity.Warning,
    type: 'InvoiceNotProcessedYet',
    ids: [],
    reason: '',
    timestamp: Date.now(),
    logger: logger,
    env: config.environment,
  };

  if (invoicedIntents.length === 0) {
    // Resolve already dispatched alerts of the type
    await resolveAlerts(reportInvoiceNotProcessedYet, logger, config, requestContext, true);
    logger.info(
      'No invoiced intents found. Resolved all alerts of type InvoiceNotProcessedYet',
      requestContext,
      methodContext,
    );
  } else {
    await Promise.allSettled(
      invoicedIntents.map(async (intent) => {
        if (!intent.addedTimestamp) return;
        reportInvoiceNotProcessedYet.ids = [intent.id];
        reportInvoiceNotProcessedYet.reason = `${requestContext.origin}, The invoice ${intent.id} hasn't been processed for over a given time period: ${config.thresholds.maxInvoiceProcessingTime!}. delayedTime: ${curTime - intent.addedTimestamp}`;
        if (curTime > intent.addedTimestamp + config.thresholds.maxInvoiceProcessingTime!) {
          // Send alerts
          logger.warn(`The invoice hasn't been processed for over a given time period`, requestContext, methodContext, {
            intentId: intent.id,
            addedTimestamp: intent.addedTimestamp,
            threshold: config.thresholds.maxInvoiceProcessingTime!,
          });

          return sendAlerts(reportInvoiceNotProcessedYet, logger, config, requestContext);
        } else {
          return resolveAlerts(reportInvoiceNotProcessedYet, logger, config, requestContext);
        }
      }),
    );
  }

  const currentEpoch = await getCurrentEpoch();
  await Promise.allSettled(
    invoices.map(async (invoice) => {
      const report = {
        severity: Severity.Warning,
        type: 'InvoiceDiscountedMoreThan5Times',
        ids: [invoice.id],
        reason: `${requestContext.origin}, The invoice ${invoice.intentId} got discounted more than 5 times. entryEpoch: ${invoice.entryEpoch}, currentEpoch: ${currentEpoch}`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      if (currentEpoch > invoice.entryEpoch + 5) {
        // Send alerts
        logger.warn(`The invoice got discounted more than 5 times`, requestContext, methodContext, {
          invoiceId: invoice.id,
          intentId: invoice.intentId,
          entryEpoch: invoice.entryEpoch,
          currentEpoch,
        });

        return sendAlerts(report, logger, config, requestContext);
      } else {
        return resolveAlerts(report, logger, config, requestContext);
      }
    }),
  );
};

export const checkInvoiceAmount = async () => {
  const {
    logger,
    config,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkInvoices.name);
  logger.info('Checking invoiced intents', requestContext, methodContext);

  const invoices = await database.getInvoicesByStatus('INVOICED');

  // Regroup invoices into a map keyed on `origin_output_asset`
  const invoicesMap = invoices.reduce(
    (map, invoice) => {
      const key = invoice.originIntent.outputAsset;
      if (!map[key]) {
        map[key] = [];
      }
      map[key].push(invoice);
      return map;
    },
    {} as Record<string, Invoice[]>,
  );

  // Get custodied assets for each key in invoicesMap
  const custodiedAssets = await Promise.all(
    Object.keys(invoicesMap).map(async (key) => {
      const custodied = await getCustodiedAssetsFromHubContract(key);
      return { key, custodied };
    }),
  ).then((results) =>
    results.reduce(
      (map, { key, custodied }) => {
        map[key] = BigNumber.from(custodied);
        return map;
      },
      {} as Record<string, BigNumber>,
    ),
  );

  // Get the current epoch
  const currentEpoch = await getCurrentEpoch();
  logger.debug('Calculated current epoch', requestContext, methodContext, { currentEpoch });

  // Compare hub_invoice_amount with custodied amount for each key
  const filteredInvoices = Object.entries(invoicesMap).reduce((acc, [key, invoices]) => {
    const custodiedAmount = custodiedAssets[key];
    if (custodiedAmount !== undefined) {
      const filtered = invoices.filter(
        (invoice) =>
          BigNumber.from(invoice.hubInvoiceAmount).lt(custodiedAmount) && invoice.hubInvoiceEntryEpoch < currentEpoch, // Not in the current epoch
      );
      acc.push(...filtered);
    }
    return acc;
  }, [] as Invoice[]);

  // Invoices invoiced amount is lesser than custodied amount
  const filteredInvoiceIds = filteredInvoices.map((invoice) => invoice.id);

  const report = {
    severity: Severity.Warning,
    type: 'InvoiceAmountLessThanCustodiedAmount',
    ids: filteredInvoiceIds,
    reason: `Invoices ${filteredInvoiceIds} haven't been processed`,
    timestamp: Date.now(),
    logger: logger,
    env: config.environment,
  };

  if (filteredInvoices.length === 0) {
    await resolveAlerts(report, logger, config, requestContext, true);
    logger.info(`Resolved all alerts of type ${report.type}`, requestContext, methodContext);
  } else {
    logger.warn(`Invoices with amounts less than the custodied amount for assethash`, requestContext, methodContext, {
      filteredInvoiceIds,
    });

    return sendAlerts(report, logger, config, requestContext, true);
  }
};
