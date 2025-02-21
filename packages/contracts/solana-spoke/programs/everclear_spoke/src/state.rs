use anchor_lang::prelude::*;

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
    pub gateway: Pubkey,
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
}

impl SpokeState {
    pub const SIZE: usize = 1    // paused: bool
        + 1                      // initialized_version: u8
        + 4                      // domain: u32
        + 4                      // everclear: u32
        + 32 * 5                 // 5 Pubkeys
        + 8                      // message_gas_limit: u64
        + 8                      // nonce: u64
        + 32                     // owner: Pubkey
        + 4                      // status HashMap
        + 1                      // bump: u8
        + 32; // mailbox: Pubkey
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
