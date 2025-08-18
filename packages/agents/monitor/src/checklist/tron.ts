import { createLoggingContext, TRON_CHAINID, GasType } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { CheckGasResponse, Severity } from '../types';
import { resolveAlerts, sendAlerts, fetchRelayerData, getTronLastIntentNonce, getAccountResources } from '../mockable';
import { DefaultTronWebFactory } from '@chimera-monorepo/utils';

/**
 * Tron-specific chain monitoring checks
 * Provides 1-1 parity with EVM monitoring but adapted for Tron Virtual Machine (TVM)
 *
 * Key Tron adaptations:
 * - Uses TronWeb
 * - Energy/bandwidth model instead of gas
 *
 * Based on everclear config: https://raw.githubusercontent.com/connext/chaindata/main/everclear.mainnet.staging.json
 */

/**
 * Check Tron energy/bandwidth balances - equivalent to checkGas for EVM
 */
export const checkTronGas = async (shouldAlert = true): Promise<CheckGasResponse> => {
  const { config, logger } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronGas.name);

  const chainGas = [];
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');

  for (const domainId of tronDomains) {
    const chainConfig = config.chains[domainId];

    const relayerBandwidthThreshold = chainConfig.minBandwidthOnRelayer ?? 0;
    const relayerEnergyThreshold = chainConfig.minEnergyOnRelayer ?? 0;
    const gatewayBandwidthThreshold = chainConfig.minBandwidthOnGateway ?? 0;
    const gatewayEnergyThreshold = chainConfig.minEnergyOnGateway ?? 0;

    const relayerUrl = config.relayers.find((relayer) => relayer.type === 'Everclear')?.url;
    const relayerAddress = relayerUrl ? await fetchRelayerData(relayerUrl) : undefined;

    const gatewayAddress = chainConfig.deployments?.gateway;

    const tronWebFactory = new DefaultTronWebFactory();
    const tronWeb = tronWebFactory.create(chainConfig.providers[0] || 'https://api.trongrid.io');

    let relayerBandwidth: bigint | undefined;
    let relayerEnergy: bigint | undefined;
    let gatewayBandwidth: bigint | undefined;
    let gatewayEnergy: bigint | undefined;

    try {
      // Get relayer resources
      if (relayerAddress) {
        const relayerResources = await getAccountResources(relayerAddress, tronWeb);
        relayerBandwidth = relayerResources.bandwidth;
        relayerEnergy = relayerResources.energy;
      }

      // Get gateway resources
      if (gatewayAddress) {
        const gatewayResources = await getAccountResources(gatewayAddress, tronWeb);
        gatewayBandwidth = gatewayResources.bandwidth;
        gatewayEnergy = gatewayResources.energy;
      }
    } catch (error) {
      logger.error(
        `Failed to get Tron resources for domain ${domainId}: ${error instanceof Error ? error.message : String(error)}`,
        requestContext,
        methodContext,
      );
    }

    logger.debug(`Checking Tron resources: ${domainId}`, requestContext, methodContext, {
      domainId,
      relayerAddress,
      relayerBandwidth: relayerBandwidth?.toString(),
      relayerEnergy: relayerEnergy?.toString(),
      gatewayAddress,
      gatewayBandwidth: gatewayBandwidth?.toString(),
      gatewayEnergy: gatewayEnergy?.toString(),
      relayerBandwidthThreshold,
      relayerEnergyThreshold,
      gatewayBandwidthThreshold,
      gatewayEnergyThreshold,
    });

    // Add bandwidth item
    chainGas.push({
      domain: domainId,
      relayerAddress,
      belowRelayerThreshold: relayerBandwidth ? relayerBandwidth < BigInt(relayerBandwidthThreshold) : false,
      relayerGas: relayerBandwidth?.toString(),
      gatewayAddress,
      gatewayGas: gatewayBandwidth?.toString(),
      belowGatewayThreshold: gatewayBandwidth ? gatewayBandwidth < BigInt(gatewayBandwidthThreshold) : false,
      gasType: GasType.Bandwidth,
    });

    // Add energy item
    chainGas.push({
      domain: domainId,
      relayerAddress,
      belowRelayerThreshold: relayerEnergy ? relayerEnergy < BigInt(relayerEnergyThreshold) : false,
      relayerGas: relayerEnergy?.toString(),
      gatewayAddress,
      gatewayGas: gatewayEnergy?.toString(),
      belowGatewayThreshold: gatewayEnergy ? gatewayEnergy < BigInt(gatewayEnergyThreshold) : false,
      gasType: GasType.Energy,
    });

    // Check relayer bandwidth resources
    const relayerBandwidthViolated =
      relayerAddress && relayerBandwidth && relayerBandwidth < BigInt(relayerBandwidthThreshold);
    const relayerBandwidthReport = {
      severity: Severity.Warning,
      type: 'LowTronBandwidthRelayer',
      ids: [domainId],
      reason: `${requestContext.origin}, The Tron relayer ${relayerAddress} of ${domainId} has low bandwidth`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };

    if (shouldAlert && relayerBandwidthViolated) {
      logger.warn(
        `The Tron relayer ${relayerAddress} of ${domainId} has low bandwidth`,
        requestContext,
        methodContext,
        {
          relayerBandwidth: relayerBandwidth?.toString(),
          relayerBandwidthThreshold,
          relayerAddress,
        },
      );
      await sendAlerts(relayerBandwidthReport, logger, config, requestContext);
    } else if (shouldAlert && !relayerBandwidthViolated) {
      await resolveAlerts(relayerBandwidthReport, logger, config, requestContext);
    }

    // Check relayer energy resources
    const relayerEnergyViolated = relayerAddress && relayerEnergy && relayerEnergy < BigInt(relayerEnergyThreshold);
    const relayerEnergyReport = {
      severity: Severity.Warning,
      type: 'LowTronEnergyRelayer',
      ids: [domainId],
      reason: `${requestContext.origin}, The Tron relayer ${relayerAddress} of ${domainId} has low energy`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };

    if (shouldAlert && relayerEnergyViolated) {
      logger.warn(`The Tron relayer ${relayerAddress} of ${domainId} has low energy`, requestContext, methodContext, {
        relayerEnergy: relayerEnergy?.toString(),
        relayerEnergyThreshold,
        relayerAddress,
      });
      await sendAlerts(relayerEnergyReport, logger, config, requestContext);
    } else if (shouldAlert && !relayerEnergyViolated) {
      await resolveAlerts(relayerEnergyReport, logger, config, requestContext);
    }

    // Check gateway bandwidth resources
    const gatewayBandwidthViolated =
      gatewayAddress && gatewayBandwidth && gatewayBandwidth < BigInt(gatewayBandwidthThreshold);
    const gatewayBandwidthReport = {
      severity: Severity.Warning,
      type: 'LowTronBandwidthGateway',
      ids: [domainId],
      reason: `${requestContext.origin}, The Tron gateway ${gatewayAddress} of ${domainId} has low bandwidth`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };

    if (shouldAlert && gatewayBandwidthViolated) {
      logger.warn(
        `The Tron gateway ${gatewayAddress} of ${domainId} has low bandwidth`,
        requestContext,
        methodContext,
        {
          gatewayBandwidth: gatewayBandwidth?.toString(),
          gatewayBandwidthThreshold,
          gatewayAddress,
        },
      );
      await sendAlerts(gatewayBandwidthReport, logger, config, requestContext);
    } else if (shouldAlert && !gatewayBandwidthViolated) {
      await resolveAlerts(gatewayBandwidthReport, logger, config, requestContext);
    }

    // Check gateway energy resources
    const gatewayEnergyViolated = gatewayAddress && gatewayEnergy && gatewayEnergy < BigInt(gatewayEnergyThreshold);
    const gatewayEnergyReport = {
      severity: Severity.Warning,
      type: 'LowTronEnergyGateway',
      ids: [domainId],
      reason: `${requestContext.origin}, The Tron gateway ${gatewayAddress} of ${domainId} has low energy`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };

    if (shouldAlert && gatewayEnergyViolated) {
      logger.warn(`The Tron gateway ${gatewayAddress} of ${domainId} has low energy`, requestContext, methodContext, {
        gatewayEnergy: gatewayEnergy?.toString(),
        gatewayEnergyThreshold,
        gatewayAddress,
      });
      await sendAlerts(gatewayEnergyReport, logger, config, requestContext);
    } else if (shouldAlert && !gatewayEnergyViolated) {
      await resolveAlerts(gatewayEnergyReport, logger, config, requestContext);
    }
  }

  logger.info('Overall Tron resources status', requestContext, methodContext, chainGas);
  return chainGas;
};

