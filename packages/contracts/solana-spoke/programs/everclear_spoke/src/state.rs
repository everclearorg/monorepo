use anchor_lang::prelude::*;

use crate::hyperlane::InterchainGasPaymasterType;

/// Queue state with first/last indices for efficient management
#[derive(AnchorSerialize, AnchorDeserialize, Default, Clone)]
pub struct QueueState<T> {
    pub items: Vec<T>,
    pub first_index: u64,
    pub last_index: u64,
}

impl<T> QueueState<T> {
    pub const SIZE: usize = 8  // discriminator
    + 4    // vec length prefix
    + 8    // first
    + 8; // last
         // Add any other fixed size fields

    pub fn new() -> Self {
        Self {
            items: Vec::new(),
            first_index: 0,
            last_index: 0,
        }
    }

    pub fn push_back(&mut self, item: T) {
        self.items.push(item);
        self.last_index = self.last_index.saturating_add(1);
    }

    pub fn pop_front(&mut self) -> Option<T> {
        if !self.items.is_empty() {
            let item = self.items.remove(0);
            self.first_index = self.first_index.saturating_add(1);
            Some(item)
        } else {
            None
        }
    }

    pub fn len(&self) -> usize {
        self.items.len()
    }

    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }
}

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
    pub call_executor: Pubkey,
    pub message_receiver: Pubkey,
    // Message gas limit (stored, though not used on Solana).
    pub message_gas_limit: u64,
    // Global nonce for intents.
    pub nonce: u64,
    // Owner of the program (admin).
    pub owner: Pubkey,
    // Intent status mapping.
    pub status: Vec<IntentStatusAccount>,
    // Bump for PDA.
    pub bump: u8,
    // Mailbox address
    pub mailbox: Pubkey,
    // TODO: do we need admin function to increment this?
    // Bump for mailbox dispatch authority
    pub mailbox_dispatch_authority_bump: u8,
    // IGP address
    pub igp: Pubkey,
    // IGP Type which either contains igp address (as in `igp`) or the overhead IGP address if the IGP is an overhead IGP
    pub igp_type: InterchainGasPaymasterType,
}

impl SpokeState {
    pub const SIZE: usize = 1    // paused: bool
        + 1                      // initialized_version: u8
        + 4                      // domain: u32
        + 4                      // everclear: u32
        + 32 * 4                 // 5 Pubkeys
        + 8                      // message_gas_limit: u64
        + 8                      // nonce: u64
        + 32                     // owner: Pubkey
        + 4                      // status HashMap
        + 1                      // bump: u8
        + 32                     // mailbox: Pubkey
        + 1                      // mailbox_dispatch_authority_bump: u8
        + 32                     // igp: Pubkey
        + 33                     // igp_type: InterchainGasPaymasterType
        ;
        
}

#[account]
pub struct IntentStatusAccount {
    pub key: [u8; 32],
    pub status: IntentStatus,
}

/// Intent status.
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum IntentStatus {
    None,
    Added,
    Filled,
    Settled,
    SettledAndManuallyExecuted,
}
