use crate::hyperlane::H256;
use anchor_lang::prelude::Pubkey;

pub const HYPERLANE_MAILBOX_PROGRAM_ID: Pubkey = Pubkey::new_from_array([0; 32]);
// NOTE: use hyperlane's sol mainnet chain ID
pub const THIS_DOMAIN: u32 = 1399811149; // This spoke's domain ID
pub const EVERCLEAR_DOMAIN: u32 = 25327; // Hub's domain ID
pub const MAX_CALLDATA_SIZE: usize = 10240; // 10KB
pub const DBPS_DENOMINATOR: u32 = 10_000;
pub const DEFAULT_NORMALIZED_DECIMALS: u8 = 18;

// TODO: need to fill these bytes
pub const EVERCLEAR_GATEWAY_BYTES: [u8; 32] = [0x01; 32]; // placeholder

pub fn everclear_gateway() -> H256 {
    H256::from(EVERCLEAR_GATEWAY_BYTES)
}

pub fn pub_to_h256(pubkey: Pubkey) -> H256 {
    H256::from(pubkey.to_bytes())
}

pub fn h256_to_pub(h256: H256) -> Pubkey {
    Pubkey::new_from_array(h256.0)
}
