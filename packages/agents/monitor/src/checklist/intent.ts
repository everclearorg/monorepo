import { createLoggingContext, RequestContext, TIntentStatus } from '@chimera-monorepo/utils';
import { BigNumber } from 'ethers';
import { getContext } from '../context';
import { getContract } from '../mockable';
import { IntentLiquiditySummary, IntentStatusSummary, MissingDeployments } from '../types';
import {
  getAssetFromContract,
  getCustodiedAssetsFromHubContract,
  getRegisteredAssetHashFromContract,
  getTokenFromContract,
  convertChainToReadableIntentStatus,
  getIntentContextFromContract,
  getCurrentEpoch,
} from '../helpers';

/**
 * Queries the status of an intent from the chain. If there is a `messageId` in the subgraph,
 * then the intent status is `Dispatched`, otherwise it is the onchain status.
 */
export const checkIntentStatus = async (
  originDomain: string,
  destinationDomains: string[],
  intentId: string,
): Promise<IntentStatusSummary> => {
  const {
    config,
    adapters: { chainreader, subgraph },
  } = getContext();

  const originEverclear = config.chains[originDomain]?.deployments?.everclear;
  const hubEverclear = config.hub.deployments?.everclear;
  if (!originEverclear || !hubEverclear) {
    const domain = !originEverclear ? `Origin-${originDomain}` : `Hub-${config.hub.domain}`;
    throw new MissingDeployments({
      domain: domain,
      chains: config.chains,
    });
  }

  // Get the destination everclears.
  const destinationEverclears = destinationDomains.map((domain) => {
    const destinationEverclear = config.chains[domain]?.deployments?.everclear;
    if (!destinationEverclear) {
      throw new MissingDeployments({
        domain: `Destination-${domain}`,
        chains: config.chains,
      });
    }
    return destinationEverclear;
  });

  const methodArgs = [
    {
      address: originEverclear,
      contract: getContract(originEverclear, config.abis.spoke.everclear),
      domain: originDomain,
      methodName: 'status',
    },
    {
      address: hubEverclear,
      contract: getContract(hubEverclear, config.abis.hub.everclear),
      domain: config.hub.domain,
      methodName: 'contexts',
    },
  ].concat(
    ...destinationEverclears.map((destinationEverclear, idx) => ({
      address: destinationEverclear,
      contract: getContract(destinationEverclear, config.abis.spoke.everclear),
      domain: destinationDomains[idx],
      methodName: 'status',
    })),
  );

  const intentStatusRes = await Promise.all(
    methodArgs.map(async (methodArg) => {
      const { address, contract, domain, methodName } = methodArg;

      const encodedIntentStatusData = contract.interface.encodeFunctionData(methodName, [intentId]);
      const encodedIntentStatusDataRes = await chainreader.readTx(
        { to: address, domain: +domain, data: encodedIntentStatusData },
        'latest',
      );
      const [decoded] = contract.interface.decodeFunctionResult(methodName, encodedIntentStatusDataRes);
      return {
        domain,
        status:
          typeof decoded == 'number'
            ? convertChainToReadableIntentStatus(decoded)
            : convertChainToReadableIntentStatus(decoded.status),
      };
    }),
  );

  const originIntentStatus = intentStatusRes.find((it) => it.domain == originDomain)!.status;
  const hubIntentStatus = intentStatusRes.find((it) => it.domain == config.hub.domain)!.status;
  const destinationIntentStatuses = intentStatusRes.filter((it) => destinationDomains.includes(it.domain));

  // Retrieve intent records from subgraph.
  const [originIntent, hubIntent, ...destinationIntents] = await Promise.all([
    subgraph.getOriginIntentById(originDomain, intentId),
    subgraph.getHubIntentById(config.hub.domain, intentId),
    ...destinationDomains.map((domain) => subgraph.getDestinationIntentById(domain, intentId)),
  ]);

  return {
    origin: originIntent?.messageId ? TIntentStatus.Dispatched : originIntentStatus,
    hub: hubIntent?.messageId ? TIntentStatus.Dispatched : hubIntentStatus,
    destinations: Object.fromEntries(
      destinationIntentStatuses.map((d) => [
        d.domain,
        destinationIntents.find((it) => it?.destination === d.domain)?.messageId ? TIntentStatus.Dispatched : d.status,
      ]),
    ),
  };
};

