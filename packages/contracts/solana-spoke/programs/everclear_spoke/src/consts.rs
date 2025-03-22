use crate::hyperlane::H256;
use anchor_lang::prelude::Pubkey;

// NOTE: use hyperlane's sol mainnet chain ID
pub const THIS_DOMAIN: u32 = 1399811149; // This spoke's domain ID
pub const EVERCLEAR_DOMAIN: u32 = 25327; // Hub's domain ID
pub const DBPS_DENOMINATOR: u32 = 10_000;
pub const DEFAULT_NORMALIZED_DECIMALS: u8 = 18;

// For mainnet
//  0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa padded to 32 bytes
// pub const EVERCLEAR_GATEWAY_BYTES: [u8; 32] = [
//     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 239, 250, 183, 204, 235, 246, 63, 190, 251, 72, 132, 150,
//     75, 18, 37, 157, 67, 116, 250, 170,
// ];

// 0xe5F2F4afAd6211cfBD6a882D5a6a435530Ee3909 padded to 32 bytes
pub const EVERCLEAR_GATEWAY_BYTES: [u8; 32] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 229, 242, 244, 175, 173, 98, 17, 207, 189, 106, 136, 45,
    90, 106, 67, 85, 48, 238, 57, 9,
];

pub fn everclear_gateway() -> H256 {
    H256::from(EVERCLEAR_GATEWAY_BYTES)
}

pub fn pub_to_h256(pubkey: Pubkey) -> H256 {
    H256::from(pubkey.to_bytes())
}

pub const fn h256_to_pub(h256: H256) -> Pubkey {
    Pubkey::new_from_array(h256.0)
}
