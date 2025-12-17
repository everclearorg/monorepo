use anchor_lang::prelude::*;

use crate::{
    hyperlane::{InterchainGasPaymasterType, SerializableAccountMeta},
    instructions::messages::Settlement,
};

/// SpokeState – global configuration.
#[account]
pub struct SpokeState {
    // Initializer version
    pub initialized_version: u8,
    // Paused flag.
    pub paused: bool,
    // Domain IDs.
    pub domain: u32,
    pub everclear: u32,
    // Addresses for key roles.
    pub lighthouse: Pubkey,
    pub watchtower: Pubkey,
    // Message gas limit (stored, though not used on Solana).
    pub message_gas_limit: u64,
    // Global nonce for intents.
    pub nonce: u64,
    // Owner of the program (admin).
    pub owner: Pubkey,
    // Bump for PDA.
    pub bump: u8,
    // Mailbox address
    pub mailbox: Pubkey,
    // Bump for mailbox dispatch authority
    pub mailbox_dispatch_authority_bump: u8,
    // IGP address
    pub igp: Pubkey,
    // IGP Type which either contains igp address (as in `igp`) or the overhead IGP address if the IGP is an overhead IGP
    pub igp_type: InterchainGasPaymasterType,
    // Bump for vault authority
    pub vault_authority_bump: u8,
}

impl SpokeState {
    pub const SIZE: usize = 1    // paused: bool
        + 1                      // initialized_version: u8
        + 4                      // domain: u32
        + 4                      // everclear: u32
        + 32 * 2                 // 2 Pubkeys
        + 8                      // message_gas_limit: u64
        + 8                      // nonce: u64
        + 32                     // owner: Pubkey
        + 1                      // bump: u8
        + 32                     // mailbox: Pubkey
        + 1                      // mailbox_dispatch_authority_bump: u8
        + 32                     // igp: Pubkey
        + 33                     // igp_type: InterchainGasPaymasterType
        + 1                      // vault_authority_bump: u8
    ;
}

#[account]
pub struct FeeAdapterState {
    pub initialized: bool,
    pub paused: bool,
    pub fee_recipient: Pubkey,
    pub fee_signer: Pubkey,
    pub fill_signer: Pubkey,
    pub bump: u8,
}

impl FeeAdapterState {
    pub const SIZE: usize = 2 // 2 bool
        + 32 * 3 // 3 Pubkey (fee_recipient, fee_signer, fill_signer)
        + 1; // u8
}

#[account]
pub struct IntentStatusAccount {
    pub status: IntentStatus,
    pub accounts: Vec<SerializableAccountMeta>,
    pub settlement: Option<Settlement>,
}

impl IntentStatusAccount {
    pub const SIZE: usize = 1 // IntentStatus
        + 136 // Option<Settlement>
        + 24 // accounts: Vec<SerializableAccountMeta>
    ;
}

/// Intent status.
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum IntentStatus {
    None,
    Added,
    Filled,
    Settled,
    SettledAndManuallyExecuted,
    Delivered,
}
