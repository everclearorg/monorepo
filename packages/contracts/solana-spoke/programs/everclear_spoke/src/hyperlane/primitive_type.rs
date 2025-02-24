use anchor_lang::{prelude::borsh::{self, BorshDeserialize, BorshSerialize}, AnchorDeserialize, AnchorSerialize};
use fixed_hash::construct_fixed_hash;
use uint::construct_uint;

construct_fixed_hash! {
    /// 256-bit hash type.
    #[derive(AnchorSerialize, AnchorDeserialize)]
    pub struct H256(32);
}

construct_uint! {
    /// 256-bit unsigned integer.
    #[derive(BorshSerialize, BorshDeserialize)]
    pub struct U256(4);
}
