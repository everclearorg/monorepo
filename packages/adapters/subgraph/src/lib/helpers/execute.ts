import { gql } from 'graphql-request';
import { DocumentInvalid } from '../errors';
import { getBlockNumberQuery } from '../operations';
import { isFulfilled, isRejected } from '../types';
import { gqlRequest } from './mockable';

const rejectAfterDelay = (ms: number) =>
  new Promise((_, reject) => {
    setTimeout(reject, ms, new Error('timeout'));
  });

const fulfilledWithinTimeout = async (promises: Promise<any>[], timeout: number): Promise<any[]> => {
  return await Promise.allSettled(promises.map((promise) => Promise.race([promise, rejectAfterDelay(timeout)])));
};

const addBlockNumberQuery = (queries: string[]): string[] => {
  for (const query of queries) {
    if (query.includes('hasIndexingErrors')) {
      return queries;
    }
  }

  return [...queries, getBlockNumberQuery()];
};

const chooseHighestBlockNumber = (results: any[]) => {
  let maxBlockNumber = 0;
  let withMaxBlockIdx = -1;
  for (let i = 0; i < results.length; i++) {
    const data = results[i];
    const blockNumber = (data as any)?._meta?.block?.number ?? 0;
    if (blockNumber > maxBlockNumber) {
      withMaxBlockIdx = i;
      maxBlockNumber = blockNumber;
    }
  }

  return withMaxBlockIdx > -1 ? results[withMaxBlockIdx] : undefined;
};

export const execute = async <T = any>(
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
