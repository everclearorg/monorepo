import { createLoggingContext } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { CheckGasResponse, Severity } from '../types';
import { BigNumber, utils } from 'ethers';
import axios from 'axios';
import { resolveAlerts, sendAlerts } from '../mockable';

export const checkGas = async (shouldAlert = true): Promise<CheckGasResponse> => {
  const {
    config,
    logger,
    adapters: { chainreader },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkGas.name);

  const chainGas = [];
  const chains = [...Object.keys(config.chains), config.hub.domain];
  let native;
  for (const domainId of chains) {
    // If the domain is hub, get the native asset from hub assets
    if (domainId === config.hub.domain) {
      native = Object.entries(config.hub.assets!).find(([, asset]) => asset.isNative)?.[1];
    } else {
      native = Object.entries(config.chains[domainId].assets!).find(([, asset]) => asset.isNative)?.[1];
    }

    // Get thresholds for relayer and gateway
    const relayerThreshold = utils.parseUnits(
      (config.thresholds.minGasOnRelayer ?? 0).toString(),
      native?.decimals ?? 18,
    );
    const gatewayThreshold = utils.parseUnits(
      (config.thresholds.minGasOnGateway ?? 0).toString(),
      native?.decimals ?? 18,
    );

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
    });

    chainGas.push({
      domain: domainId,
      relayerAddress,
      belowRelayerThreshold: relayerGas ? BigNumber.from(relayerGas).lt(relayerThreshold) : false,
      relayerGas,
      gatewayAddress,
      gatewayGas,
      belowGatewayThreshold: gatewayGas ? BigNumber.from(gatewayGas).lt(gatewayThreshold) : false,
      tokenomicsGatewayGas,
      belowTokenomicsGatewayThreshold: tokenomicsGatewayGas ? BigNumber.from(gatewayGas).lt(gatewayThreshold) : false,
    });

    const relayerReport = {
      severity: Severity.Warning,
      type: 'LowGasRelayer',
      ids: [domainId],
      reason: `${requestContext.origin}, The relayer ${relayerAddress} of ${domainId} has low gas balance`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };
    const relayerViolated = relayerAddress && BigNumber.from(relayerGas ?? '0').lt(relayerThreshold);
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

    const gatewayGasViolated = gatewayAddress && BigNumber.from(gatewayGas ?? '0').lt(gatewayThreshold);
    const gatewayReport = {
      severity: Severity.Warning,
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

    const tokenomicsGatewayGasViolated =
      tokenonmicsGatewayAddress && BigNumber.from(tokenomicsGatewayGas ?? '0').lt(gatewayThreshold);
    const tokenomicsGatewayReport = {
      severity: Severity.Warning,
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
  }

  logger.info('Overall chain gas', requestContext, methodContext, chainGas);

  return chainGas;
};

/**
 * Fetch address from the given relayer URL.
 */
async function fetchRelayerData(relayerUrl: string): Promise<string | undefined> {
  try {
    const response = await axios.get(`${relayerUrl}/address`);
    return response.data;
  } catch (error) {
    console.error(`Error fetching address from ${relayerUrl}:`, error);
    return undefined;
  }
}
