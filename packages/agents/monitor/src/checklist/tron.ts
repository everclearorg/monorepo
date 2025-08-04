import { createLoggingContext, Logger } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { Report, Severity, ChainStatusResponse, CheckGasResponse } from '../types';
import { resolveAlerts, sendAlerts } from '../mockable';
import { BigNumber, utils, constants } from 'ethers';
// Note: TronWeb integration is handled through the chainreader adapter

/**
 * Tron-specific chain monitoring checks
 * Provides 1-1 parity with EVM monitoring but adapted for Tron Virtual Machine (TVM)
 * 
 * Key Tron adaptations:
 * - Uses chainreader with TronWeb integration (domain 728126428 = Tron mainnet)
 * - TRX has 6 decimals (not 18 like ETH)
 * - Uses constants.AddressZero for native TRX balance checks
 * - Addresses are Base58 format (not hex) but chainreader handles conversion
 * - Energy/bandwidth model instead of gas
 * 
 * Based on everclear config: https://raw.githubusercontent.com/connext/chaindata/main/everclear.mainnet.staging.json
 */

interface TronRpcError {
  rpcOrigin: string;
  domain: string;
  error?: string;
  blockNumber?: number;
}

const makeTronRpcReport = (e: TronRpcError, logger: Logger, env: string): Report => ({
  severity: Severity.Warning,
  type: 'BadTronRpcDetected',
  ids: [e.domain, e.rpcOrigin],
  reason: `Bad Tron Rpcs:\n domain: ${e.domain}, url: ${e.rpcOrigin}, error: ${e.error}`,
  timestamp: Date.now(),
  logger,
  env,
});

/**
 * Check Tron RPC connectivity - equivalent to checkRpcs for EVM
 * Uses chainreader which already has TronWeb integration
 */
export const checkTronRpcs = async () => {
  const { config, logger, adapters: { chainreader } } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronRpcs.name);
  
  const badRpcs: TronRpcError[] = [];
  const goodRpcs = [];
  
  // Filter for Tron chains (network: 'tvm')
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  
  for (const domainId of tronDomains) {
    const chainConfig = config.chains[domainId];
    const rpcUrls = chainConfig.providers;
    
    for (const rpcUrl of rpcUrls) {
      const rpcOrigin = URL.canParse(rpcUrl) ? new URL(rpcUrl).origin : 'malformed URL';
      try {
        // Use chainreader which has proper TronWeb integration
        const blockNumber = await chainreader.getBlockNumber(+domainId);
        goodRpcs.push({ rpcOrigin, blockNumber, domain: domainId });
      } catch (error: unknown) {
        (error as Error).message = (error as Error).message.replace(rpcUrl, rpcOrigin);
        badRpcs.push({ rpcOrigin, error: (error as Error).message, domain: domainId });
        logger.debug(`Error connecting to Tron provider at ${rpcOrigin}: ${error}`, requestContext, methodContext);
      }
    }
  }

  for (const badRpc of badRpcs) {
    const report = makeTronRpcReport(badRpc, logger, config.environment);
    await sendAlerts(report, logger, config, requestContext);
  }

  for (const goodRpc of goodRpcs) {
    const report = makeTronRpcReport(goodRpc, logger, config.environment);
    await resolveAlerts(report, logger, config, requestContext);
  }

  logger.info('Overall Tron RPC status', requestContext, methodContext, {
    badRpcs,
    goodRpcs,
  });
};

/**
 * Check Tron chain status - equivalent to checkChains for EVM
 */
export const checkTronChains = async (shouldAlert = true): Promise<ChainStatusResponse> => {
  const {
    config,
    logger,
    adapters: { subgraph, chainreader },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronChains.name);

  const chainStatus = [];
  // Get Tron domains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  
  const subgraphBlockNumbers = await subgraph.getLatestBlockNumber(tronDomains);

  for (const domainId of tronDomains) {
    const chainConfig = config.chains[domainId];
    const threshold = chainConfig.maxDelayedSubgraphBlock ?? config.thresholds.maxDelayedSubgraphBlock ?? 0;

    const subgraphBlockNumber = subgraphBlockNumbers.has(domainId) ? subgraphBlockNumbers.get(domainId)! : 0;
    
    // For Tron, we need to use chainreader adapted for TVM
    const rpcBlock = await chainreader.getBlock(+domainId, 'latest');
    const diff = rpcBlock.number - subgraphBlockNumber;

    logger.debug(`Checking Tron chain status: ${domainId}`, requestContext, methodContext, {
      rpc: rpcBlock.number,
      subgraph: subgraphBlockNumber,
      diff,
      threshold,
    });

    chainStatus.push({
      domain: domainId,
      rpc: {
        blockNumber: rpcBlock.number,
        timestamp: rpcBlock.timestamp,
      },
      subgraphBlockNumber,
    });

    const report = {
      severity: Severity.Warning,
      type: 'TronSubgraphDelayed',
      ids: [domainId],
      reason: `${requestContext.origin}, The Tron subgraph of ${domainId} is behind by ${diff} blocks (threshold: ${threshold})`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };

    if (shouldAlert && threshold > 0 && diff > threshold) {
      logger.warn(`The Tron subgraph of ${domainId} is behind by a threshold of blocks`, requestContext, methodContext, {
        diff,
        threshold,
      });
      await sendAlerts(report, logger, config, requestContext);
    } else {
      await resolveAlerts(report, logger, config, requestContext);
    }
  }

  logger.info('Overall Tron chain status', requestContext, methodContext, chainStatus);
  return chainStatus;
};

