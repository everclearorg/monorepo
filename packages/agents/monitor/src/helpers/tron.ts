import { getContext } from '../context';
import { createLoggingContext, jsonifyError } from '@chimera-monorepo/utils';

/**
 * Tron-specific helper functions
 * Provides utilities for interacting with Tron blockchain
 */

/**
 * Get the last intent nonce from Tron chain
 * This function fetches the latest nonce from the Tron spoke contract
 * Uses chainreader which has proper TronWeb integration
 */
export const getTronLastIntentNonce = async (): Promise<number> => {
  const { config, logger, adapters: { chainreader } } = getContext();
  const { requestContext, methodContext } = createLoggingContext(getTronLastIntentNonce.name);
  
  try {
    // Find Tron chain configuration (domain 728126428 = Tron mainnet)
    const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
    if (tronDomains.length === 0) {
      logger.warn('No Tron chains configured');
      return 0;
    }
    
    const tronDomain = tronDomains[0]; // Use first Tron domain
    const tronConfig = config.chains[tronDomain];
    const spokeAddress = tronConfig.deployments?.everclear;
    
    if (!spokeAddress) {
      logger.error('No Tron spoke address configured');
      return 0;
    }
    
    // Use chainreader to call the contract method
    // This is a placeholder - would need the actual ABI and method signature
    try {
      // Example contract call through chainreader (would need proper ABI encoding)
      // const nonce = await chainreader.readTx({
      //   domain: +tronDomain,
      //   to: spokeAddress,
      //   data: '0x...', // encoded function call
      //   funcSig: 'getLastIntentNonce()'
      // }, 'latest');
      
      // For now, return 0 as this would need proper contract integration
      logger.debug('Tron intent nonce check - contract integration needed');
      return 0;
    } catch (contractError: unknown) {
      logger.warn('Error calling Tron spoke contract for nonce', requestContext, methodContext, jsonifyError(contractError as Error));
      return 0;
    }
  } catch (error: unknown) {
    logger.error('Error fetching Tron intent nonce', requestContext, methodContext, jsonifyError(error as Error));
    return 0;
  }
};

/**
 * Convert Ethereum-style hex address to Tron Base58 address
 */
export const hexToTronAddress = (hexAddress: string): string => {
  // This is a placeholder implementation
  // Real implementation would use TronWeb.utils conversion
  return hexAddress; // Return as-is for now
};

/**
 * Convert Tron Base58 address to Ethereum-style hex address
 */
export const tronToHexAddress = (tronAddress: string): string => {
  // This is a placeholder implementation
  // Real implementation would use TronWeb.utils conversion
  return tronAddress; // Return as-is for now
};

/**
 * Get Tron block by number or 'latest'
 * Uses chainreader which has proper TronWeb integration
 */
export const getTronBlock = async (domainId: string, blockNumber: string | number = 'latest') => {
  const { config, logger, adapters: { chainreader } } = getContext();
  const { requestContext, methodContext } = createLoggingContext(getTronBlock.name);
  
  try {
    const chainConfig = config.chains[domainId];
    if (chainConfig.network !== 'tvm') {
      throw new Error(`Domain ${domainId} is not a Tron chain`);
    }
    
    // Use chainreader which has proper TronWeb integration
    const block = await chainreader.getBlock(+domainId, blockNumber);
    
    return {
      number: block.number,
      timestamp: block.timestamp,
      hash: block.hash,
    };
  } catch (error: unknown) {
    logger.error(`Error fetching Tron block for domain ${domainId}`, requestContext, methodContext, jsonifyError(error as Error));
    throw error;
  }
};