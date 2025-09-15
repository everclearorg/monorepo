/* eslint-disable @typescript-eslint/no-explicit-any */
import { mkAddress, mkHash } from '../mk';

// Define viem-compatible types
type TransactionRequest = {
  to: string;
  from: string;
  data: string;
  value: bigint;
  chainId?: number;
  nonce?: number;
  gasLimit?: bigint;
  gasPrice?: bigint;
  maxPriorityFeePerGas?: bigint;
  maxFeePerGas?: bigint;
  type?: number;
};

type TransactionResponse = {
  chainId: number;
  confirmations: number;
  data: string;
  to: string;
  from: string;
  gasLimit: bigint;
  gasPrice: bigint;
  hash: string;
  nonce: number;
  value: bigint;
  type: number;
  wait: () => Promise<TransactionReceipt>;
};

type TransactionReceipt = {
  to: string;
  from: string;
  contractAddress: string;
  transactionIndex: number;
  gasUsed: bigint;
  logsBloom: string;
  blockHash: string;
  transactionHash: string;
  logs: any[];
  blockNumber: number;
  confirmations: number;
  cumulativeGasUsed: bigint;
  effectiveGasPrice: bigint;
  byzantium: boolean;
  type: number;
  status: number;
};

const transactionRequest = (overrides: Partial<TransactionRequest> = {}): TransactionRequest => ({
  to: mkAddress('0xbbbb'),
  from: mkAddress('0xaaa'),
  data: mkHash('0xdef'),
  value: 1n,
  ...overrides,
});

const transactionResponse = (overrides: Partial<TransactionResponse> = {}): TransactionResponse => {
  const response = {
    chainId: 123123,
    confirmations: 0,
    data: '0x',
    to: mkAddress('0xbbbb'),
    from: mkAddress('0xaaa'),
    gasLimit: 21000000n,
    gasPrice: 1n,
    hash: mkHash('0xdef'),
    nonce: 1,
    value: 0n,
    type: 1,
    ...overrides,
  };
  return {
    ...response,
    wait: () =>
      Promise.resolve(
        transactionReceipt({
          transactionHash: response.hash,
          from: response.from,
          to: response.to,
        }),
      ),
  };
};

const transactionReceipt = (overrides: Partial<TransactionReceipt> = {}): TransactionReceipt => ({
  to: mkAddress('0xaaa'),
  from: mkAddress('0xbbb'),
  contractAddress: mkAddress('0xa'),
  transactionIndex: 1,
  gasUsed: 21000n,
  logsBloom: '0x',
  blockHash: mkHash('0xabc'),
  transactionHash: mkHash('0xdef'),
  logs: [],
  blockNumber: 123,
  confirmations: 1,
  cumulativeGasUsed: 21000n,
  effectiveGasPrice: 1n,
  byzantium: true,
  type: 1,
  status: 1,
  ...overrides,
});

const getAssociatedTransactions = (
  overrides: Partial<TransactionRequest> = {},
): {
  request: TransactionRequest;
  response: TransactionResponse;
  receipt: TransactionReceipt;
} => {
  const request = transactionRequest(overrides);
  const { nonce, gasLimit, gasPrice, data, to, value, chainId, from, type } = request;
  const response = transactionResponse({
    to,
    chainId,
    from,
    type,
    nonce: nonce ?? 1,
    gasLimit: gasLimit ?? 800_000n,
    gasPrice: gasPrice ?? 1n,
    data: data?.toString() ?? '0x',
    value: value ?? 0n,
  });
  const { hash } = response;
  const receipt = transactionReceipt({
    to,
    from,
    transactionHash: hash,
    type,
  });
  return { request, response, receipt };
};

export const ethers = {
  request: transactionRequest,
  response: transactionResponse,
  receipt: transactionReceipt,
  transactions: getAssociatedTransactions,
};