export const checkIntentLiquidity = async (
  originDomain: string,
  intentId: string,
  _requestContext?: RequestContext,
): Promise<IntentLiquiditySummary> => {
  const {
    config,
    logger,
    adapters: { subgraph },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(checkIntentLiquidity.name, _requestContext);
  logger.debug('Checking intent liquidity', requestContext, methodContext, { originDomain, intentId });

  // First, get the intent information from the origin subgraph. If this is not defined,
  // Then we can't proceed with the liquidity check.
  const originIntent = await subgraph.getOriginIntentById(originDomain, intentId);
  if (!originIntent) {
    // NOTE: in the future, could query events by block number. this would increase the latency
    // substantially as we would likely have to iterate through a large block range.
    return {
      notice: 'Intent not found in origin subgraph.',
      tickerHash: '',
      elapsedEpochs: 0,
      discount: 0,
      invoiceValue: '0',
      settlementValue: '0',
      unclaimed: {},
    };
  }
  logger.debug('Retrieved originIntent', requestContext, methodContext, { originIntent });

  // Lookup the ticker hash for the input asset.
  // If the ticker is not registered, return empty liquidity summary (unsupported intent).
  const assetConfig = await getAssetFromContract(originIntent.inputAsset, originDomain);
  if (!assetConfig.approval) {
    // Unsupported asset, no liquidity required. Must be reverted to origin.
    return {
      notice: 'Unsupported asset. Intent is unsupported.',
      tickerHash: assetConfig.id,
      elapsedEpochs: 0,
      discount: 0,
      invoiceValue: originIntent.amount,
      settlementValue: originIntent.amount,
      unclaimed: {},
    };
  }
  logger.debug('Retrieved asset config', requestContext, methodContext, { assetConfig });

  // Lookup the token config by ticker hash.
  const tokenConfig = await getTokenFromContract(assetConfig.id);
  logger.debug('Retrieved token config', requestContext, methodContext, { tokenConfig });

  // Look up all the possible destination domain asset hashes.
  const destinationAssetHashes = await Promise.all(
    originIntent.destinations.map(async (dest) => ({
      domain: dest,
      assetHash: await getRegisteredAssetHashFromContract(assetConfig.id, dest),
    })),
  );
  logger.debug('Retrieved eligible asset hashes', requestContext, methodContext, { destinationAssetHashes });

  // Get the unclaimed balance on the hub for the available asset hashes.
  const unclaimedList = await Promise.all(
    destinationAssetHashes.map(async ({ domain, assetHash }) => {
      return {
        domain,
        custodied: await getCustodiedAssetsFromHubContract(assetHash),
      };
    }),
  );
  logger.debug('Retrieved unclaimed asset balances', requestContext, methodContext, { unclaimed: unclaimedList });

  // Look up the intent context on the hub.
  const context = await getIntentContextFromContract(intentId);
  logger.debug('Retrieved intent context', requestContext, methodContext, { context });

  // Handle the case where the intent does not yet exist on the hub (no discount, expected protocol
  // fees, elapsedEpochs = 0, etc.)
  if (context.intentStatus === TIntentStatus.None) {
    return {
      notice: 'Intent not yet registered on the hub.',
      tickerHash: assetConfig.id,
      elapsedEpochs: 0,
      discount: 0,
      invoiceValue: originIntent.amount,
      settlementValue: originIntent.amount,
      unclaimed: Object.fromEntries(
        unclaimedList.map(({ domain, custodied }) => [domain, { custodied, required: '0' }]),
      ),
    };
  }

  // Attempt to get the hub intent
  const hubIntent = await subgraph.getHubIntentById(config.hub.domain, intentId);
  logger.debug('Retrieved hub intent', requestContext, methodContext, { hubIntent });

  // Attempt to get the invoice from the hub.
  const invoice = await subgraph.getHubInvoiceById(config.hub.domain, intentId);

  // Calculate the original invoice amount from the context
  const invoiceValue = invoice?.amount
    ? BigNumber.from(invoice.amount)
    : BigNumber.from(context.amountAfterFees).add(context.pendingRewards);
  const settlementValue = hubIntent?.settlementAmount ?? invoiceValue.toString();
  logger.debug('Calculated invoice and settlement value', requestContext, methodContext, {
    invoiceValue: invoiceValue.toString(),
    settlementValue,
  });

  // Get the elapsed epochs.
  const currentEpoch = await getCurrentEpoch();
  const settledEpoch = hubIntent?.settlementEpoch ?? currentEpoch;
  const elapsedEpochs = invoice?.entryEpoch ? settledEpoch - invoice.entryEpoch : 0;
  logger.debug('Calculated elapsed epochs', requestContext, methodContext, {
    elapsedEpochs,
    currentEpoch,
    settledEpoch,
  });

  // Define the discount (take the configured max into consideration).
  const discount = Math.min(elapsedEpochs * tokenConfig.discountPerEpoch, tokenConfig.maxDiscountBps);
  const discounted = invoiceValue.sub(invoiceValue.mul(discount).div(100_000));

  // Define unclaimed balances.
  const unclaimed = Object.fromEntries(
    unclaimedList.map(({ domain, custodied }) => {
      const requiredWithFees = invoiceValue
        .sub(custodied)
        .mul(100_000)
        .div(100_000 - tokenConfig.feeAmounts.reduce((acc, next) => acc + +next, 0));
      return [domain, { custodied, required: invoiceValue.lte(custodied) ? '0' : requiredWithFees.toString() }];
    }),
  );

  // If the intent is _not_ in the `Invoiced` state, the discounts are not ongoing.
  if (context.intentStatus !== TIntentStatus.Invoiced) {
    return {
      notice: 'Discounts not being applied. Status: ' + context.intentStatus,
      tickerHash: assetConfig.id,
      elapsedEpochs,
      discount,
      invoiceValue: invoiceValue.toString(),
      settlementValue,
      unclaimed,
    };
  }

  // If the intent does exist on the hub, calculate the current epoch and entry epoch.
  // NOTE: entry epoch is pulled from the subgraph, current epoch is calculated from the chain.
  if (!invoice) {
    return {
      notice: 'Invoice not found in subgraph.',
      tickerHash: assetConfig.id,
      elapsedEpochs: 0,
      discount: 0,
      invoiceValue: invoiceValue.toString(),
      settlementValue,
      unclaimed,
    };
  }

  // Calculate the invoice value by applying fees, discount, and pending rewards.
  return {
    notice: 'Invoice waiting for settlement.',
    tickerHash: assetConfig.id,
    elapsedEpochs,
    discount,
    invoiceValue: discounted.toString(),
    settlementValue: hubIntent?.settlementAmount ?? '0',
    unclaimed,
  };
};
