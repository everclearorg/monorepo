import { createLoggingContext, chainWrapper, jsonifyError } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { CheckGasResponse, Severity } from '../types';
import axios from 'axios';
import { resolveAlerts, sendAlerts } from '../mockable';

export const checkGas = async (shouldAlert = true): Promise<CheckGasResponse> => {
  const {
    config,
    logger,
    adapters: { chainreader },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkGas.name);

  const chainGas: CheckGasResponse = [];
  const chains = [
    ...Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'evm'),
    config.hub.domain,
  ];

  await Promise.all(
    chains.map(async (domainId) => {
      // If the domain is hub, get the native asset from hub assets
      const native =
        domainId === config.hub.domain
          ? Object.entries(config.hub.assets!).find(([, asset]) => asset.isNative)?.[1]
          : Object.entries(config.chains[domainId].assets!).find(([, asset]) => asset.isNative)?.[1];

      // Get chain-specific thresholds or fall back to global defaults
      const chainConfig = domainId === config.hub.domain ? config.hub : config.chains[domainId];

      // Use chain-specific values if available, otherwise fall back to global thresholds
      const relayerThresholdValue = chainConfig.minGasOnRelayer ?? config.thresholds.minGasOnRelayer ?? 0;
      const gatewayThresholdValue = chainConfig.minGasOnGateway ?? config.thresholds.minGasOnGateway ?? 0;

      // Parse threshold values with appropriate decimal places
      const relayerThreshold = chainWrapper.parseUnits(relayerThresholdValue.toString(), native?.decimals ?? 18);
      const gatewayThreshold = chainWrapper.parseUnits(gatewayThresholdValue.toString(), native?.decimals ?? 18);

      const relayerUrl = config.relayers.find((relayer) => relayer.type === 'Everclear')?.url;

      const relayerAddress = relayerUrl ? await fetchRelayerData(relayerUrl) : undefined;
      const relayerGas = relayerAddress
        ? await chainreader.getBalance(+domainId, relayerAddress, native?.address)
        : undefined;

      let gatewayAddress;
      let tokenonmicsGatewayAddress;
      if (domainId === config.hub.domain) {
        gatewayAddress = config.hub.deployments?.gateway;
        tokenonmicsGatewayAddress = config.hub.deployments?.tokenomicsHubGateway;
      } else {
        gatewayAddress = config.chains[domainId].deployments?.gateway;
      }

      const gatewayGas = gatewayAddress
        ? await chainreader.getBalance(+domainId, gatewayAddress, native?.address)
        : undefined;

      const tokenomicsGatewayGas = tokenonmicsGatewayAddress
        ? await chainreader.getBalance(+domainId, tokenonmicsGatewayAddress, native?.address)
        : undefined;

      logger.debug(`Checking chain gas: ${domainId}`, requestContext, methodContext, {
        domainId,
        relayerAddress,
        relayerGas,
        gatewayAddress,
        gatewayGas,
        tokenomicsGatewayGas,
        relayerThresholdValue,
        gatewayThresholdValue,
      });

      chainGas.push({
        domain: domainId,
        relayerAddress,
        belowRelayerThreshold: relayerGas ? BigInt(relayerGas) < BigInt(relayerThreshold) : false,
        relayerGas,
        gatewayAddress,
        gatewayGas,
        belowGatewayThreshold: gatewayGas ? BigInt(gatewayGas) < BigInt(gatewayThreshold) : false,
        tokenomicsGatewayGas,
        belowTokenomicsGatewayThreshold: tokenomicsGatewayGas
          ? BigInt(tokenomicsGatewayGas) < BigInt(gatewayThreshold)
          : false,
      });

      const relayerBalance = BigInt(relayerGas ?? '0');
      const relayerCritical = relayerAddress && relayerBalance < BigInt(relayerThreshold) / 2n;
      const relayerReport = {
        severity: relayerCritical ? Severity.Critical : Severity.Warning,
        type: 'LowGasRelayer',
        ids: [domainId],
        reason: `${requestContext.origin}, The relayer ${relayerAddress} of ${domainId} has low gas balance`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      const relayerViolated = relayerAddress && relayerBalance < BigInt(relayerThreshold);
      if (shouldAlert && relayerViolated) {
        // Send relayer gas alerts
        logger.warn(`The relayer ${relayerAddress} of ${domainId} has low gas balance`, requestContext, methodContext, {
          relayerGas,
          relayerThreshold,
          relayerAddress,
        });

        await sendAlerts(relayerReport, logger, config, requestContext);
      } else if (shouldAlert && !relayerViolated) {
        // Send relayer gas alerts
        logger.info(
          `The relayer ${relayerAddress} of ${domainId} has sufficient gas balance`,
          requestContext,
          methodContext,
          {
            relayerGas,
            relayerThreshold,
            relayerAddress,
          },
        );
        await resolveAlerts(relayerReport, logger, config, requestContext);
      }

      const gatewayBalance = BigInt(gatewayGas ?? '0');
      const gatewayGasViolated = gatewayAddress && gatewayBalance < BigInt(gatewayThreshold);
      const gatewayCritical = gatewayAddress && gatewayBalance < BigInt(gatewayThreshold) / 2n;
      const gatewayReport = {
        severity: gatewayCritical ? Severity.Critical : Severity.Warning,
        type: 'LowGasGateway',
        ids: [domainId],
        reason: `${requestContext.origin}, The gateway ${gatewayAddress} of ${domainId} has low gas balance`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      if (shouldAlert && gatewayGasViolated) {
        // Resolve gateway gas alerts
        logger.warn(`The gateway ${gatewayAddress} of ${domainId} has low gas balance`, requestContext, methodContext, {
          gatewayGas,
          gatewayThreshold,
          gatewayAddress,
        });

        await sendAlerts(gatewayReport, logger, config, requestContext);
      } else if (shouldAlert && !gatewayGasViolated) {
        // Resolve relayer gas alerts
        logger.info(
          `The gateway ${gatewayAddress} of ${domainId} has sufficient gas balance`,
          requestContext,
          methodContext,
          {
            relayerGas,
            relayerThreshold,
            relayerAddress,
          },
        );
        await resolveAlerts(gatewayReport, logger, config, requestContext);
      }

      const tokenomicsGwBalance = BigInt(tokenomicsGatewayGas ?? '0');
      const tokenomicsGatewayGasViolated =
        tokenonmicsGatewayAddress && tokenomicsGwBalance < BigInt(gatewayThreshold);
      const tokenomicsGwCritical = tokenonmicsGatewayAddress && tokenomicsGwBalance < BigInt(gatewayThreshold) / 2n;
      const tokenomicsGatewayReport = {
        severity: tokenomicsGwCritical ? Severity.Critical : Severity.Warning,
        type: 'LowGasTokenomicsGateway',
        ids: [domainId],
        reason: `${requestContext.origin}, The tokenomics gateway ${tokenonmicsGatewayAddress} of ${domainId} has low gas balance`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      if (shouldAlert && tokenomicsGatewayGasViolated) {
        // Send tokenomics gateway gas alerts
        logger.warn(
          `The tokenomics gateway ${tokenonmicsGatewayAddress} of ${domainId} has low gas balance`,
          requestContext,
          methodContext,
          {
            tokenomicsGatewayGas,
            gatewayThreshold,
            tokenonmicsGatewayAddress,
          },
        );

        await sendAlerts(tokenomicsGatewayReport, logger, config, requestContext);
      } else if (shouldAlert && !tokenomicsGatewayGasViolated) {
        // Resolve tokenomics gateway gas alerts
        logger.info(
          `The tokenomics gateway ${tokenonmicsGatewayAddress} of ${domainId} has sufficient gas balance`,
          requestContext,
          methodContext,
          {
            tokenomicsGatewayGas,
            gatewayThreshold,
            tokenonmicsGatewayAddress,
          },
        );
        await resolveAlerts(tokenomicsGatewayReport, logger, config, requestContext);
      }
    }),
  );

  logger.info('Overall chain gas', requestContext, methodContext, chainGas);

  return chainGas;
};

/**
 * Fetch address from the given relayer URL.
 */
async function fetchRelayerData(relayerUrl: string): Promise<string | undefined> {
  const { logger } = getContext();
  try {
    const response = await axios.get(`${relayerUrl}/address`);
    return response.data;
  } catch (error) {
    logger.error(`Error fetching address from ${relayerUrl}`, undefined, undefined, jsonifyError(error as Error));
    return undefined;
  }
}
