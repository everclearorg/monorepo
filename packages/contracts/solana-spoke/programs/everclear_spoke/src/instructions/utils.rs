use anchor_lang::prelude::*;

use crate::error::SpokeError;

use crate::intent::EVMIntent;

pub(crate) fn normalize_decimals(
    amount: u128,
    minted_decimals: u8,
    target_decimals: u8,
) -> Result<u128> {
    match minted_decimals.cmp(&target_decimals) {
        // No scaling needed
        std::cmp::Ordering::Equal => Ok(amount),
        // e.g. minted_decimals=9, target_decimals=6 => downscale
        std::cmp::Ordering::Greater => {
            let shift = minted_decimals - target_decimals;
            // prevent potential divide-by-zero or overshoot
            if shift > 12 {
                // you might fail or just saturate for large differences
                return err!(SpokeError::DecimalConversionOverflow);
            };
            Ok(amount / u128::from(10u64.pow(shift as u32)))
        }
        // minted_decimals < target_decimals => upscale
        std::cmp::Ordering::Less => {
            let shift = target_decimals - minted_decimals;
            // watch for overflow if we do big multiplications
            let factor = 10u64
                .checked_pow(shift as u32)
                .ok_or(error!(SpokeError::DecimalConversionOverflow))?;
            let scaled = amount
                .checked_mul(u128::from(factor))
                .ok_or(error!(SpokeError::DecimalConversionOverflow))?;
            Ok(scaled)
        }
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

pub fn hash_intent_id_array(intent_ids: &[[u8; 32]]) -> [u8; 32] {
    let mut bytes: Vec<u8> = Vec::with_capacity(intent_ids.len() * 32);
    for id in intent_ids {
        bytes.extend_from_slice(id);
    }
    keccak_256(&bytes)
}

pub(crate) fn encode_single_intent(intent: &EVMIntent) -> Vec<u8> {
    let mut out = Vec::new();

    out.extend_from_slice(&u256_to_32bytes(32u64 as u128));

    let mut head = Vec::new();

    // Now we write the struct #0 "head," which is 13 * 32 bytes

    // word0: initiator (bytes32)
    head.extend_from_slice(&intent.initiator);

    // word1: receiver (bytes32)
    head.extend_from_slice(&intent.receiver);

    // word2: input_asset (bytes32)
    head.extend_from_slice(&intent.input_asset);

    // word3: output_asset (bytes32)
    head.extend_from_slice(&intent.output_asset);

    // word4: origin (uint32 => 4 bytes used, the other 28 are zero)
    head.extend_from_slice(&u256_to_32bytes(u128::from(intent.origin)));

    // word5: nonce (uint64)
    head.extend_from_slice(&u256_to_32bytes(intent.nonce as u128));

    // word6: timestamp (uint48 => we store in 32 bytes, last 6 bytes used)
    head.extend_from_slice(&u256_to_32bytes(intent.timestamp as u128));

    // word7: ttl (uint48 => same reasoning)
    head.extend_from_slice(&u256_to_32bytes(intent.ttl as u128));

    // word8: amount (uint256 => already 32 bytes big-endian).
    // In typical abi.encode, we just place it as-is, but ensure it's 32 bytes big-endian
    head.extend_from_slice(&intent.amount);

    // word9: amountOutMin (uint256 => already 32 bytes big-endian)
    // In typical abi.encode, we just place it as-is, but ensure it's 32 bytes big-endian
    head.extend_from_slice(&intent.amount_out_min);

    // We have 2 dynamic fields => destinations[] and data
    // They each get a 32-byte "offset" word. The offset is from the start of struct #0 head (i.e. offset=0 there)
    // We know the struct head is 384 bytes total => that means the "tail" starts at offset 384
    // But we must figure out how big "destinations" is to know where "data" begins in that tail.

    // We'll build the tail in a separate buffer, so we can figure out lengths
    let (tail, destinations_offset, data_offset) = encode_struct_tail(intent);

    // word10: offset to destinations
    head.extend_from_slice(&u256_to_32bytes(destinations_offset as u128));

    // word11: offset to data
    head.extend_from_slice(&u256_to_32bytes(data_offset as u128));

    // Finally, we put the entire head (384 bytes) after the initial 32 bytes for array length:
    out.extend_from_slice(&head);

    // Then we append the tail:
    out.extend_from_slice(&tail);

    out
}

/// Helper that encodes the "tail" portion for the dynamic fields (destinations and data)
/// and returns:
///   - the tail bytes
///   - the offset (in bytes) from the start of the struct's head to the destinations data
///   - the offset (in bytes) from the start of the struct's head to the data field
///
/// We know:
///   - The struct "head" is 12 words = 384 bytes.
///   - So the tail region physically begins at offset = 384 from the start of the struct head.
///   - The offset we store in word10 is the distance from 0.. to where destinations data starts in the tail.
///   - The offset we store in word11 is the distance from 0.. to where data starts in the tail.
///
fn encode_struct_tail(intent: &EVMIntent) -> (Vec<u8>, u64, u64) {
    let mut tail = Vec::new();
    // The tail offset starts right after the struct's 384-byte head,
    // but the offsets *within* the struct are measured from the start of that head (i.e. 0).
    // So the first dynamic field (destinations) will be at offset = 384 - 384 = 0?
    // Actually, in the ABI spec, the offset stored in the struct’s head is measured
    // *relative to the start of that struct’s head*. So if the tail is appended
    // immediately after 384 bytes, then the first dynamic field is at offset = 384 - 384 = 0 from the tail’s start.
    //
    // However, we typically store just the numeric offset "384" in the top-level array encoding,
    // then plus the struct's index. But because we have an array of length=1, we measure from the
    // start of that single struct's head, so it is indeed 384. But inside that single struct,
    // it is "0" to the first tail chunk. The EVM looks at (headStart + offset).
    //
    // In practice, to keep consistent with the standard approach:
    //   - For the first dynamic field, we store offset=384 in the struct’s head.
    //   - Then for the second dynamic field, offset=384 + [size of the first], etc.
    //
    // Because there's only one struct, that "384" is the distance from the struct start
    // up to the tail. So let's do this carefully:
    //
    // We'll figure out the size of the destinations chunk, then we know where data begins.
    // Then we know the offsets to store in the head are (384) for destinations, (384 + size_of_destinations_chunk) for data.

    // 1) Encode destinations
    let mut destinations_bytes = Vec::new();
    //  - first 32 bytes => length of array
    destinations_bytes.extend_from_slice(&u256_to_32bytes(u128::from(
        intent.destinations.len() as u64
    )));

    //  - then each element is a uint32 => in abi.encode, each element is still a full 32-byte word,
    //    with the value in the last 4 bytes (big-endian).
    for &val in intent.destinations.iter() {
        destinations_bytes.extend_from_slice(&u256_to_32bytes(u128::from(val)));
    }

    // 2) Encode data (bytes)
    let mut data_bytes = Vec::new();
    data_bytes.extend_from_slice(&u256_to_32bytes(u128::from(intent.data.len() as u64)));
    // the raw bytes, then pad to multiple of 32
    data_bytes.extend_from_slice(&intent.data);
    // pad
    let padding = (32 - (intent.data.len() % 32)) % 32;
    data_bytes.extend(std::iter::repeat(0u8).take(padding));

    // We place "destinations_bytes" first, then "data_bytes" in the tail
    let destinations_offset = 384; // from start of struct #0
    let data_offset = destinations_offset + destinations_bytes.len() as u64; // from start of struct #0

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

#[cfg(test)]
mod tests {
    use super::*;
    use hex::FromHex;

    fn u128_to_u256_be(val: u128) -> [u8; 32] {
        let mut out = [0u8; 32];
        // copy val’s big-endian bytes into the last 8 bytes
        out[16..32].copy_from_slice(&val.to_be_bytes());
        out
    }

    #[test]
    fn test_compute_intent_hash() {
        // NOTE: this intent data is taken from actual intent from EVM
        let intent = EVMIntent {
            initiator: <[u8; 32]>::from_hex("00000000000000000000000065588b1121eb7dd41ba7d82a4f387548381584a9").unwrap(),
            receiver: <[u8; 32]>::from_hex("00000000000000000000000039096a17ba70fe5c1eddb923f940b2e6deae5c3b").unwrap(),
            input_asset: <[u8; 32]>::from_hex("000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913").unwrap(),
            output_asset: <[u8; 32]>::from_hex("00000000000000000000000094b008aa00579c1307b0ef2c499ad98a8ce58e58").unwrap(),
            origin: 8453,
            nonce: 168,
            timestamp: 1762404021,
            ttl: 7200,
            amount: u128_to_u256_be(422401000000000000),
            amount_out_min: u128_to_u256_be(422352),
            destinations: vec![10],
            data: vec![],
        };
        let intent_id = compute_intent_hash(&intent);
        assert_eq!(
            hex::encode(intent_id),
            "d6db7d3cefc524dc4717361e8b77c7cdca1f700971ae36c61823c17a38a7472a"
        );

        // NOTE: this is a made-up solana intent
        let solana_intent = EVMIntent {
            initiator: Pubkey::from_str_const("AUgefcX2VZq9v72gqXUg8rgUNxsbHV7RVWuw42yU4LyQ")
                .to_bytes(),
            receiver: Pubkey::from_str_const("1111111111113FiC6QTSLv7Up9gSeUwhPifXRCoH").to_bytes(),
            input_asset: Pubkey::from_str_const("EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v")
                .to_bytes(),
            output_asset: Pubkey::from_str_const("1111111111112q2Gg8TH19xwTZeyUCme313nZsTQ")
                .to_bytes(),
            origin: 1399811149,
            nonce: 35,
            timestamp: 1743782830,
            ttl: 0,
            amount: u128_to_u256_be(2000000000000000000),
            amount_out_min: u128_to_u256_be(0),
            destinations: vec![8453],
            data: vec![],
        };
        let intent_id = compute_intent_hash(&solana_intent);
        assert_eq!(
            hex::encode(intent_id),
            "8200900c8aa6b771a0cc3a6936d9313bfb9721f2506d4e6b884813c7f50db86e"
        );
    }
}
