import { chainWrapper } from './chain';
import { randomBytes } from 'crypto';

////////////////////////////////////////
// Generators

/**
 * Gets a random bytes32
 *
 * @returns A random/valid bytes32 string
 */
export const getRandomBytes32 = (): string => chainWrapper.toHex(randomBytes(32));

/**
 * Converts a 20-byte (or other length) ID to a 32-byte ID.
 * Ensures that a bytes-like is 32 long. left-padding with 0s if not.
 *
 * @param data A string or array of bytes to canonize
 * @returns A Uint8Array of length 32
 * @throws if the input is undefined, or not exactly 20 or 32 bytes long
 */
export function canonizeId(data?: string | Uint8Array): string {
  if (!data) throw new Error('Bad input. Undefined');

  const buf = typeof data === 'string' ? chainWrapper.fromHex(data as `0x${string}`, 'bytes') : data;
  if (buf instanceof Uint8Array) {
    if (buf.length > 32) throw new Error('Too long');
    if (buf.length !== 20 && buf.length != 32) {
      throw new Error('bad input, expect address or bytes32');
    }
    const hex = chainWrapper.toHex(buf);
    const hexWithoutPrefix = hex.replace('0x', '');
    return '0x' + hexWithoutPrefix.padStart(64, '0');
  } else {
    throw new Error('Invalid data type');
  }
}

/**
 * Converts an ID of 20 or 32 bytes to the corresponding EVM Address.
 *
 * For 32-byte IDs this enforces the EVM convention of using the LAST 20 bytes.
 *
 * @param data The data to truncate
 * @returns A 20-byte, 0x-prepended hex string representing the EVM Address
 * @throws if the data is not 20 or 32 bytes
 */
export function evmId(data: string | Uint8Array): string {
  const u8a = typeof data === 'string' ? chainWrapper.fromHex(data as `0x${string}`, 'bytes') : data;

  if (u8a instanceof Uint8Array) {
    if (u8a.length === 32) {
      const sliced = u8a.slice(12, 32);
      return chainWrapper.toHex(sliced);
    } else if (u8a.length === 20) {
      return chainWrapper.toHex(u8a);
    } else {
      throw new Error(`Invalid id length. expected 20 or 32. Got ${u8a.length}`);
    }
  } else {
    throw new Error('Invalid data type');
  }
}
