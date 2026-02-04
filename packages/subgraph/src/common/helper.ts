/* eslint-disable */
import { Address, BigInt, ByteArray, Bytes, ethereum } from '@graphprotocol/graph-ts';

export function generateTxNonce(event: ethereum.Event): BigInt {
  return event.block.timestamp.times(BigInt.fromI32(10000)).plus(event.logIndex);
}

export function generateIdFromTx(event: ethereum.Event): Bytes {
  return event.transaction.hash.concatI32(event.logIndex.toI32());
}

export function BigIntToBytes(int: BigInt): Bytes {
  return Bytes.fromByteArray(Bytes.fromBigInt(int));
}

export function ConcatBigIntsToBytes(int1: BigInt, int2: BigInt): Bytes {
  return Bytes.fromByteArray(Bytes.fromBigInt(int1).concat(Bytes.fromUTF8('-')).concat(Bytes.fromBigInt(int2)));
}

export function Bytes32ToAddress(bytes32: Bytes): Address {
  let addressBytes = new Bytes(20);
  for (let i = 0; i < 20; i++) {
    addressBytes[i] = bytes32[12 + i];
  }
  return Address.fromBytes(addressBytes);
}

/**
 * Safely gets gasPrice from a transaction, handling EIP-1559 transactions where gasPrice may be null.
 * For EIP-1559 transactions where gasPrice is null, uses BigInt.zero() as fallback.
 * Note: In practice, The Graph's indexer should provide gasPrice for all transactions,
 * but this handles edge cases where it might be null.
 *
 * @param transaction - The transaction object
 * @returns The gas price as BigInt (never null)
 */
export function getGasPrice(transaction: ethereum.Transaction): BigInt {
  // For legacy transactions, gasPrice is always set
  // For EIP-1559 transactions, gasPrice may be null, so we provide a fallback
  // AssemblyScript requires explicit handling of nullable types - use changetype after null check
  const gasPriceValue = transaction.gasPrice;
  if (gasPriceValue === null) {
    return BigInt.zero();
  }
  return changetype<BigInt>(gasPriceValue);
}