/**
 * Check Tron energy/bandwidth balances - equivalent to checkGas for EVM
 * Note: Tron uses TRX for energy and bandwidth instead of gas
 * TRX has 6 decimals (not 18 like ETH)
 */
export const checkTronGas = async (shouldAlert = true): Promise<CheckGasResponse> => {
  const {
    config,
    logger,
    adapters: { chainreader },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronGas.name);

  const chainGas = [];
  // Get Tron domains only (domain 728126428 = Tron mainnet)
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  
  for (const domainId of tronDomains) {
    const chainConfig = config.chains[domainId];
    
    // For Tron, there's no native asset marked as isNative in the config
    // TRX balance is checked using constants.AddressZero
    // From the everclear config: TRX is implicit (not listed in assets)
    const TRX_DECIMALS = 6; // TRX has 6 decimals (from chainservice implementation)
    
    // Use chain-specific thresholds or fall back to global defaults
    const relayerThresholdValue = chainConfig.minGasOnRelayer ?? config.thresholds.minGasOnRelayer ?? 0;
    const gatewayThresholdValue = chainConfig.minGasOnGateway ?? config.thresholds.minGasOnGateway ?? 0;

    // TRX has 6 decimals unlike ETH's 18
    const relayerThreshold = utils.parseUnits(relayerThresholdValue.toString(), TRX_DECIMALS);
    const gatewayThreshold = utils.parseUnits(gatewayThresholdValue.toString(), TRX_DECIMALS);

    const relayerUrl = config.relayers.find((relayer) => relayer.type === 'Everclear')?.url;
    const relayerAddress = relayerUrl ? await fetchRelayerData(relayerUrl) : undefined;
    // For TRX native balance, use constants.AddressZero (per chainservice implementation)
    const relayerGas = relayerAddress
      ? await chainreader.getBalance(+domainId, relayerAddress, constants.AddressZero)
      : undefined;

    const gatewayAddress = chainConfig.deployments?.gateway;
    const gatewayGas = gatewayAddress
      ? await chainreader.getBalance(+domainId, gatewayAddress, constants.AddressZero)
      : undefined;

    logger.debug(`Checking Tron energy/bandwidth: ${domainId}`, requestContext, methodContext, {
      domainId,
      relayerAddress,
      relayerGas,
      gatewayAddress,
      gatewayGas,
      relayerThresholdValue,
      gatewayThresholdValue,
    });

    chainGas.push({
      domain: domainId,
      relayerAddress,
      belowRelayerThreshold: relayerGas ? BigNumber.from(relayerGas).lt(relayerThreshold) : false,
      relayerGas,
      gatewayAddress,
      gatewayGas,
      belowGatewayThreshold: gatewayGas ? BigNumber.from(gatewayGas).lt(gatewayThreshold) : false,
      tokenomicsGatewayGas: undefined, // Tron doesn't have tokenomics gateway yet
      belowTokenomicsGatewayThreshold: false,
    });

    // Check relayer TRX balance
    const relayerReport = {
      severity: Severity.Warning,
      type: 'LowTrxRelayer',
      ids: [domainId],
      reason: `${requestContext.origin}, The Tron relayer ${relayerAddress} of ${domainId} has low TRX balance`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };
    
    const relayerViolated = relayerAddress && BigNumber.from(relayerGas ?? '0').lt(relayerThreshold);
    if (shouldAlert && relayerViolated) {
      logger.warn(`The Tron relayer ${relayerAddress} of ${domainId} has low TRX balance`, requestContext, methodContext, {
        relayerGas,
        relayerThreshold,
        relayerAddress,
      });
      await sendAlerts(relayerReport, logger, config, requestContext);
    } else if (shouldAlert && !relayerViolated) {
      await resolveAlerts(relayerReport, logger, config, requestContext);
    }

    // Check gateway TRX balance
    const gatewayGasViolated = gatewayAddress && BigNumber.from(gatewayGas ?? '0').lt(gatewayThreshold);
    const gatewayReport = {
      severity: Severity.Warning,
      type: 'LowTrxGateway',
      ids: [domainId],
      reason: `${requestContext.origin}, The Tron gateway ${gatewayAddress} of ${domainId} has low TRX balance`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };
    
    if (shouldAlert && gatewayGasViolated) {
      logger.warn(`The Tron gateway ${gatewayAddress} of ${domainId} has low TRX balance`, requestContext, methodContext, {
        gatewayGas,
        gatewayThreshold,
        gatewayAddress,
      });
      await sendAlerts(gatewayReport, logger, config, requestContext);
    } else if (shouldAlert && !gatewayGasViolated) {
      await resolveAlerts(gatewayReport, logger, config, requestContext);
    }
  }

  logger.info('Overall Tron energy/bandwidth status', requestContext, methodContext, chainGas);
  return chainGas;
};

/**
 * Fetch address from the given relayer URL - same as EVM version
 */
async function fetchRelayerData(relayerUrl: string): Promise<string | undefined> {
  try {
    const response = await fetch(`${relayerUrl}/address`);
    const data = await response.text();
    return data;
  } catch (error) {
    console.error(`Error fetching address from ${relayerUrl}:`, error);
    return undefined;
  }
}