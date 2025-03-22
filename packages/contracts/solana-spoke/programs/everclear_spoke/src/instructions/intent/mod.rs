pub mod new_intent;

pub use new_intent::*;

use super::MessageType;

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

    // 4) Write "head" of the first element
    out.extend_from_slice(&u256_to_32bytes(32u64 as u128));

    // 5) Now we write the struct #0 "head," which is 12 * 32 bytes
    let mut head = Vec::new();

    // word0: initiator (bytes32)
    head.extend_from_slice(&intent.initiator);

    // word1: receiver (bytes32)
    head.extend_from_slice(&intent.receiver);

    // word2: input_asset (bytes32)
    head.extend_from_slice(&intent.input_asset);

    // word3: output_asset (bytes32)
    head.extend_from_slice(&intent.output_asset);

    // word4: max_fee => stored in top 3 bytes or simply zero-extended as a 32-byte word
    // For abi.encode, the entire 32 bytes get used, with the last 3 bytes carrying the value for a uint24
    head.extend_from_slice(&u256_to_32bytes(u128::from(intent.max_fee)));

    // word5: origin (uint32 => 4 bytes used, the other 28 are zero)
    head.extend_from_slice(&u256_to_32bytes(u128::from(intent.origin)));

    // word6: nonce (uint64)
    head.extend_from_slice(&u256_to_32bytes(intent.nonce as u128));

    // word7: timestamp (uint48 => we store in 32 bytes, last 6 bytes used)
    head.extend_from_slice(&u256_to_32bytes(intent.timestamp as u128));

    // word8: ttl (uint48 => same reasoning)
    head.extend_from_slice(&u256_to_32bytes(intent.ttl as u128));

    // word9: amount (uint256 => already 32 bytes big-endian).
    // In typical abi.encode, we just place it as-is, but ensure it's 32 bytes big-endian
    head.extend_from_slice(&intent.amount);

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
