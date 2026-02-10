/* eslint-disable @typescript-eslint/no-explicit-any */
import { chainWrapper } from '../chain';

export const aggregatorV3InterfaceABI = [
  {
    inputs: [],
    name: 'decimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'description',
    outputs: [{ internalType: 'string', name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint80', name: '_roundId', type: 'uint80' }],
    name: 'getRoundData',
    outputs: [
      { internalType: 'uint80', name: 'roundId', type: 'uint80' },
      { internalType: 'int256', name: 'answer', type: 'int256' },
      { internalType: 'uint256', name: 'startedAt', type: 'uint256' },
      { internalType: 'uint256', name: 'updatedAt', type: 'uint256' },
      { internalType: 'uint80', name: 'answeredInRound', type: 'uint80' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'latestRoundData',
    outputs: [
      { internalType: 'uint80', name: 'roundId', type: 'uint80' },
      { internalType: 'int256', name: 'answer', type: 'int256' },
      { internalType: 'uint256', name: 'startedAt', type: 'uint256' },
      { internalType: 'uint256', name: 'updatedAt', type: 'uint256' },
      { internalType: 'uint80', name: 'answeredInRound', type: 'uint80' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'version',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
];

/**
 * Get the token price from the chainlink price feed.
 * @param domain - The domain id.
 * @param priceFeed - The data feed contract address.
 * @param chainReaderReadTx - Function wrapper for ChainReader.readTx.
 * @param chainReaderDomain - Domain ID.
 */
export const getTokenPriceFromChainlink = async (
  domain: string,
  priceFeed: string,
  chainReaderReadTx: (params: { to: string; domain: number; data: `0x${string}`; funcSig: string }) => Promise<string>,
  chainReaderDomain: number,
): Promise<number> => {
  const encodedResult = await chainReaderReadTx({
    to: priceFeed,
    domain: chainReaderDomain,
    data: chainWrapper.encodeFunctionData({
      abi: aggregatorV3InterfaceABI,
      functionName: 'latestRoundData',
    }),
    funcSig: 'latestRoundData()',
  });

  const result = chainWrapper.decodeFunctionResult({
    abi: aggregatorV3InterfaceABI,
    functionName: 'latestRoundData',
    data: encodedResult as `0x${string}`,
  }) as [bigint, bigint, bigint, bigint, bigint];

  const answer = result[1];
  return +chainWrapper.formatUnits(answer, 8);
};
