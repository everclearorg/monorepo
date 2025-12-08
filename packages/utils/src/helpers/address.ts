import { chainWrapper, type ViemAddress as Address } from '../helpers/chain';
import { publicKeyConvert } from 'secp256k1';

/**
 * Function to derive the address from an EC public key
 *
 * @param publicKey the public key to derive
 *
 * @returns the address
 */
export const getAddressFromPublicKey = (publicKey: string): Address => {
  let key = publicKey.replace(/^0x/, '');

  // Validate that the key contains only valid hex characters
  if (!/^[0-9a-fA-F]+$/.test(key)) {
    throw new Error('Invalid public key: contains non-hex characters');
  }

  // Ensure we have the uncompressed format (04 prefix (optional) + 64 bytes)
  if (key.length === 130 && key.startsWith('04')) {
    key = key.slice(2);
  } else if (key.length !== 128) {
    throw new Error('Invalid public key format');
  }

  // Hash the 64-byte public key with Keccak256
  const hash = chainWrapper.keccak256(`0x${key}`);

  // Take the last 20 bytes (40 hex characters) as the address
  const address = `0x${hash.slice(-40)}`;

  return chainWrapper.getAddress(address);
};

/**
 * Converts a public key to its compressed form.
 */
export const compressPublicKey = (publicKey: string): Uint8Array => {
  publicKey = publicKey.replace(/^0x/, '');
  // if there are more bytes than the key itself, it means there is already a prefix
  if (publicKey.length % 32 === 0) {
    publicKey = `04${publicKey}`;
  }
  return publicKeyConvert(Buffer.from(publicKey, 'hex'));
};
