import { BigNumber } from 'ethers';
import { formatUnits } from 'ethers/lib/utils';
import { AssetConfig, createLoggingContext, RequestContext } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { Severity } from '../types';
import { getRegisteredAssetHashFromContract, getCustodiedAssetsFromHubContract } from '../helpers';
import { resolveAlerts, sendAlerts } from '../mockable';

// check sum of balance from all spokes contract >= hub custodied/unclaimed amount.
// this ensure there were no missing balance, i.e. all custodied in hub have corresponding asset.
const checkAssetSpokeBalance = async (
  assetName: string,
  assetConfig: AssetConfig,
  _requestContext?: RequestContext,
): Promise<undefined> => {
  const {
    config,
    logger,
    adapters: { chainreader },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkSpokeBalance.name, _requestContext);

  // We batch chainreader calls together to minimize timing issue and to make it more efficient.
  // Note it might still be possible that timing causes a false positive here.
  const getCustodiedAssetCalls = [];
  const spokeBalanceCalls = [];

  let totalCustodiedBalance = BigNumber.from(0);
  const custodiedBalances: Record<string, string> = {};
  // spokeBalances stores a mapping of domains to (balance and representing decimals).
  const spokeBalances: Record<string, [string, number]> = {};
  for (const domainId of Object.keys(config.chains)) {
    const assetHash = await getRegisteredAssetHashFromContract(assetConfig.tickerHash, domainId);

    const hubCallback = async () => {
      const custodied = await getCustodiedAssetsFromHubContract(assetHash);
      totalCustodiedBalance = totalCustodiedBalance.add(custodied);
      custodiedBalances[domainId] = custodied;
      logger.debug(`${assetName} to ${domainId} unclaimed on Hub: ${custodied}`);
    };
    getCustodiedAssetCalls.push(hubCallback());

    const chainConfig = config.chains[domainId];
    if (chainConfig.deployments?.everclear === undefined) {
      logger.error(`Missing spoke contract config in domain ${domainId}`, requestContext, methodContext);
      continue;
    }
    const domainAssetConfig = chainConfig.assets?.[assetName];
    if (domainAssetConfig === undefined) {
      logger.warn(`Asset ${assetName} not available at domain ${domainId}.`);
      continue;
    }

    const spokeAddress: string = chainConfig.deployments?.everclear;
    const spokeCallback = async () => {
      const spokeBalance = await chainreader.getBalance(
        +domainId,
        spokeAddress,
        domainAssetConfig.isNative ? undefined : domainAssetConfig.address,
      );
      spokeBalances[domainId] = [spokeBalance, domainAssetConfig.decimals];
      logger.debug(`${assetName} Spoke Balance on ${domainId}: ${spokeBalance}`);
    };

    spokeBalanceCalls.push(spokeCallback());
  }

  await Promise.all([...getCustodiedAssetCalls, ...spokeBalanceCalls]);

  // check if there is a spoke using decimals > 18
  const highestDecimals = Object.values(spokeBalances).reduce((acc: number, item) => {
    const decimals = item[1];
    return acc < decimals ? decimals : acc;
  }, 18);
  if (highestDecimals > 18) {
    logger.error(`${assetName} used decimals > 18 ${highestDecimals}! checks no longer valid.`);
    return;
  }

  // compute decimal normalized spoke balances for comparison
  let totalSpokeBalance = BigNumber.from(0);
  const normalizedSpokeBalances: Record<string, BigNumber> = {};
  Object.entries(spokeBalances).forEach(([domain, [balance, decimals]]) => {
    const multiplier = BigNumber.from(10).pow(18 - decimals);
    normalizedSpokeBalances[domain] = BigNumber.from(balance).mul(multiplier);
    totalSpokeBalance = totalSpokeBalance.add(normalizedSpokeBalances[domain]);
  });

  const formattedTotalCustodiedBalance = `${formatUnits(totalCustodiedBalance, highestDecimals)} ${assetName}`;
  const formattedTotalSpokeBalance = `${formatUnits(totalSpokeBalance, highestDecimals)} ${assetName}`;

  logger.debug(`total Hub unclaimed: ${formattedTotalCustodiedBalance}`);
  logger.debug(`total Spoke Balance: ${formattedTotalSpokeBalance}`);

  const report = {
    // TODO: switch this to critical severity after sufficient prod test
    severity: Severity.Warning,
    type: 'MissingSpokeBalance',
    ids: [assetName],
    reason: [
      `Missing Spoke Balance for ${assetName}:`,
      `totalSpokeBalance < totalUnclaimedBalance: ${formattedTotalSpokeBalance} < ${formattedTotalCustodiedBalance}`,
      'balance in domain spokes:',
      ...Object.entries(normalizedSpokeBalances).map(
        ([domainId, normalizedSpokeBalance]) => `domainId ${domainId}: ${normalizedSpokeBalance}`,
      ),
      'unclaimed in hub routes:',
      ...Object.entries(custodiedBalances).map(
        ([domainId, unclaimedBalance]) => `domainId ${domainId}: ${unclaimedBalance}`,
      ),
    ].join('\n'),
    timestamp: Date.now(),
    logger,
    env: config.environment,
  };

  if (totalSpokeBalance.lt(totalCustodiedBalance)) {
    // critical error. liquidity missing as total spoke balance for the asset < custodied balance!
    await sendAlerts(report, logger, config, requestContext);
    logger.debug(
      `Missing Spoke Balance in ${assetName} totalSpokeBalance < totalUnclaimedBalance: ${formattedTotalSpokeBalance} < ${formattedTotalCustodiedBalance}`,
      requestContext,
      methodContext,
    );
  } else {
    await resolveAlerts(report, logger, config, requestContext);
  }
};

export const checkSpokeBalance = async () => {
  const { config, logger } = getContext();

  const { requestContext, methodContext } = createLoggingContext(checkSpokeBalance.name);
  logger.debug('Checking spoke balance', requestContext, methodContext);

  const checkAssetSpokeBalanceCalls = [];
  const checkedAsset = new Set();
  for (const domain of Object.keys(config.chains)) {
    const chainConfig = config.chains[domain];
    if (chainConfig.assets) {
      for (const assetName of Object.keys(chainConfig.assets)) {
        // For each token, we check sum of all spokes balance >= sum of hub unchaimed amount for all routes
        if (!checkedAsset.has(assetName)) {
          const assetConfig = chainConfig.assets[assetName];
          checkAssetSpokeBalanceCalls.push(checkAssetSpokeBalance(assetName, assetConfig, requestContext));
          checkedAsset.add(assetName);
        }
      }
    }
  }
  await Promise.all(checkAssetSpokeBalanceCalls);
};
