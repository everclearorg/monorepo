import axios from 'axios';
import { Logger } from 'pino';

/**
 * Interface for the request proof parameters
 */
interface RequestProofParams {
  jsonrpc: string;
  id: number;
  method: string;
  params: number[];
}

/**
 * Interface for the request proof response
 */
interface RequestProofResponse {
  result: number;
  error?: {
    code: number;
    message: string;
  };
}

/**
 * Interface for the query proof parameters
 */
interface QueryProofParams {
  jsonrpc: string;
  id: number;
  method: string;
  params: number[];
}

/**
 * Interface for the query proof result
 */
interface QueryProofResult {
  proof: string;
  status: string;
}

/**
 * Interface for the query proof response
 */
interface QueryProofResponse {
  result: QueryProofResult;
  error?: {
    code: number;
    message: string;
  };
}

/**
 * Max number of attempts to query a proof
 */
const MAX_QUERY_ATTEMPTS = 5;

/**
 * Delay between query attempts in milliseconds
 */
const QUERY_DELAY_MS = 2000;

/**
 * Fetch a Polymer proof for a specific event
 * 
 * @param endpoint The Polymer API endpoint
 * @param token The Polymer API authentication token
 * @param chainId The chain ID where the event occurred
 * @param blockNumber The block number where the event occurred
 * @param transactionIndex The transaction index in the block
 * @param logIndex The log index in the transaction
 * @param logger Optional logger for detailed logging
 * @returns The proof as a hex string, or undefined if retrieval failed
 */
export async function fetchProof(
  endpoint: string,
  token: string,
  chainId: number,
  blockNumber: number,
  transactionIndex: number,
  logIndex: number,
  logger?: Logger
): Promise<string | undefined> {
  try {
    // Request the proof generation
    const jobId = await requestProof(
      endpoint,
      token,
      chainId,
      blockNumber,
      transactionIndex,
      logIndex,
      logger
    );
    
    if (jobId === undefined) {
      logger?.error({
        chainId,
        blockNumber,
        transactionIndex,
        logIndex
      }, 'Failed to get job ID for proof request');
      return undefined;
    }
    
    // Query the proof status and retrieve when ready
    let attempts = 0;
    while (attempts < MAX_QUERY_ATTEMPTS) {
      const result = await queryProof(endpoint, token, jobId, logger);
      
      if (!result) {
        logger?.warn({ jobId }, 'Received empty result from query proof');
        attempts++;
        await sleep(QUERY_DELAY_MS);
        continue;
      }
      
      if (result.status === 'ready' || result.status === 'complete') {
        if (!result.proof) {
          logger?.error({ jobId }, 'Proof is ready but empty');
          return undefined;
        }
        
        // Decode the base64 proof to a hex string
        const proofBytes = Buffer.from(result.proof, 'base64');
        return '0x' + proofBytes.toString('hex');
      }
      
      logger?.debug({ 
        jobId, 
        status: result.status,
        attempt: attempts + 1
      }, 'Proof not ready yet, waiting...');
      
      attempts++;
      await sleep(QUERY_DELAY_MS);
    }
    
    logger?.error({ 
      jobId,
      maxAttempts: MAX_QUERY_ATTEMPTS
    }, 'Exceeded maximum attempts waiting for proof');
    
    return undefined;
    
  } catch (error) {
    logger?.error({
      chainId,
      blockNumber,
      transactionIndex,
      logIndex,
      error: error instanceof Error ? error.message : String(error)
    }, 'Error fetching Polymer proof');
    
    return undefined;
  }
}

/**
 * Request a proof generation from the Polymer API
 * 
 * @returns The job ID for the proof request, or undefined if the request failed
 */
async function requestProof(
  endpoint: string,
  token: string,
  chainId: number,
  blockNumber: number,
  transactionIndex: number,
  logIndex: number,
  logger?: Logger
): Promise<number | undefined> {
  try {
    const headers = {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    };
    
    const params: RequestProofParams = {
      jsonrpc: '2.0',
      id: 1,
      method: 'log_requestProof',
      params: [chainId, blockNumber, transactionIndex, logIndex]
    };
    
    logger?.debug({ 
      chainId, 
      blockNumber, 
      transactionIndex, 
      logIndex 
    }, 'Requesting Polymer proof');
    
    const response = await axios.post(endpoint, params, { headers });
    
    const data = response.data as RequestProofResponse;
    
    if (data.error) {
      logger?.error({ 
        error: data.error.message,
        code: data.error.code
      }, 'Error from Polymer API when requesting proof');
      return undefined;
    }
    
    logger?.debug({ jobId: data.result }, 'Successfully requested proof');
    
    return data.result;
    
  } catch (error) {
    logger?.error({
      chainId,
      blockNumber,
      transactionIndex,
      logIndex,
      error: error instanceof Error ? error.message : String(error)
    }, 'Error requesting proof from Polymer API');
    
    return undefined;
  }
}

/**
 * Query the status of a proof request
 * 
 * @returns The proof result, or undefined if the query failed
 */
async function queryProof(
  endpoint: string,
  token: string,
  jobId: number,
  logger?: Logger
): Promise<QueryProofResult | undefined> {
  try {
    const headers = {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    };
    
    const params: QueryProofParams = {
      jsonrpc: '2.0',
      id: 1,
      method: 'log_queryProof',
      params: [jobId]
    };
    
    logger?.debug({ jobId }, 'Querying proof status');
    
    const response = await axios.post(endpoint, params, { headers });
    
    const data = response.data as QueryProofResponse;
    
    if (data.error) {
      logger?.error({ 
        jobId,
        error: data.error.message,
        code: data.error.code
      }, 'Error from Polymer API when querying proof');
      return undefined;
    }
    
    return data.result;
    
  } catch (error) {
    logger?.error({
      jobId,
      error: error instanceof Error ? error.message : String(error)
    }, 'Error querying proof from Polymer API');
    
    return undefined;
  }
}

/**
 * Sleep for the specified number of milliseconds
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}
