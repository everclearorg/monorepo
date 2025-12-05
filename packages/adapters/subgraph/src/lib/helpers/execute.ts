import { gql, GraphQLClient } from 'graphql-request';
import { DocumentInvalid } from '../errors';
import { getBlockNumberQuery } from '../operations';
import { isFulfilled, isRejected } from '../types';
import { gqlRequest } from './mockable';
import { SubgraphConfig } from '../entities';

const rejectAfterDelay = (ms: number) =>
  new Promise((_, reject) => {
    setTimeout(reject, ms, new Error('timeout'));
  });

const fulfilledWithinTimeout = async <T>(
  promises: Promise<T>[],
  timeout: number,
): Promise<PromiseSettledResult<T | Error>[]> => {
  return (await Promise.allSettled(
    promises.map((promise) => Promise.race([promise, rejectAfterDelay(timeout)])),
  )) as PromiseSettledResult<T | Error>[];
};

const addBlockNumberQuery = (queries: string[]): string[] => {
  for (const query of queries) {
    if (query.includes('hasIndexingErrors')) {
      return queries;
    }
  }

  return [...queries, getBlockNumberQuery()];
};

const chooseHighestBlockNumber = <T>(results: T[]): T | undefined => {
  let maxBlockNumber = 0;
  let withMaxBlockIdx = -1;
  for (let i = 0; i < results.length; i++) {
    const data = results[i] as Record<string, unknown>;
    const blockNumber =
      ((data._meta as Record<string, unknown>)?.block as Record<string, unknown>)?.number ?? 0;
    if (typeof blockNumber === 'number' && blockNumber > maxBlockNumber) {
      withMaxBlockIdx = i;
      maxBlockNumber = blockNumber;
    }
  }

  return withMaxBlockIdx > -1 ? results[withMaxBlockIdx] : undefined;
};

export const execute = async <T = Record<string, unknown>>(
  domain: string,
  queries: string[],
  endpoints: string[],
  timeout = 10_000,
): Promise<T | undefined> => {
  const addedBlockNumber = addBlockNumberQuery(queries);
  const results = await fulfilledWithinTimeout(
    endpoints.map((endpoint: string) => {
      const query = gql`{
          ${addedBlockNumber.reduce((acc, chunk) => `${acc}${chunk}`, ``)}
        }`;
      return gqlRequest(endpoint, query);
    }),
    timeout,
  );

  const fulfilled = results.filter(isFulfilled).map(({ value }) => value);
  const errors = results.filter(isRejected).map(({ reason }) => reason);

  if (fulfilled.length === 0) {
    throw new DocumentInvalid({ domain, errors: JSON.stringify(errors) });
  } else if (fulfilled.length === 1) {
    return fulfilled[0] as T;
  } else {
    return chooseHighestBlockNumber(fulfilled) as T;
  }
};

/**
 * Execute a GraphQL query against Envio HyperIndex
 * Envio is multichain and environment-specific (not domain-specific like Goldsky)
 *
 * @param config - SubgraphConfig containing Envio configuration
 * @param query - GraphQL query string
 * @param variables - Optional query variables
 * @returns Query result
 */
export const executeEnvioQuery = async <T = Record<string, unknown>>(
  config: SubgraphConfig,
  query: string,
  variables?: Record<string, unknown>,
): Promise<T> => {
  if (!config.envio?.url) {
    throw new Error('Envio configuration is missing. Please provide envio.url in SubgraphConfig.');
  }

  // Build headers only if an API key is provided and not a placeholder value
  // Note: The hosted Envio endpoint (indexer.hyperindex.xyz) does not require authentication
  const headers: Record<string, string> = {};
  if (
    config.envio.apiKey &&
    config.envio.apiKey.trim() !== '' &&
    config.envio.apiKey !== 'testing' &&
    !config.envio.url.includes('indexer.hyperindex.xyz')
  ) {
    headers['x-hasura-admin-secret'] = config.envio.apiKey;
  }

  const client = new GraphQLClient(config.envio.url, {
    headers,
  });

  const timeout = (config.envio.timeout || 10) * 1000; // Convert to milliseconds

  const results = await fulfilledWithinTimeout(
    [client.request<T>(query, variables)],
    timeout,
  );

  const fulfilled = results.filter(isFulfilled).map(({ value }) => value);
  const errors = results.filter(isRejected).map(({ reason }) => reason);

  if (fulfilled.length === 0) {
    const errorMessage = errors.length > 0 ? errors[0]?.message || 'Unknown error' : 'Envio query timeout';
    throw new Error(`Envio query failed: ${errorMessage}`);
  }

  return fulfilled[0] as T;
};
