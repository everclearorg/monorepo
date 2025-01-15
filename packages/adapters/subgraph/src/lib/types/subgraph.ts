export type SubgraphQueryMetaParams = {
  maxBlockNumber: number;
  latestNonce: number;
  destinationDomains?: string[];
  orderDirection?: 'asc' | 'desc';
  limit?: number;
};

export type SubgraphQueryByTimestampMetaParams = {
  maxBlockNumber?: number;
  fromTimestamp: number;
  destinationDomains?: string[];
  orderDirection?: 'asc' | 'desc';
  limit?: number;
};

export type SubgraphQueryByTransferIDsMetaParams = {
  maxBlockNumber: number;
  transferIDs: string[];
};

export type SubgraphQueryByNoncesMetaParams = {
  maxBlockNumber: number;
  nonces: string[];
};

export interface QueryResponse<T> {
  domain: string;
  data: T;
}

export const isRejected = (input: PromiseSettledResult<unknown>): input is PromiseRejectedResult =>
  input.status === 'rejected';

export const isFulfilled = <T>(input: PromiseSettledResult<T>): input is PromiseFulfilledResult<T> =>
  input.status === 'fulfilled';
