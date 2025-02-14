use std::collections::{VecDeque};

use anchor_lang::prelude::*;

use crate::consts::MAX_INTENT_QUEUE_SIZE;

/// Queue state with first/last indices for efficient management
#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct QueueState<T> {
    pub items: VecDeque<T>,
    pub first_index: u64,
    pub last_index: u64,
}

impl<T> QueueState<T> {
    pub const SIZE: usize = 8  // discriminator
    + 4    // vec length prefix
    + 8    // first
    + 8;   // last
    // Add any other fixed size fields
    
    pub fn new() -> Self {
        Self {
            items: VecDeque::new(),
            first_index: 0,
            last_index: 0,
        }
    }

    pub fn push_back(&mut self, item: T) {
        self.items.push_back(item);
        self.last_index = self.last_index.saturating_add(1);
    }

    pub fn pop_front(&mut self) -> Option<T> {
        let item = self.items.pop_front();
        if item.is_some() {
            self.first_index = self.first_index.saturating_add(1);
        }
        item
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
    pub status: Vec<([u8; 32], IntentStatusAccount)>,
    // Dynamic mappings/queues
    pub intent_queue: QueueState<[u8;32]>,
    // Bump for PDA.
    pub bump: u8,
    // Mailbox address
    pub mailbox: Pubkey
}

#[account]
pub struct IntentStatusAccount {
    pub key: [u8; 32],
    pub status: IntentStatus,
    pub bump: u8, // if needed
}

impl SpokeState {
    pub const SIZE: usize = 1    // paused: bool
        + 4                      // domain: u32
        + 4                      // everclear: u32
        + 32 * 5                 // 5 Pubkeys
        + 8                      // message_gas_limit: u64
        + 8                      // nonce: u64
        + 32                     // owner: Pubkey
        + 4 + (MAX_INTENT_QUEUE_SIZE * (32 + 1))  // status HashMap
        + QueueState::<[u8;32]>::SIZE      // intent_queue
        + 1;                     // bump: u8
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
