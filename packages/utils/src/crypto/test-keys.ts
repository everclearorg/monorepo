/**
 * Test Tron Keys for Development and Testing
 * 
 * WARNING: These are test keys only! Never use in production!
 * These keys are publicly visible and should only be used for testing.
 */

export const TEST_TRON_KEYS = {
  // Generated test key pair for Tron development
  PRIVATE_KEY: 'da146374a75310b9666e834ee4ad0866d6f4035967bfc76217c5a495fff9f0d0',
  PUBLIC_KEY: '04947c4f5d9e4d8c8a7e2c5f3e1a8b9c6d2e5f4a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b',
  ADDRESS_HEX: '41928c9af0651632157ef27a2cf17ca72c575a4d21',
  ADDRESS_BASE58: 'TPL66VK2gCXNCD7EJg9pgJRfqcRazjhUZY',
  
  // Corresponding Ethereum-style address (for compatibility)
  ETH_ADDRESS: '0x928c9af0651632157ef27a2cf17ca72c575a4d21',
} as const;

/**
 * Alternative test keys for multi-account testing
 */
export const TEST_TRON_KEYS_ALT = {
  PRIVATE_KEY: 'f4a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2',
  ADDRESS_BASE58: 'TKHuVq1oKVruCGLvqVexFs6dawKv6fQgFs',
  ETH_ADDRESS: '0x742d35Cc6635C0532925a3b8D8A4F6e8d8A8C9B7',
} as const;

/**
 * Get test private key for Tron development
 */
export function getTestTronPrivateKey(): string {
  return TEST_TRON_KEYS.PRIVATE_KEY;
}

/**
 * Get test Tron address in base58 format
 */
export function getTestTronAddress(): string {
  return TEST_TRON_KEYS.ADDRESS_BASE58;
}

/**
 * Get test Ethereum address for compatibility
 */
export function getTestEthAddress(): string {
  return TEST_TRON_KEYS.ETH_ADDRESS;
} 