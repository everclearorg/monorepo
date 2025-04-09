pub mod new_intent;

pub use new_intent::*;

use super::{utils::encode_single_intent, MessageType};

/// Represents the 12 fields in our Intent struct, matching the Solidity layout.
#[derive(Debug, Clone)]
pub struct EVMIntent {
    pub initiator: [u8; 32],
    pub receiver: [u8; 32],
    pub input_asset: [u8; 32],
    pub output_asset: [u8; 32],
    pub max_fee: u32, // actually uint24 in Solidity
    pub origin: u32,
    pub nonce: u64,
    pub timestamp: u64,   // actually uint48 in Solidity
    pub ttl: u64,         // actually uint48 in Solidity
    pub amount: [u8; 32], // big-endian, matching typical EVM usage
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
}

/// Encodes a single EVMIntent as if we did abi.encode([intent]) in Solidity.
/// Because we have exactly 1 Intent, we encode a dynamic array of length=1.
fn encode_array_of_one_intent(intent: &EVMIntent) -> Vec<u8> {
    //
    // The layout for abi.encode(EVMIntent[]) with length=1 is:
    //
    // OFFSET 0:   32 bytes = "head" of the array which is offset to the array length (=32)
    // OFFSET 32:  32 bytes = length of the array => 1
    // OFFSET 64:  32 bytes = "head" of the first (and single) element in the array
    //             which is offset to the first element of the array (=32)
    // OFFSET 96:  "head" of struct #0, which is 12 * 32 = 384 bytes
    // OFFSET 480: "tail" data for dynamic fields (destinations, data), appended sequentially
    //
    // Inside that "head" (struct #0):
    //   word0: initiator (bytes32)
    //   word1: receiver  (bytes32)
    //   word2: input_asset (bytes32)
    //   word3: output_asset (bytes32)
    //   word4: max_fee (uint24 => but zero-extended to 32 bytes)
    //   word5: origin (uint32)
    //   word6: nonce (uint64)
    //   word7: timestamp (uint48 => but zero-extended to 32 bytes)
    //   word8: ttl (uint48 => but zero-extended to 32 bytes)
    //   word9: amount (uint256 => 32 bytes as is)
    //   word10: offset to destinations (dynamic array) from start of struct #0 head
    //   word11: offset to data (dynamic bytes) from start of struct #0 head
    //
    // The "tail" must contain:
    //   * destinations[]:
    //        - 32 bytes = length L
    //        - L * 32 bytes = each element stored in last 4 bytes of each 32-byte word
    //   * data (bytes):
    //        - 32 bytes = length (in bytes)
    //        - actual byte data (padded to multiple of 32)
    //

    // 1) Prepare a vector for the final output
    let mut out = Vec::new();

    // 2) Write array "head"
    out.extend_from_slice(&u256_to_32bytes(32u64 as u128));

    // 3) Write array length = 1 (32 bytes, big-endian)
    out.extend_from_slice(&u256_to_32bytes(1u128));

    // 4) Write the encoded intent element
    out.extend_from_slice(&encode_single_intent(intent));

    out
}

/// Finally, wrap the single-intent-array encoding in abi.encode(uint8 messageType, bytes).
/// This means at the top level we have 2 fields:
///   [0]: messageType (uint8) => expanded to 32 bytes
///   [1]: the offset to the start of the dynamic bytes
/// Then we store the length of that dynamic bytes + the bytes.
fn encode_full(message_type: MessageType, intent: &EVMIntent) -> Vec<u8> {
    // 1) encode the single-intent array
    let inner_data = encode_array_of_one_intent(intent);

    // 2) Now produce abi.encode(uint8, bytes).
    //    That means we have two "slots" in the head:
    //
    //    slot0 => 32-byte word for the uint8 (the last byte is message_type, the rest zero)
    //    slot1 => 32-byte word containing offset to the dynamic data region, which begins
    //             immediately after these 2 words => offset = 64 (0x40)
    //
    // Then we place the length of inner_data in 32 bytes, followed by inner_data, padded if needed.

    let mut out = Vec::new();

    // slot0: 32 bytes => messageType in the last 1 byte
    {
        let mut word = [0u8; 32];
        word[31] = message_type as u8;
        out.extend_from_slice(&word);
    }

    // slot1: 32 bytes => offset to dynamic data, i.e. 64
    out.extend_from_slice(&u256_to_32bytes(64u64 as u128));

    // Then at offset=64, we place:
    //   - 32 bytes length
    //   - the actual bytes of inner_data
    //   - (plus padding if needed, but typically we treat the entire result as dynamic so no trailing data is needed)
    let inner_len = inner_data.len();
    out.extend_from_slice(&u256_to_32bytes(inner_len as u128));
    out.extend_from_slice(&inner_data);

    // no further padding is strictly required unless you are embedding this inside something else
    out
}

/// Utility: Convert a u64 (or any Into<u128>) to a 32-byte big-endian word
/// that Solidity's abi.encode() would produce for a uintN.
fn u256_to_32bytes(val: impl Into<u128>) -> [u8; 32] {
    let mut word = [0u8; 32];
    let v: u128 = val.into();
    // fill from the right (big-endian)
    for i in 0..16 {
        word[31 - i] = (v >> (8 * i)) as u8;
    }
    word
}

fn u64_to_u256_be(val: u64) -> [u8; 32] {
    let mut out = [0u8; 32];
    // copy val’s big-endian bytes into the last 8 bytes
    out[24..32].copy_from_slice(&val.to_be_bytes());
    out
}
