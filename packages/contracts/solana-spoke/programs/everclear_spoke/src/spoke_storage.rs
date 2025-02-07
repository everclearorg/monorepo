/*
   Common types and constants shared across intent modules.
*/

use anchor_lang::prelude::*;
use std::collections::VecDeque;

/// Maximum number of intents that can be queued
pub const MAX_INTENT_QUEUE_SIZE: usize = 1000;
/// Maximum number of fills that can be queued
pub const MAX_FILL_QUEUE_SIZE: usize = 1000;
/// Maximum number of strategies that can be registered
pub const MAX_STRATEGIES: usize = 100;
/// Maximum number of modules that can be registered
pub const MAX_MODULES: usize = 50;
/// Maximum size of calldata in bytes
pub const MAX_CALLDATA_SIZE: usize = 10240; // 10KB

pub const FILL_INTENT_FOR_SOLVER_TYPEHASH: [u8; 32] = [0xAA; 32]; // placeholder
pub const PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH: [u8; 32] = [0xBB; 32];
pub const PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH: [u8; 32] = [0xCC; 32];

/// Dummy Permit2 address.
pub const PERMIT2: Pubkey = Pubkey::new_from_array([0u8; 32]);

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug, PartialEq)]
pub enum IntentStatus {
    None,
    Added,
    Filled,
    Settled,
    SettledAndManuallyExecuted,
}

/// Represents an intent in the system
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug, PartialEq)]
pub struct Intent {
    /// The owner of the intent
    pub owner: Pubkey,
    /// The nonce used for this intent
    pub nonce: u64,
    /// The strategy ID this intent belongs to
    pub strategy_id: u32,
    /// The calldata for this intent
    pub calldata: Vec<u8>,
    /// The timestamp when this intent was created
    pub timestamp: i64,
}

/// Represents a fill for an intent
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug, PartialEq)]
pub struct Fill {
    /// The intent this fill is for
    pub intent: Intent,
    /// The filler of this intent
    pub filler: Pubkey,
    /// The calldata for this fill
    pub calldata: Vec<u8>,
    /// The timestamp when this fill was created
    pub timestamp: i64,
}

/// Represents a strategy configuration
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug, PartialEq)]
pub struct Strategy {
    /// Unique identifier for the strategy
    pub id: u32,
    /// Whether the strategy is enabled
    pub enabled: bool,
    /// The module that handles this strategy
    pub module: Pubkey,
    /// Configuration data for the strategy
    pub config: Vec<u8>,
}

/// Represents a module that can handle strategies
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug, PartialEq)]
pub struct Module {
    /// The address of the module
    pub address: Pubkey,
    /// Whether the module is enabled
    pub enabled: bool,
    /// The strategies this module can handle
    pub strategies: Vec<u32>,
}

/// Main storage state for the spoke
#[account]
pub struct SpokeStorageState {
    /// The owner of this spoke
    pub owner: Pubkey,
    /// Whether the spoke is paused
    pub paused: bool,
    /// Current nonce for intent creation
    pub nonce: u64,
    /// The domain identifier for this spoke
    pub domain: u32,
    /// Gas limit for message processing
    pub message_gas_limit: u64,
    /// The gateway contract address
    pub gateway: Pubkey,
    /// The message receiver contract address
    pub message_receiver: Pubkey,
    /// The lighthouse contract address
    pub lighthouse: Pubkey,
    /// The watchtower contract address
    pub watchtower: Pubkey,
    /// The call executor contract address
    pub call_executor: Pubkey,
    /// The Everclear identifier
    pub everclear: u32,
    /// Queue of pending intents
    pub intent_queue: VecDeque<Intent>,
    /// Queue of pending fills
    pub fill_queue: VecDeque<Fill>,
    /// Registered strategies
    pub strategies: Vec<Strategy>,
    /// Registered modules
    pub modules: Vec<Module>,
    /// Token balances for users
    pub balances: Vec<(Pubkey, u64)>,
}

impl SpokeStorageState {
    pub const LEN: usize = 8 + // discriminator
        32 + // owner
        1 + // paused
        8 + // nonce
        4 + // domain
        8 + // message_gas_limit
        32 + // gateway
        32 + // message_receiver
        32 + // lighthouse
        32 + // watchtower
        32 + // call_executor
        4 + // everclear
        (MAX_INTENT_QUEUE_SIZE * (32 + 8 + 4 + MAX_CALLDATA_SIZE + 8)) + // intent_queue
        (MAX_FILL_QUEUE_SIZE * (32 + 8 + 4 + MAX_CALLDATA_SIZE + 8 + 32 + MAX_CALLDATA_SIZE + 8)) + // fill_queue
        (MAX_STRATEGIES * (4 + 1 + 32 + MAX_CALLDATA_SIZE)) + // strategies
        (MAX_MODULES * (32 + 1 + (4 * 100))) + // modules
        (1000 * (32 + 8)); // balances (assuming max 1000 users)
} 
