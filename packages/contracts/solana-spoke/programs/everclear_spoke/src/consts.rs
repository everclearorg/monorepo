use anchor_lang::prelude::Pubkey;

// Constants
pub const HYPERLANE_MAILBOX_PROGRAM_ID: Pubkey = Pubkey::new_from_array([0; 32]);
pub const THIS_DOMAIN: u32 = 1234; // This spoke's domain ID
pub const EVERCLEAR_DOMAIN: u32 = 9999; // Hub's domain ID
pub const MAX_INTENT_QUEUE_SIZE: usize = 1000;
pub const MAX_FILL_QUEUE_SIZE: usize = 1000;
pub const MAX_CALLDATA_SIZE: usize = 10240; // 10KB
pub const DBPS_DENOMINATOR: u32 = 10_000;
pub const DEFAULT_NORMALIZED_DECIMALS: u8 = 18;

// TODO: Need to define these hashes
pub const GATEWAY_HASH: [u8; 32] = [0x01; 32]; // placeholder
pub const MAILBOX_HASH: [u8; 32] = [0x02; 32]; // placeholder
pub const LIGHTHOUSE_HASH: [u8; 32] = [0x03; 32]; // placeholder
pub const WATCHTOWER_HASH: [u8; 32] = [0x04; 32]; // placeholder

pub const FILL_INTENT_FOR_SOLVER_TYPEHASH: [u8; 32] = [0xAA; 32]; // placeholder
pub const PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH: [u8; 32] = [0xBB; 32];
pub const PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH: [u8; 32] = [0xCC; 32];
