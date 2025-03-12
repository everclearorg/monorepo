import { ethers } from 'ethers';
import { getContext } from '../../context';
import { fetchProof } from './polymerProof';
import { LighthouseConfig } from '../config';
import { Relayer } from '../adapters/relayers';
import { Chain } from '../types';
import { sleep } from '../utils/sleep';
import { Logger } from 'pino';

// Interface for the IntentAdded event
interface IntentAddedEvent {
  chainId: number;
  blockNumber: number;
  transactionIndex: number;
  logIndex: number;
  transactionHash: string;
  intentHash: string;
}

// Error definitions
class PolymerProofFetchError extends Error {
  constructor(message: string, public readonly event: IntentAddedEvent) {
    super(`Failed to fetch Polymer proof: ${message}`);
    this.name = 'PolymerProofFetchError';
  }
}

class ProofRelayError extends Error {
  constructor(message: string, public readonly proof: string) {
    super(`Failed to relay proof to Gateway: ${message}`);
    this.name = 'ProofRelayError';
  }
}

/**
 * Process IntentAdded events
 * 
 * This task:
 * 1. Queries for IntentAdded events on specified spoke chains
 * 2. Fetches Polymer proofs for these events
 * 3. Relays the proofs to the Gateway contract on the clearing chain
 */
