import {
  createLoggingContext,
  domainToChainId,
  getConfiguredTickers,
  getTickerHashes,
  mkBytes32,
} from '@chimera-monorepo/utils';
import { sendWithRelayerWithBackup } from '@chimera-monorepo/adapters-relayer';
import { chainWrapper } from '@chimera-monorepo/utils';

import { getContext } from '../../context';

export type InvoiceList = {
  head: string;
  tail: string;
  nonce: bigint;
  length: bigint;
  nodes: unknown;
};

// Used to parameterize the processDepositsAndInvoices method to avoid gas limit issues.
// NOTE: 0-value for maxes means no limit / process all possible.
// TODO: experimentally derive proper constants here, likely interdependent.
const MAX_EPOCHS_TO_PROCESS = 0; // 250;
const MAX_DEPOSITS_TO_PROCESS = 0; // 100;
const MAX_INVOICES_TO_PROCESS = 0; // 35;

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

  for (const tickerHash of tickerHashes) {
    const registeredConfig = configued.find((a) => a.token === tickerHash.toLowerCase());
    // Check that ticker hash is configured onchain as well as in chaindata
    if (!registeredConfig) {
      logger.warn('Asset not registered', requestContext, methodContext, { tickerHash });
      continue;
    }
    const encodedDataForInvoices = chainWrapper.encodeFunctionData({
      abi: abis.hub.everclear,
      functionName: 'invoices',
      args: [tickerHash],
    });
    const encodedDataForInvoicesRes = await chainservice.readTx(
      {
        to: hub.deployments.everclear,
        domain: +hub.domain,
        data: encodedDataForInvoices,
        funcSig: 'invoices(bytes32)',
      },
      'latest',
    );

    const invoices = chainWrapper.decodeFunctionResult({
      abi: abis.hub.everclear,
      functionName: 'invoices',
      data: encodedDataForInvoicesRes as `0x${string}`,
    }) as unknown as InvoiceList;

    const encodedDataForLastClosedEpoch = chainWrapper.encodeFunctionData({
      abi: abis.hub.everclear,
      functionName: 'lastClosedEpochsProcessed',
      args: [tickerHash],
    });
    const encodedDataForLastClosedEpochRes = await chainservice.readTx(
      {
        to: hub.deployments.everclear,
        domain: +hub.domain,
        data: encodedDataForLastClosedEpoch,
        funcSig: 'lastClosedEpochsProcessed(bytes32)',
      },
      'latest',
    );
    const lastClosedEpochProcessed = chainWrapper.decodeFunctionResult({
      abi: abis.hub.everclear,
      functionName: 'lastClosedEpochsProcessed',
      data: encodedDataForLastClosedEpochRes as `0x${string}`,
    }) as unknown as bigint;

    const encodedDataForGetCurrentEpoch = chainWrapper.encodeFunctionData({
      abi: abis.hub.everclear,
      functionName: 'getCurrentEpoch',
      args: [],
    });
    const encodedDataForGetCurrentEpochRes = await chainservice.readTx(
      {
        to: hub.deployments.everclear,
        domain: +hub.domain,
        data: encodedDataForGetCurrentEpoch,
        funcSig: 'getCurrentEpoch()',
      },
      'latest',
    );
    const currentEpoch = chainWrapper.decodeFunctionResult({
      abi: abis.hub.everclear,
      functionName: 'getCurrentEpoch',
      data: encodedDataForGetCurrentEpochRes as `0x${string}`,
    });

    const lastClosedEpoch = Number(currentEpoch) > 0 ? Number(currentEpoch) - 1 : 0;
    // Check if there are deposits to process in unprocessed epochs across all spokes
    let hasDepositsToProcess = false;
    if (lastClosedEpoch > +lastClosedEpochProcessed.toString()) {
      for (const spokeDomain of spokes) {
        for (let epoch = +lastClosedEpochProcessed.toString() + 1; epoch <= lastClosedEpoch; epoch++) {
          const encodedDataForDepositsAvailable = chainWrapper.encodeFunctionData({
            abi: abis.hub.everclear,
            functionName: 'depositsAvailableInEpoch',
            args: [epoch, +spokeDomain, tickerHash],
          });
          const encodedDataForDepositsAvailableRes = await chainservice.readTx(
            {
              to: hub.deployments.everclear,
              domain: +hub.domain,
              data: encodedDataForDepositsAvailable,
              funcSig: 'depositsAvailableInEpoch(uint256,uint32,bytes32)',
            },
            'latest',
          );
          const depositsAvailable = chainWrapper.decodeFunctionResult({
            abi: abis.hub.everclear,
            functionName: 'depositsAvailableInEpoch',
            data: encodedDataForDepositsAvailableRes as `0x${string}`,
          }) as unknown as bigint;
          if (+depositsAvailable.toString() > 0) {
            hasDepositsToProcess = true;
            break;
          }
        }
        if (hasDepositsToProcess) break;
      }
    }
    const hasInvoicesToProcess = invoices.head != mkBytes32();
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
      },
    );
    // Only call relayer if there are invoices to process OR deposits to process
    if (!hasInvoicesToProcess && !hasDepositsToProcess) {
      logger.debug(
        'Skip to call the processDepositsAndInvoices method - no invoices or deposits to process',
        requestContext,
        methodContext,
      );
      continue;
    }

    const encodedDataToProcess = chainWrapper.encodeFunctionData({
      abi: abis.hub.everclear,
      functionName: 'processDepositsAndInvoices',
      args: [tickerHash, MAX_EPOCHS_TO_PROCESS, MAX_DEPOSITS_TO_PROCESS, MAX_INVOICES_TO_PROCESS],
    });
    logger.info('Processing deposits and invoices', requestContext, methodContext, {
      tickerHash,
      maxEpochs: MAX_EPOCHS_TO_PROCESS,
      maxDeposits: MAX_DEPOSITS_TO_PROCESS,
      maxInvoices: MAX_INVOICES_TO_PROCESS,
      encodedDataToProcess,
    });

    // Call the `processDepositsAndInvoices` method on the hub
    const { taskId, relayerType } = await sendWithRelayerWithBackup(
      domainToChainId(hub.domain),
      hub.domain,
      hub.deployments.everclear,
      encodedDataToProcess,
      '0',
      'processDepositsAndInvoices(bytes32,uint256,uint256,uint256)',
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
