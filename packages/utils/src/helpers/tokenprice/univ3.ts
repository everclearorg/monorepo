import { AssetConfig } from '../../types';
import { Interface } from 'ethers/lib/utils';
import { providers } from 'ethers';

export const univ3PoolABI = [
  {
    inputs: [],
    name: 'slot0',
    outputs: [
      { internalType: 'uint160', name: 'sqrtPriceX96', type: 'uint160' },
      { internalType: 'int24', name: 'tick', type: 'int24' },
      { internalType: 'uint16', name: 'observationIndex', type: 'uint16' },
      { internalType: 'uint16', name: 'observationCardinality', type: 'uint16' },
      { internalType: 'uint16', name: 'observationCardinalityNext', type: 'uint16' },
      { internalType: 'uint8', name: 'feeProtocol', type: 'uint8' },
      { internalType: 'bool', name: 'unlocked', type: 'bool' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'token0',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'token1',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
];

/**
 * Get the token price from univ3 pool.
 * @param domain - The domain id.
 * @param pool - The pool address.
 * @param token0 - The token0 config.
 * @param token1 - The token1 config.
 * @returns The token0 price
 */
export const getTokenPriceFromUniV3 = async (
  domain: string,
  pool: string,
  token0: AssetConfig,
  token1: AssetConfig,
  provider: providers.JsonRpcProvider,
) => {
  /**
   * How can derive price from a tick?
   *
   * Deriving an asset price from the current tick is achievable due to the fixed expression across the pool contract of token0 in terms of token1.
   * ----------------------------------------------------------------------------------------------------------------------------------------------
   * An example of finding the price of WETH in a WETH / USDC pool, where WETH is token0 and USDC is token1:
   *
   * You have an oracle reading that shows a return of tickCumulative as [70_000, 1_070_000], with an elapsed time between the observations of 10 seconds.
   * We can derive the average tick over this interval by taking the difference in accumulator values (1_070_000 - 70_000 = 1_000_000),
   * and dividing by the time elapsed (1_000_000 / 10 = 100_000).
   *
   * With a tick reading of 100_000, we can find the value of token1 (USDC) in terms of token0 (WETH) by using the current tick as i
   * in the formula p(i) = 1.0001**i (see 6.1 in the whitepaper).
   *
   * ERC20 tokens have built in decimal values. For example, 1 WETH actually represents 10**18 WETH in the contract whereas USDC is 10**6.
   *
   * const price0 = (1.0001**tick)/(10**(Decimal1-Decimal0))
   * const price1 = 1 / price0
   *
   * For more info, refer to the uniswap docs: https://docs.uniswap.org/concepts/protocol/oracle#deriving-price-from-a-tick
   **/
  const univ3PoolIface = new Interface(univ3PoolABI);
  const encodedDataForSlot0 = univ3PoolIface.encodeFunctionData('slot0');
  const encodedResultData = await provider.call(
    {
      to: pool,
      chainId: +domain,
      data: encodedDataForSlot0,
    },
    'latest',
  );
  const [, tick] = univ3PoolIface.decodeFunctionResult('slot0', encodedResultData);

  const P = 1.0001;
  const price0 = Math.pow(P, +tick) / Math.pow(10, token1.decimals - token0.decimals);
  return price0;
};
