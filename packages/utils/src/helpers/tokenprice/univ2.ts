import { Interface, formatUnits } from 'ethers/lib/utils';
import { providers } from 'ethers';
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
 * @returns The token0 price
 */
export const getTokenPriceFromUniV2 = async (
  domain: string,
  pair: string,
  token0: AssetConfig,
  token1: AssetConfig,
  provier: providers.JsonRpcProvider,
): Promise<number> => {
  const univ2PairIface = new Interface(univ2PairABI);
  const encodedDataForGetReserves = univ2PairIface.encodeFunctionData('getReserves');

  const encodedResultData = await provier.call(
    {
      to: pair,
      chainId: +domain,
      data: encodedDataForGetReserves,
    },
    'latest',
  );

  const [reserve0, reserve1] = univ2PairIface.decodeFunctionResult('getReserves', encodedResultData);

  const readableReserve0 = formatUnits(reserve0, token0.decimals);
  const readableReserve1 = formatUnits(reserve1, token1.decimals);

  return +readableReserve1 / +readableReserve0;
};
