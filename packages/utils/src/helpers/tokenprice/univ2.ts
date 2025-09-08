/* eslint-disable @typescript-eslint/no-explicit-any */
import { chainWrapper, type PublicClient } from '../chain';
import { AssetConfig } from '../../types';
export const univ2PairABI = [
  {
    constant: true,
    inputs: [],
    name: 'getReserves',
    outputs: [
      { internalType: 'uint112', name: '_reserve0', type: 'uint112' },
      { internalType: 'uint112', name: '_reserve1', type: 'uint112' },
      { internalType: 'uint32', name: '_blockTimestampLast', type: 'uint32' },
    ],
    payable: false,
    stateMutability: 'view',
    type: 'function',
  },
  {
    constant: true,
    inputs: [],
    name: 'token0',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    payable: false,
    stateMutability: 'view',
    type: 'function',
  },
  {
    constant: true,
    inputs: [],
    name: 'token1',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    payable: false,
    stateMutability: 'view',
    type: 'function',
  },
];

/**
 * Get the token price from the specified univ2 pair contract.
 * @param domain - The domain id.
 * @param pair - The pair contract address.
 * @param token0 - The token0 asset.
 * @param token1 - The token1 asset
 * @param client - The viem public client instance.
 * @returns The token0 price
 */
export const getTokenPriceFromUniV2 = async (
  domain: string,
  pair: string,
  token0: AssetConfig,
  token1: AssetConfig,
  client: PublicClient,
): Promise<number> => {
  const encodedDataForGetReserves = chainWrapper.encodeFunctionData({
    abi: univ2PairABI,
    functionName: 'getReserves',
  });

  const encodedResultData = await client.request({
    method: 'eth_call',
    params: [
      {
        to: pair as `0x${string}`,
        data: encodedDataForGetReserves,
      },
      'latest',
    ],
  });

  const result = chainWrapper.decodeFunctionResult({
    abi: univ2PairABI,
    functionName: 'getReserves',
    data: encodedResultData as `0x${string}`,
  }) as any[];
  const reserve0 = result[0];
  const reserve1 = result[1];

  const readableReserve0 = chainWrapper.formatUnits(reserve0, token0.decimals);
  const readableReserve1 = chainWrapper.formatUnits(reserve1, token1.decimals);

  return +readableReserve1 / +readableReserve0;
};
