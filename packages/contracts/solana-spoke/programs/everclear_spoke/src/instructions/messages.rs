use anchor_lang::prelude::*;

use crate::hyperlane::U256;

// Context for the settlements
#[derive(AnchorSerialize, Clone, PartialEq, Eq, Debug)]
pub struct Settlement {
    pub intent_id: [u8; 32],
    pub amount: U256,
    pub asset: Pubkey,
    pub recipient: Pubkey,
    pub update_virtual_balance: bool,
}

impl AnchorDeserialize for Settlement {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let mut intent_id: [u8; 32] = [0; 32];
        let mut amount: [u8; 32] = [0; 32];
        let mut asset: [u8; 32] = [0; 32];
        let mut recipient: [u8; 32] = [0; 32];
        reader.read_exact(&mut intent_id)?;
        reader.read_exact(&mut amount)?;
        reader.read_exact(&mut asset)?;
        reader.read_exact(&mut recipient)?;
        let mut buf: [u8; 32] = [0; 32];
        reader.read_exact(&mut buf)?;
        let settlement = Settlement {
            intent_id,
            amount: U256::from_little_endian(&amount),
            asset: Pubkey::new_from_array(asset),
            recipient: Pubkey::new_from_array(recipient),
            update_virtual_balance: buf[31] == 1,
        };
        Ok(settlement)
    }
}

/// Settlements object from EVM layer
pub struct Settlements {
    pub settlements: Vec<Settlement>,
}

impl AnchorDeserialize for Settlements {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        // Structure of the data in slots:
        // offset
        // length of data
        // ?
        // len of settlements
        // settlement 1
        // ...
        // settlement 2
        // ...
        let mut buf = [0u8; 32];
        // read offset and ignore
        reader.read_exact(&mut buf)?;
        // read len and ignore
        reader.read_exact(&mut buf)?;
        // read one more block and ignore
        reader.read_exact(&mut buf)?;
        // read len and store into buf
        reader.read_exact(&mut buf)?;
        // SAFE: buf size > 4 and can always be unwrapped
        let (_, size) = buf.split_last_chunk().unwrap();
        let size = u32::from_be_bytes(*size);
        let mut settlements = vec![];
        for _ in 0..size {
            let mut intent_id: [u8; 32] = [0; 32];
            let mut amount_be: [u8; 32] = [0; 32];
            let mut asset: [u8; 32] = [0; 32];
            let mut recipient: [u8; 32] = [0; 32];
            let mut update_virtual_balance_buf: [u8; 32] = [0; 32];

            reader.read_exact(&mut intent_id)?;
            reader.read_exact(&mut amount_be)?;
            reader.read_exact(&mut asset)?;
            reader.read_exact(&mut recipient)?;
            reader.read_exact(&mut update_virtual_balance_buf)?;

            let amount = U256::from_big_endian(&amount_be);

            let settlement = Settlement {
                intent_id,
                amount,
                asset: Pubkey::new_from_array(asset),
                recipient: Pubkey::new_from_array(recipient),
                update_virtual_balance: update_virtual_balance_buf[31] == 1,
            };
            settlements.push(settlement);
        }
        Ok(Settlements { settlements })
    }
}

#[derive(Debug, PartialEq)]
pub enum MessageType {
    Intent,
    Fill,
    Settlement,
    VarUpdate,
}

impl TryFrom<u8> for MessageType {
    type Error = u8;

    fn try_from(value: u8) -> std::result::Result<Self, Self::Error> {
        let res = match value {
            0 => MessageType::Intent,
            1 => MessageType::Fill,
            2 => MessageType::Settlement,
            3 => MessageType::VarUpdate,
            _ => return Err(value),
        };
        Ok(res)
    }
}
pub struct HyperlaneMessages {
    pub message_type: MessageType,
    pub rest: Vec<u8>,
}

impl AnchorDeserialize for HyperlaneMessages {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        // Structure of the data:
        // MessageType (32 byte)
        // remaining message contents
        let mut buf = [0u8; 32];
        reader.read_exact(&mut buf)?;
        let message_type: MessageType = MessageType::try_from(buf[31])
            .map_err(|_| std::io::Error::new(std::io::ErrorKind::InvalidInput, "invalid type"))?;

