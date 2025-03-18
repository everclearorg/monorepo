use anchor_lang::prelude::*;

use crate::error::SpokeError;

use crate::intent::EVMIntent;

pub(crate) fn normalize_decimals(
    amount: u64,
    minted_decimals: u8,
    target_decimals: u8,
) -> Result<u64> {
    if minted_decimals == target_decimals {
        // No scaling needed
        Ok(amount)
    } else if minted_decimals > target_decimals {
        // e.g. minted_decimals=9, target_decimals=6 => downscale
        let shift = minted_decimals - target_decimals;
        // prevent potential divide-by-zero or overshoot
        if shift > 12 {
            // you might fail or just saturate for large differences
            return err!(SpokeError::DecimalConversionOverflow);
        }
        Ok(amount / 10u64.pow(shift as u32))
    } else {
        // minted_decimals < target_decimals => upscale
        let shift = target_decimals - minted_decimals;
        // watch for overflow if we do big multiplications
        let factor = 10u64
            .checked_pow(shift as u32)
            .ok_or(error!(SpokeError::DecimalConversionOverflow))?;
        let scaled = amount
            .checked_mul(factor)
            .ok_or(error!(SpokeError::DecimalConversionOverflow))?;
        Ok(scaled)
    }
}

/// Minimal keccak256 using the tiny_keccak crate.
fn keccak_256(data: &[u8]) -> [u8; 32] {
    use tiny_keccak::{Hasher, Keccak};
    let mut hasher = Keccak::v256();
    hasher.update(data);
    let mut output = [0u8; 32];
    hasher.finalize(&mut output);
    output
}

pub fn compute_intent_hash(intent: &EVMIntent) -> [u8; 32] {
    let encoded = encode_single_intent(intent);
    keccak_256(&encoded)
}

pub(crate) fn encode_single_intent(intent: &EVMIntent) -> Vec<u8>  {
    let mut out = Vec::new();
    let mut head = Vec::new();

    // 1) Initiator
    head.extend_from_slice(intent.initiator.as_ref());

    // 2) Receiver
    head.extend_from_slice(intent.receiver.as_ref());

    // 3) InputAsset
    head.extend_from_slice(intent.input_asset.as_ref());

    // 4) OutputAsset
    head.extend_from_slice(intent.output_asset.as_ref());

    // 5) maxFee
    head.extend_from_slice(&intent.max_fee.to_be_bytes());

    // 6) originDomain
    head.extend_from_slice(&intent.origin.to_be_bytes());

    // 7) nonce
    head.extend_from_slice(&intent.nonce.to_be_bytes());

    // 8) timestamp
    head.extend_from_slice(&intent.timestamp.to_be_bytes());

    // 9) ttl
    head.extend_from_slice(&intent.ttl.to_be_bytes());

    // 10) normalizedAmount
    head.extend_from_slice(&intent.amount);

    let (tail, dest_offset, data_offset) = encode_struct_tail(intent);

    // word10: offset to destinations
    head.extend_from_slice(&u256_to_32bytes(dest_offset as u128));

    // word11: offset to data
    head.extend_from_slice(&u256_to_32bytes(data_offset as u128));

    // Now place the entire head (384 bytes) first
    out.extend_from_slice(&head);
    // Then place the tail
    out.extend_from_slice(&tail);

    out
}

fn encode_struct_tail(intent: &EVMIntent) -> (Vec<u8>, u64, u64) {
    let mut tail = Vec::new();
    // The offset for the first dynamic field is 384 bytes (12×32) from the start of the struct
    let destinations_offset = 384;
    // We'll encode the destinations first, then we know where the data will go
    let mut destinations_bytes = Vec::new();

    // 1) destinations: 
    //   - 32 bytes array length
    //   - each element occupies one full 32‐byte word
    destinations_bytes.extend_from_slice(&u256_to_32bytes(intent.destinations.len() as u128));
    for &val in intent.destinations.iter() {
        destinations_bytes.extend_from_slice(&u256_to_32bytes(val as u128));
    }

    let data_offset = destinations_offset + destinations_bytes.len() as u64;

    // 2) data (bytes)
    let mut data_bytes = Vec::new();
    // 32 bytes => length
    data_bytes.extend_from_slice(&u256_to_32bytes(intent.data.len() as u128));
    data_bytes.extend_from_slice(&intent.data);
    // pad to multiple of 32
    let padding = (32 - (intent.data.len() % 32)) % 32;
    data_bytes.extend(std::iter::repeat(0u8).take(padding));

    tail.extend_from_slice(&destinations_bytes);
    tail.extend_from_slice(&data_bytes);

    (tail, destinations_offset, data_offset)
}

fn u256_to_32bytes(val: u128) -> [u8; 32] {
    let mut word = [0u8; 32];
    // big-endian => fill from the right
    for i in 0..16 {
        word[31 - i] = (val >> (8 * i)) as u8;
    }
    word
}