export async function processIntentAdded(
  config: LighthouseConfig
): Promise<void> {
  // Get the config
  const {
    logger,
    config: { chains, thresholds, hub },
    adapters: { database },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(processIntentAdded.name);

  // Get the spoke domains
  const domains = Object.keys(chains);
  const spokes = domains.filter((d) => d !== hub.domain);

  logger.debug('Method start', requestContext, methodContext, { type, spokes, domains, hubDomain: hub.domain });

  // Process each spoke chain
  for (const spoke of spokes) {
    await processChain(context, config, spoke, hub);
  }
  
  logger.info('Completed processIntentAdded task');
}

/**
 * Process IntentAdded events for a specific spoke chain
 */
async function processChain(
  context: LighthouseContext,
  config: LighthouseConfig,
  spokeChain: Chain,
  clearingChain: Chain
): Promise<void> {
  const { logger, adapters } = context;
  const { polymerConfig } = config;
  
  if (!polymerConfig) {
    logger.error('Polymer configuration is missing');
    return;
  }
  
  const chainService = adapters.chainservice;
  const relayers = adapters.relayers;
  
  // Get provider for the spoke chain
  const provider = await chainService.getProvider(spokeChain.domain);
  
  if (!provider) {
    logger.error({ chain: spokeChain.name }, 'Failed to get provider');
    return;
  }
  
  // Set up the everclear spoke contract
  const spokeAddress = spokeChain.contracts?.everclear;
  
  if (!spokeAddress) {
    logger.error({ chain: spokeChain.name }, 'Everclear spoke address not configured');
    return;
  }
  
  // Set up the Gateway contract on the clearing chain
  const gatewayAddress = clearingChain.contracts?.gateway;
  
  if (!gatewayAddress) {
    logger.error({ chain: clearingChain.name }, 'Gateway address not configured');
    return;
  }
  
  logger.info({ 
    spokeChain: spokeChain.name,
    clearingChain: clearingChain.name 
  }, 'Processing IntentAdded events');
  
  try {
    // Get the latest processed block or start from the configured block
    let fromBlock = await getLastProcessedBlock(context, spokeChain.domain) || 
      spokeChain.startBlock || 0;
    
    // Calculate to block (current - confirmations)
    const currentBlock = await provider.getBlockNumber();
    const toBlock = currentBlock - (spokeChain.confirmations || 1);
    
    if (fromBlock >= toBlock) {
      logger.info({ 
        chain: spokeChain.name,
        fromBlock,
        toBlock
      }, 'No new blocks to process');
      return;
    }
    
    logger.info({ 
      chain: spokeChain.name, 
      fromBlock, 
      toBlock 
    }, 'Querying for IntentAdded events');
    
    // Query for IntentAdded events
    const events = await getIntentAddedEvents(
      provider,
      spokeAddress,
      fromBlock,
      toBlock,
      logger
    );
    
    logger.info({ 
      chain: spokeChain.name, 
      count: events.length 
    }, 'Found IntentAdded events');
    
    // Process each event
    for (const event of events) {
      await processEvent(
        event,
        polymerConfig,
        gatewayAddress,
        clearingChain,
        relayers,
        logger
      );
    }
    
    // Update the last processed block
    await updateLastProcessedBlock(context, spokeChain.domain, toBlock);
    
  } catch (error) {
    logger.error({ 
      chain: spokeChain.name,
      error: error instanceof Error ? error.message : String(error)
    }, 'Error processing IntentAdded events');
  }
}

/**
 * Query for IntentAdded events on the spoke chain
 */
async function getIntentAddedEvents(
  provider: ethers.providers.Provider,
  spokeAddress: string,
  fromBlock: number,
  toBlock: number,
  logger: Logger
): Promise<IntentAddedEvent[]> {
  // IntentAdded event signature
  const eventSignature = 'IntentAdded(bytes32)';
  const eventTopic = ethers.utils.id(eventSignature);
  
  // Query logs for the IntentAdded event
  try {
    const logs = await provider.getLogs({
      address: spokeAddress,
      topics: [eventTopic],
      fromBlock,
      toBlock
    });
    
    // Map logs to events
    return logs.map(log => ({
      chainId: log.chainId || 0, // Fallback if not available
      blockNumber: log.blockNumber,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
      transactionHash: log.transactionHash,
      intentHash: log.topics[1] // Assuming the intent hash is the first indexed parameter
    }));
    
  } catch (error) {
    logger.error({ 
      error: error instanceof Error ? error.message : String(error),
      fromBlock,
      toBlock
    }, 'Error querying IntentAdded events');
    
    return [];
  }
}

/**
 * Process an individual IntentAdded event
 */
async function processEvent(
  event: IntentAddedEvent,
  polymerConfig: any,
  gatewayAddress: string,
  clearingChain: Chain,
  relayers: Relayer[],
  logger: Logger
): Promise<void> {
  logger.info({ 
    intentHash: event.intentHash,
    txHash: event.transactionHash
  }, 'Processing IntentAdded event');
  
  try {
    // Request proof from Polymer API
    const proof = await fetchProof(
      polymerConfig.apiEndpoint,
      polymerConfig.apiToken,
      event.chainId,
      event.blockNumber,
      event.transactionIndex,
      event.logIndex
    );
    
    if (!proof) {
      throw new PolymerProofFetchError('Empty proof returned', event);
    }
    
    logger.info({ 
      intentHash: event.intentHash,
      proofSize: proof.length
    }, 'Successfully fetched Polymer proof');
    
    // Prepare transaction for Gateway.sol on clearing chain
    const tx = {
      to: gatewayAddress,
      data: encodeHandlePolymerProof(proof)
    };
    
    // Select relayer for the clearing chain
    const relayer = selectRelayerForChain(relayers, clearingChain.domain);
    
    if (!relayer) {
      logger.error({ chain: clearingChain.name }, 'No relayer available for chain');
      return;
    }
    
    // Send the transaction
    const txResponse = await relayer.sendTransaction(clearingChain.domain, tx);
    
    logger.info({ 
      intentHash: event.intentHash,
      txHash: txResponse.hash
    }, 'Successfully relayed proof to Gateway');
    
    // Wait for confirmation
    await txResponse.wait(clearingChain.confirmations || 1);
    
    logger.info({ 
      intentHash: event.intentHash,
      txHash: txResponse.hash
    }, 'Proof relay transaction confirmed');
    
  } catch (error) {
    if (error instanceof PolymerProofFetchError) {
      logger.error({ 
        intentHash: event.intentHash,
        error: error.message
      }, 'Failed to fetch Polymer proof');
    } else {
      logger.error({ 
        intentHash: event.intentHash,
        error: error instanceof Error ? error.message : String(error)
      }, 'Error processing event');
    }
  }
}

/**
 * Encode the handlePolymerProof function call
 */
function encodeHandlePolymerProof(proof: string): string {
  // The function signature for handlePolymerProof
  const functionSignature = 'handlePolymerProof(bytes)';
  const functionSelector = ethers.utils.id(functionSignature).slice(0, 10);
  
  // Encode the parameters
  const encodedParams = ethers.utils.defaultAbiCoder.encode(['bytes'], [proof]);
  
  // Combine function selector and encoded parameters
  return functionSelector + encodedParams.slice(2);
}

/**
 * Select a relayer for the specified chain
 */
function selectRelayerForChain(relayers: Relayer[], domain: number): Relayer | undefined {
  // Find relayers that support this domain
  const eligibleRelayers = relayers.filter(r => r.supportsChain(domain));
  
  if (eligibleRelayers.length === 0) {
    return undefined;
  }
  
  // For now, just pick the first one
  // Could be enhanced with load balancing, gas price optimization, etc.
  return eligibleRelayers[0];
}

/**
 * Get the last processed block for a domain
 */
async function getLastProcessedBlock(
  context: LighthouseContext,
  domain: number
): Promise<number | undefined> {
  const { adapters } = context;
  const db = adapters.database;
  
  if (!db) {
    return undefined;
  }
  
  try {
    const result = await db.getLastProcessedBlock('intentadded', domain);
    return result?.blockNumber;
  } catch (error) {
    return undefined;
  }
}

/**
 * Update the last processed block for a domain
 */
async function updateLastProcessedBlock(
  context: LighthouseContext,
  domain: number,
  blockNumber: number
): Promise<void> {
  const { adapters } = context;
  const db = adapters.database;
  
  if (!db) {
    return;
  }
  
  try {
    await db.setLastProcessedBlock('intentadded', domain, blockNumber);
  } catch (error) {
    context.logger.error({ 
      domain, 
      blockNumber,
      error: error instanceof Error ? error.message : String(error)
    }, 'Failed to update last processed block');
  }
}
