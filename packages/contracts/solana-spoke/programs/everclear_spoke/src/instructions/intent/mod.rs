pub mod new_intent;

pub use new_intent::*;

use anchor_lang::prelude::*;

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct Intent {
    pub initiator: Pubkey,
    pub receiver: Pubkey,
    pub input_asset: Pubkey,
    pub output_asset: Pubkey,
    pub max_fee: u32,
    pub origin_domain: u32,
    pub nonce: u64,
    pub timestamp: u64,
    pub ttl: u64,
    pub normalized_amount: u64,
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
}
