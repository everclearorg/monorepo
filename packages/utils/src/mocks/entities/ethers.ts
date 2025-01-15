import { providers, BigNumber } from 'ethers';
import { mkAddress, mkHash } from '../mk';

const transactionRequest = (overrides: Partial<providers.TransactionRequest> = {}): providers.TransactionRequest => ({
  to: mkAddress('0xbbbb'),
  from: mkAddress('0xaaa'),
  data: mkHash('0xdef'),
  value: BigNumber.from('1'),
  ...overrides,
});

const transactionResponse = (overrides: Partial<providers.TransactionResponse> = {}): providers.TransactionResponse => {
  const response = {
    chainId: 123123,
    confirmations: 0,
    data: '0x',
    to: mkAddress('0xbbbb'),
    from: mkAddress('0xaaa'),
    gasLimit: BigNumber.from('21000000'),
    gasPrice: BigNumber.from('1'),
    hash: mkHash('0xdef'),
    nonce: 1,
    value: BigNumber.from('0'),
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

const transactionReceipt = (overrides: Partial<providers.TransactionReceipt> = {}): providers.TransactionReceipt => ({
  to: mkAddress('0xaaa'),
  from: mkAddress('0xbbb'),
  contractAddress: mkAddress('0xa'),
  transactionIndex: 1,
  gasUsed: BigNumber.from('21000'),
  logsBloom: '0x',
  blockHash: mkHash('0xabc'),
  transactionHash: mkHash('0xdef'),
  logs: [],
  blockNumber: 123,
  confirmations: 1,
  cumulativeGasUsed: BigNumber.from(21000),
  effectiveGasPrice: BigNumber.from('1'),
  byzantium: true,
  type: 1,
  status: 1,
  ...overrides,
});

const getAssociatedTransactions = (
  overrides: Partial<providers.TransactionRequest> = {},
): {
  request: providers.TransactionRequest;
  response: providers.TransactionResponse;
  receipt: providers.TransactionReceipt;
} => {
  const request = transactionRequest(overrides);
  const { nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, gasPrice, data, to, value, chainId, from, type } =
    request;
  const response = transactionResponse({
    to,
    chainId,
    from,
    type,
    nonce: BigNumber.from(nonce ?? 1).toNumber(),
    gasLimit: BigNumber.from(gasLimit ?? 800_000),
    gasPrice: BigNumber.from(gasPrice ?? 1),
    data: data?.toString() ?? '0x',
    value: BigNumber.from(value ?? 0),
    maxPriorityFeePerGas: maxPriorityFeePerGas ? BigNumber.from(maxPriorityFeePerGas) : undefined,
    maxFeePerGas: maxFeePerGas ? BigNumber.from(maxPriorityFeePerGas) : undefined,
  });
  const { hash, blockNumber, blockHash } = response;
  const receipt = transactionReceipt({
    to,
    from,
    transactionHash: hash,
    blockHash,
    blockNumber,
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
