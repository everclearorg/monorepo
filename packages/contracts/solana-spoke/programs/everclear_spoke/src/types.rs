use anchor_lang::prelude::*;

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct OrderParameters {
  pub destinations: Vec<u32>,
  pub receiver:     Pubkey,
  pub input_asset:  Pubkey,
  pub output_asset: Pubkey,
  pub amount:       u64,
  pub max_fee:      u32,
  pub ttl:          u64,
  pub data:         Vec<u8>,
}