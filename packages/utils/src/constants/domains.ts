/**
 * @dev These constants should go into the configuration package by default.
 * Hardcodeing for ease of use now.
 */
// NOTE: EVM chains (i.e. chains with a chainId) will have domain == chainId
const MAINNET_CHAINID_TO_DOMAIN_MAPPING: Map<number, number> = new Map([
  // mainnets
  [1, 1], // Ethereum
  [10, 10], // Optimism
  [56, 56], // BNB Chain
  [100, 100], // Gnosis Chain
  [137, 137], // Polygon
  [42161, 42161], // Arbitrum One
  [324, 324], // zkSync2 Mainnet
  [1101, 1101], // Polygon zkEvm Mainnet
  [59144, 59144], // Consensys Linea Mainnet
  [8453, 8453], // Base Mainnet
  [43114, 43114], // Avalanche C-Chain
  [1088, 1088], // Metis Andromeda
  [5000, 5000], // Mantle
  [34443, 34443], // Mode
  [534352, 534352], // Scroll
  [196, 196], // X Layer Mainnet
  [25327, 25327], // Everclear Mainnet
  [48900, 48900], // Zircuit Mainnet
  [81457, 81457], // Blast mainnet
]);

const TESTNET_CHAINID_TO_DOMAIN_MAPPING: Map<number, number> = new Map([
  // testnets
  [10200, 10200], // gnosis-chiado
  [97, 97], // chapel
  [280, 280], // zkSync2 Testnet
  [1442, 1442], // Polygon zkEvm test
  [195, 195], // X1 Testnet
  [11155111, 11155111], // Sepolia
  [11155420, 11155420], // Optimism sepolia
  [421614, 421614], // Arbitrum sepolia
  [44787, 44787], // Celo Alfajores
  [534351, 534351], // Scroll sepolia
  [6398, 6398], //Everclear sepolia
  [168587773, 168587773], //Blast sepolia
]);

const DEVNET_CHAINID_TO_DOMAIN_MAPPING: Map<number, number> = new Map([
  // local
  [1337, 1337],
  [1338, 1338],
  [1339, 1339],
  [13337, 13337],
  [13338, 13338],
  [31337, 31337],
  [31338, 31338],
  [31339, 31339],
]);

// Hex domains calculated using `getHexDomainFromString`
// alternative: ethers.BigNumber.from(ethers.utils.toUtf8Bytes("some string")).toNumber()
export const chainIdToDomainMapping: Map<number, number> = new Map([
  ...MAINNET_CHAINID_TO_DOMAIN_MAPPING.entries(),
  ...TESTNET_CHAINID_TO_DOMAIN_MAPPING.entries(),
  ...DEVNET_CHAINID_TO_DOMAIN_MAPPING.entries(),
]);

export const chainIds: Array<number> = [
  ...MAINNET_CHAINID_TO_DOMAIN_MAPPING.keys(),
  ...TESTNET_CHAINID_TO_DOMAIN_MAPPING.keys(),
  ...DEVNET_CHAINID_TO_DOMAIN_MAPPING.keys(),
];

/**
 * Converts a chain id (listed at at chainlist.org) to a domain.
 *
 * @param chainId A chain id number
 * @returns A domain number in decimal
 */
export function chainIdToDomain(chainId: number): number {
  if (!chainIdToDomainMapping.has(chainId)) throw new Error(`Cannot find corresponding domain for chainId ${chainId}`);

  return chainIdToDomainMapping.get(chainId)!;
}

/**
 * Converts a domain id  to a chain id. (listed at at chainlist.org)
 *
 * @param domainId A domain id number
 * @returns A chain id
 */
export function domainToChainId(domainId: number | string): number {
  const domains = [...chainIdToDomainMapping.entries()];
  const [chainId] = domains.find(([domain]) => domain === +domainId) ?? [];

  if (chainId == undefined) {
    throw new Error(`Cannot find corresponding chainId for domain ${domainId}`);
  }

  return chainId;
}

export function isMainnetDomain(domainId: number): boolean {
  return MAINNET_CHAINID_TO_DOMAIN_MAPPING.has(domainToChainId(domainId));
}

export function isTestnetDomain(domainId: number): boolean {
  return TESTNET_CHAINID_TO_DOMAIN_MAPPING.has(domainToChainId(domainId));
}
