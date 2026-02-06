/* eslint-disable @typescript-eslint/no-explicit-any */
import { chainWrapper } from '../chain';
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
 * @param chainReaderReadTx - Function wrapper for ChainReader.readTx.
 * @param chainReaderDomain - Domain ID.
 * @returns The token0 price
 */
export const getTokenPriceFromUniV2 = async (
  domain: string,
  pair: string,
  token0: AssetConfig,
  token1: AssetConfig,
  chainReaderReadTx: (params: { to: string; domain: number; data: `0x${string}`; funcSig: string }) => Promise<string>,
  chainReaderDomain: number,
): Promise<number> => {
  const encodedResult = await chainReaderReadTx({
    to: pair,
    domain: chainReaderDomain,
    data: chainWrapper.encodeFunctionData({
      abi: univ2PairABI,
      functionName: 'getReserves',
    }),
    funcSig: 'getReserves()',
  });

  const result = chainWrapper.decodeFunctionResult({
    abi: univ2PairABI,
    functionName: 'getReserves',
    data: encodedResult as `0x${string}`,
  }) as [bigint, bigint, number];

  const reserve0 = result[0];
  const reserve1 = result[1];

  const readableReserve0 = chainWrapper.formatUnits(reserve0, token0.decimals);
  const readableReserve1 = chainWrapper.formatUnits(reserve1, token1.decimals);

  return +readableReserve1 / +readableReserve0;
};
