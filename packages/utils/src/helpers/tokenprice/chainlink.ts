import { Interface, formatUnits } from 'ethers/lib/utils';
import { providers } from 'ethers';

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
 * @param provider - The json rpc provider for a given domain.
 */
export const getTokenPriceFromChainlink = async (
  domain: string,
  priceFeed: string,
  provider: providers.JsonRpcProvider,
): Promise<number> => {
  const feedIface = new Interface(aggregatorV3InterfaceABI);
  const encodedData = feedIface.encodeFunctionData('latestRoundData');

  const encodedPriceResult = await provider.call(
    {
      to: priceFeed,
      chainId: +domain,
      data: encodedData,
    },
    'latest',
  );

  const [, answer, , ,] = feedIface.decodeFunctionResult('latestRoundData', encodedPriceResult);
  return +formatUnits(answer, 8);
};
