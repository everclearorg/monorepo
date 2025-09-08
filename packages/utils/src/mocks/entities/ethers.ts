/* eslint-disable @typescript-eslint/no-explicit-any */
import { chainWrapper } from '../../helpers';
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
  value: chainWrapper.parseUnits('1', 18),
  ...overrides,
});

const transactionResponse = (overrides: Partial<TransactionResponse> = {}): TransactionResponse => {
  const response = {
    chainId: 123123,
    confirmations: 0,
    data: '0x',
    to: mkAddress('0xbbbb'),
    from: mkAddress('0xaaa'),
    gasLimit: chainWrapper.parseUnits('21000000', 0),
    gasPrice: chainWrapper.parseUnits('1', 0),
    hash: mkHash('0xdef'),
    nonce: 1,
    value: chainWrapper.parseUnits('0', 18),
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
  gasUsed: chainWrapper.parseUnits('21000', 0),
  logsBloom: '0x',
  blockHash: mkHash('0xabc'),
  transactionHash: mkHash('0xdef'),
  logs: [],
  blockNumber: 123,
  confirmations: 1,
  cumulativeGasUsed: chainWrapper.parseUnits('21000', 0),
  effectiveGasPrice: chainWrapper.parseUnits('1', 0),
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
    gasLimit: gasLimit ?? chainWrapper.parseUnits('800000', 0),
    gasPrice: gasPrice ?? chainWrapper.parseUnits('1', 0),
    data: data?.toString() ?? '0x',
    value: value ?? chainWrapper.parseUnits('0', 18),
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
