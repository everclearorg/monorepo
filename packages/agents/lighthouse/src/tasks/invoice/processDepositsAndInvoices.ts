import { Interface } from 'ethers/lib/utils';
import {
  createLoggingContext,
  domainToChainId,
  getConfiguredTickers,
  getTickerHashes,
  mkBytes32,
} from '@chimera-monorepo/utils';
import { sendWithRelayerWithBackup } from '@chimera-monorepo/adapters-relayer';

import { getContext } from '../../context';

import { BigNumber } from 'ethers';

export type InvoiceList = {
  head: string;
  tail: string;
  nonce: BigNumber;
  length: BigNumber;
  nodes: unknown;
};

// Used to parameterize the processDepositsAndInvoices method to avoid gas limit issues.
// NOTE: 0-value for maxes means no limit / process all possible.
// TODO: experimentally derive proper constants here, likely interdependent.
const MAX_EPOCHS_TO_PROCESS = 0; // 250;
const MAX_DEPOSITS_TO_PROCESS = 0; // 100;
const MAX_INVOICES_TO_PROCESS = 0; // 35;

export const MAX_UNPROCESSED_EPOCHS_COUNT = 100;

export const processDepositsAndInvoices = async () => {
  const {
    config: { chains, hub, abis },
    logger,
    adapters: { chainservice, relayers, database },
  } = getContext();

  // Create logging context
  const { requestContext, methodContext } = createLoggingContext(processDepositsAndInvoices.name);

  // Get the spoke domains
  const domains = Object.keys(chains);
  const spokes = domains.filter((d) => d !== hub.domain);
  logger.debug('Method start', requestContext, methodContext, {
    spokes,
    domains,
    hubDomain: hub.domain,
    assets: chains.assets,
  });

  // Get all the configured asset tickers excluding native assets
  const tickers = getConfiguredTickers(chains, true);
  const tickerHashes = getTickerHashes(tickers);
  logger.info('Configured tickers', requestContext, methodContext, { tickers, tickerHashes });

  // Check that the assets exist in carto (i.e. have been registered)
  const configued = await database.getAssets(tickerHashes);

  const iface = new Interface(abis.hub.everclear);
  for (const tickerHash of tickerHashes) {
    const registeredConfig = configued.find((a) => a.token === tickerHash.toLowerCase());
    // Check that ticker hash is configured onchain as well as in chaindata
    if (!registeredConfig) {
      logger.warn('Asset not registered', requestContext, methodContext, { tickerHash });
      continue;
    }
    const encodedDataForInvoices = iface.encodeFunctionData('invoices', [tickerHash]);
    const encodedDataForInvoicesRes = await chainservice.readTx(
      {
        to: hub.deployments.everclear,
        domain: +hub.domain,
        data: encodedDataForInvoices,
        funcSig: iface.getFunction('invoices').format(),
      },
      'latest',
    );

    const invoices = iface.decodeFunctionResult('invoices', encodedDataForInvoicesRes) as unknown as InvoiceList;

    const encodedDataForLastClosedEpoch = iface.encodeFunctionData('lastClosedEpochsProcessed', [tickerHash]);
    const encodedDataForLastClosedEpochRes = await chainservice.readTx(
      {
        to: hub.deployments.everclear,
        domain: +hub.domain,
        data: encodedDataForLastClosedEpoch,
        funcSig: iface.getFunction('lastClosedEpochsProcessed').format(),
      },
      'latest',
    );
    const [lastClosedEpochsProcessed] = iface.decodeFunctionResult(
      'lastClosedEpochsProcessed',
      encodedDataForLastClosedEpochRes,
    );
    const lastClosedEpochProcessed = +lastClosedEpochsProcessed.toString();

    const encodedDataForGetCurrentEpoch = iface.encodeFunctionData('getCurrentEpoch', []);
    const encodedDataForGetCurrentEpochRes = await chainservice.readTx(
      {
        to: hub.deployments.everclear,
        domain: +hub.domain,
        data: encodedDataForGetCurrentEpoch,
        funcSig: iface.getFunction('getCurrentEpoch').format(),
      },
      'latest',
    );
    const [currentEpoch] = iface.decodeFunctionResult('getCurrentEpoch', encodedDataForGetCurrentEpochRes);

    const lastClosedEpoch = currentEpoch > 0 ? currentEpoch - 1 : 0;
    // Check if there are deposits to process in unprocessed epochs across all spokes
    let hasDepositsToProcess = false;
    let unprocessedEpochsCount = 0;
    if (lastClosedEpoch > lastClosedEpochProcessed) {
      unprocessedEpochsCount = lastClosedEpoch - lastClosedEpochProcessed;
      for (const spokeDomain of spokes) {
        for (let epoch = lastClosedEpochProcessed + 1; epoch <= lastClosedEpoch; epoch++) {
          const encodedDataForDepositsAvailable = iface.encodeFunctionData('depositsAvailableInEpoch', [
            epoch,
            +spokeDomain,
            tickerHash,
          ]);
          const encodedDataForDepositsAvailableRes = await chainservice.readTx(
            {
              to: hub.deployments.everclear,
              domain: +hub.domain,
              data: encodedDataForDepositsAvailable,
              funcSig: iface.getFunction('depositsAvailableInEpoch').format(),
            },
            'latest',
          );
          const [depositsAvailable] = iface.decodeFunctionResult(
            'depositsAvailableInEpoch',
            encodedDataForDepositsAvailableRes,
          );
          if (+depositsAvailable.toString() > 0) {
            hasDepositsToProcess = true;
            break;
          }
        }
        if (hasDepositsToProcess) break;
      }
    }
    const hasInvoicesToProcess = invoices.head != mkBytes32();

    // Processed last MAX_UNPROCESSED_EPOCHS_COUNT epochs even if there are no deposits/invoices to avoid
    // out of gas transaction reverts when the number of epochs to process is too large.
    const hitUnprocessedEpochsLimit = unprocessedEpochsCount >= MAX_UNPROCESSED_EPOCHS_COUNT;

    logger.debug(
      'Checking the possibility of calling the processDepositsAndInvoices method',
      requestContext,
      methodContext,
      {
        tickerHash,
        invoices: invoices.length,
        lastClosedEpochProcessed: lastClosedEpochProcessed.toString(),
        currentEpoch,
        lastClosedEpoch,
        hasInvoicesToProcess,
        hasDepositsToProcess,
        unprocessedEpochsCount,
        hitUnprocessedEpochsLimit,
      },
    );

    // Call relayer if there are invoices to process OR deposits to process OR there are unprocessed epochs
    if (!hasInvoicesToProcess && !hasDepositsToProcess && !hitUnprocessedEpochsLimit) {
      logger.debug(
        'Skip to call the processDepositsAndInvoices method - no invoices or deposits to process or hit unprocessed epochs limit',
        requestContext,
        methodContext,
      );
      continue;
    }

    const encodedDataToProcess = iface.encodeFunctionData('processDepositsAndInvoices', [
      tickerHash,
      MAX_EPOCHS_TO_PROCESS,
      MAX_DEPOSITS_TO_PROCESS,
      MAX_INVOICES_TO_PROCESS,
    ]);
    logger.info('Processing deposits and invoices', requestContext, methodContext, {
      tickerHash,
      maxEpochs: MAX_EPOCHS_TO_PROCESS,
      maxDeposits: MAX_DEPOSITS_TO_PROCESS,
      maxInvoices: MAX_INVOICES_TO_PROCESS,
      encodedDataToProcess,
      invoicesCount: invoices.length.toString(),
      unprocessedEpochsCount,
    });

    // Call the `processDepositsAndInvoices` method on the hub
    const { taskId, relayerType } = await sendWithRelayerWithBackup(
      domainToChainId(hub.domain),
      hub.domain,
      hub.deployments.everclear,
      encodedDataToProcess,
      '0',
      iface.getFunction('processDepositsAndInvoices').format(),
      relayers,
      chainservice,
      logger,
      requestContext,
    );

    logger.info('Submitted a tx to process deposits and invoices to relayer', requestContext, methodContext, {
      taskId,
      relayerType,
      tickerHash,
    });
  }
};
