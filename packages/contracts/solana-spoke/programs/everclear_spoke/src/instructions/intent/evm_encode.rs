use crate::error::SpokeError;
use crate::instructions::messages::MessageType;
use anchor_lang::prelude::*;

pub trait EVMEncode {
    /// encode to evm equivalent encoded `abi.encode` format
    fn encode(&self) -> Vec<u8>;
}

/// Represents the 12 fields in our Intent struct, matching the Solidity layout.
/// Anchor serde is added here for putting the intent in event.
#[derive(Debug, Clone, AnchorSerialize, AnchorDeserialize)]
pub struct EVMIntent {
    pub initiator: [u8; 32],
    pub receiver: [u8; 32],
    pub input_asset: [u8; 32],
    pub output_asset: [u8; 32],
    pub origin: u32,
    pub nonce: u64,
    pub timestamp: u64,           // actually uint48 in Solidity
    pub ttl: u64,                // actually uint48 in Solidity
    pub amount: [u8; 32],        // big-endian, matching typical EVM usage
    pub amount_out_min: [u8; 32], // uint256
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
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
    // [comments from diff omitted for length - same logic]

    // 1) Encode destinations
    let mut destinations_bytes = Vec::new();
    destinations_bytes.extend_from_slice(&u256_to_32bytes(u128::from(
        intent.destinations.len() as u64
    )));
    for &val in intent.destinations.iter() {
        destinations_bytes.extend_from_slice(&u256_to_32bytes(u128::from(val)));
    }

    // 2) Encode data (bytes)
    let mut data_bytes = Vec::new();
    data_bytes.extend_from_slice(&u256_to_32bytes(u128::from(intent.data.len() as u64)));
    data_bytes.extend_from_slice(&intent.data);
    let padding = (32 - (intent.data.len() % 32)) % 32;
    data_bytes.extend(std::iter::repeat(0u8).take(padding));

    let destinations_offset = 384;
    let data_offset = destinations_offset + destinations_bytes.len() as u64;

    tail.extend_from_slice(&destinations_bytes);
    tail.extend_from_slice(&data_bytes);

    (tail, destinations_offset, data_offset)
}

impl EVMEncode for EVMIntent {
    fn encode(&self) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&u256_to_32bytes(32u64 as u128));
        let mut head = Vec::new();

        head.extend_from_slice(&self.initiator);
        head.extend_from_slice(&self.receiver);
        head.extend_from_slice(&self.input_asset);
        head.extend_from_slice(&self.output_asset);
        head.extend_from_slice(&u256_to_32bytes(u128::from(self.origin)));
        head.extend_from_slice(&u256_to_32bytes(self.nonce as u128));
        head.extend_from_slice(&u256_to_32bytes(self.timestamp as u128));
        head.extend_from_slice(&u256_to_32bytes(self.ttl as u128));
        head.extend_from_slice(&self.amount);
        head.extend_from_slice(&self.amount_out_min);

        let (tail, destinations_offset, data_offset) = encode_struct_tail(self);
        head.extend_from_slice(&u256_to_32bytes(destinations_offset as u128));
        head.extend_from_slice(&u256_to_32bytes(data_offset as u128));

        out.extend_from_slice(&head);
        out.extend_from_slice(&tail);
        out
    }
}

pub struct FillMessage {
    pub intent_id: [u8; 32],
    pub receiver: [u8; 32],
    pub intent_input_asset: [u8; 32],
    pub intent_origin: u32,
    pub amount_out: [u8; 32],
    pub destinations: Vec<u32>,
    pub execution_timestamp: u64,
}

impl FillMessage {
    fn encode_tail(&self) -> (Vec<u8>, u64) {
        let mut tail = Vec::new();
        let mut destinations_bytes = Vec::new();
        destinations_bytes
            .extend_from_slice(&u256_to_32bytes(u128::from(self.destinations.len() as u64)));
        for &val in self.destinations.iter() {
            destinations_bytes.extend_from_slice(&u256_to_32bytes(u128::from(val)));
        }
        let destinations_offset = 224;
        tail.extend_from_slice(&destinations_bytes);
        (tail, destinations_offset)
    }
}

impl EVMEncode for FillMessage {
    fn encode(&self) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&u256_to_32bytes(32u64 as u128));
        let mut head = Vec::new();

        head.extend_from_slice(&self.intent_id);
        head.extend_from_slice(&self.receiver);
        head.extend_from_slice(&self.intent_input_asset);
        head.extend_from_slice(&u256_to_32bytes(u128::from(self.intent_origin)));
        head.extend_from_slice(&self.amount_out);

        let (tail, destinations_offset) = self.encode_tail();
        head.extend_from_slice(&u256_to_32bytes(destinations_offset as u128));
        head.extend_from_slice(&u256_to_32bytes(self.execution_timestamp as u128));

        out.extend_from_slice(&head);
        out.extend_from_slice(&tail);
        out
    }
}

impl<T> EVMEncode for [&T; 1]
where
    T: EVMEncode,
{
    fn encode(&self) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&u256_to_32bytes(32u64 as u128));
        out.extend_from_slice(&u256_to_32bytes(1u128));
        out.extend_from_slice(&self[0].encode());
        out
    }
}

/// Wrap the single-intent-array encoding in abi.encode(uint8 messageType, bytes).
pub fn encode_full<T>(message_type: MessageType, intent: T) -> Vec<u8>
where
    [T; 1]: EVMEncode,
{
    let inner_data = [intent].encode();
    let mut out = Vec::new();
    {
        let mut word = [0u8; 32];
        word[31] = message_type as u8;
        out.extend_from_slice(&word);
    }
    out.extend_from_slice(&u256_to_32bytes(64u64 as u128));
    let inner_len = inner_data.len();
    out.extend_from_slice(&u256_to_32bytes(inner_len as u128));
    out.extend_from_slice(&inner_data);
    out
}

fn u256_to_32bytes(val: impl Into<u128>) -> [u8; 32] {
    let mut word = [0u8; 32];
    let v: u128 = val.into();
    for i in 0..16 {
        word[31 - i] = (v >> (8 * i)) as u8;
    }
    word
}

pub fn u128_to_u256_be(val: u128) -> [u8; 32] {
    let mut out = [0u8; 32];
    out[16..32].copy_from_slice(&val.to_be_bytes());
    out
}

/// Convert an 32-byte big-endian word that is Solidity encoded to u64.
pub(crate) fn try_32bytes_to_u64(val: [u8; 32]) -> Result<u64> {
    let mut result: u64 = 0;
    for byte in val.iter().take(24) {
        require!(*byte == 0, SpokeError::IntegerOverflow);
    }
    for byte in val.iter().skip(24) {
        result <<= 8;
        result += *byte as u64;
    }
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_try_32bytes_to_u64() {
        assert_eq!(
            try_32bytes_to_u64([
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 12, 12, 196
            ])
            .unwrap(),
            789700
        );
    }
}