export const checkTronPipelineStatus = async (shouldAlert = true): Promise<void> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronPipelineStatus.name);

  const CHECKPOINT_NAME = 'tron_intent_nonce';

  logger.debug('Checking Tron pipeline status', requestContext, methodContext);

  const chainNonce = await getTronLastIntentNonce();
  const localNonce = await database.getOriginIntentsLastNonce(TRON_CHAINID);
  const lastSavedNonce = await database.getCheckPoint(CHECKPOINT_NAME);

  if (chainNonce === lastSavedNonce) {
    logger.debug('Tron intent nonce match', requestContext, methodContext, {
      chainNonce,
      localNonce,
    });
    return;
  }

  if (localNonce !== lastSavedNonce) {
    await database.saveCheckPoint(CHECKPOINT_NAME, localNonce);
  }

  if (shouldAlert) {
    const report = {
      severity: Severity.Warning,
      type: 'TronPipelineDelay',
      ids: ['TronPipelineDelay'],
      reason: `The Tron pipeline is delayed, local nonce: ${localNonce}, chain nonce: ${chainNonce}`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };

    if (chainNonce !== localNonce) {
      logger.warn('Tron intent nonce mismatch', requestContext, methodContext, {
        chainNonce,
        localNonce,
      });

      await sendAlerts(report, logger, config, requestContext);
    } else {
      await resolveAlerts(report, logger, config, requestContext, true);
    }
  }
};