        let mut rest = vec![];
        reader.read_to_end(&mut rest)?;
        Ok(HyperlaneMessages { message_type, rest })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hyperlane_message_deserialize() {
        let data = hex::decode("0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000012f4a5c761bb98e62e126f2ef03950b75eb9920e70f5f1ea7f5e7050ad275db800000000000000000000000000000000000000000000000000ddd2935029d8000c6fa7af3bedbad3a3d65f36aabc97431b1bbe4c2d2f6e0e47ca60203452f5d617e6a69246a33870eb4b7218a18e51c460c6e995f49d9a964e2d7445195953fd60000000000000000000000000000000000000000000000000000000000000000").unwrap();
        let message: HyperlaneMessages =
            AnchorDeserialize::deserialize(&mut data.as_ref()).unwrap();
        assert_eq!(message.message_type, MessageType::Settlement);
        assert_eq!(message.rest, hex::decode("000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000012f4a5c761bb98e62e126f2ef03950b75eb9920e70f5f1ea7f5e7050ad275db800000000000000000000000000000000000000000000000000ddd2935029d8000c6fa7af3bedbad3a3d65f36aabc97431b1bbe4c2d2f6e0e47ca60203452f5d617e6a69246a33870eb4b7218a18e51c460c6e995f49d9a964e2d7445195953fd60000000000000000000000000000000000000000000000000000000000000000").unwrap());
    }

    #[test]
    fn test_settlements_deserialize() {
        let data = hex::decode("000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000012f4a5c761bb98e62e126f2ef03950b75eb9920e70f5f1ea7f5e7050ad275db800000000000000000000000000000000000000000000000000ddd2935029d8000c6fa7af3bedbad3a3d65f36aabc97431b1bbe4c2d2f6e0e47ca60203452f5d617e6a69246a33870eb4b7218a18e51c460c6e995f49d9a964e2d7445195953fd60000000000000000000000000000000000000000000000000000000000000000").unwrap();
        let settlements: Settlements = AnchorDeserialize::deserialize(&mut data.as_ref()).unwrap();
        assert_eq!(settlements.settlements.len(), 1);
        assert_eq!(
            settlements.settlements[0],
            Settlement {
                intent_id: [
                    47, 74, 92, 118, 27, 185, 142, 98, 225, 38, 242, 239, 3, 149, 11, 117, 235,
                    153, 32, 231, 15, 95, 30, 167, 245, 231, 5, 10, 210, 117, 219, 128
                ],
                amount: U256::from(999000000000000000u64),
                asset: Pubkey::from_str_const("EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"),
                recipient: Pubkey::from_str_const("9WUUr2WNUiKMzwxJgbb4oxS81oYAyhrBFkv3NSg2mjbj"),
                update_virtual_balance: false,
            }
        )
    }

    #[test]
    fn test_settlement_round_trip_serialization() {
        let test_amount = U256::from(999000000000000000u64);
        let original_settlement = Settlement {
            intent_id: [1u8; 32],
            amount: test_amount,
            asset: Pubkey::new_unique(),
            recipient: Pubkey::new_unique(),
            update_virtual_balance: true,
        };

        let mut amount_buf = [0u8; 32];
        original_settlement.amount.to_little_endian(&mut amount_buf);

        let deserialized_amount = U256::from_little_endian(&amount_buf);

        assert_eq!(
            test_amount, deserialized_amount,
            "Settlement amount should match after round-trip (serialize little-endian, deserialize little-endian)"
        );

        let wrong_amount = U256::from_big_endian(&amount_buf);
        assert_ne!(
            test_amount, wrong_amount,
            "Using big-endian deserialization would give wrong value, breaking round-trip"
        );
    }

    #[test]
    fn test_settlement_endianness_consistency() {
        let test_amount = U256::from(1234567890123456789u64);

        let mut serialized = Vec::new();
        let settlement = Settlement {
            intent_id: [0u8; 32],
            amount: test_amount,
            asset: Pubkey::default(),
            recipient: Pubkey::default(),
            update_virtual_balance: false,
        };
        settlement.serialize(&mut serialized).unwrap();

        let amount_bytes = &serialized[32..64];

        let deserialized_amount = U256::from_little_endian(amount_bytes);
        assert_eq!(
            test_amount, deserialized_amount,
            "Amount should deserialize correctly from little-endian bytes (matching AnchorSerialize)"
        );

        let wrong_amount = U256::from_big_endian(amount_bytes);
        assert_ne!(
            test_amount, wrong_amount,
            "Deserializing as big-endian should give different (wrong) value"
        );
    }
}
