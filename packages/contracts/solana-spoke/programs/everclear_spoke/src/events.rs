use anchor_lang::prelude::*;

use crate::hyperlane::InterchainGasPaymasterType;

// =====================================================================
// EVENTS
// =====================================================================

#[event]
pub struct InitializedEvent {
    pub owner: Pubkey,
    pub domain: u32,
    pub everclear: u32,
}

#[event]
pub struct PausedEvent {}

#[event]
pub struct UnpausedEvent {}

#[event]
pub struct WithdrawnEvent {
    pub user: Pubkey,
    pub asset: Pubkey,
    pub amount: u64,
}

#[event]
pub struct IntentAddedEvent {
    pub intent_id: [u8; 32],
    pub initiator: Pubkey,
    pub receiver: Pubkey,
    pub input_asset: Pubkey,
    pub output_asset: Pubkey,
    pub normalized_amount: u64,
    pub max_fee: u32,
    pub origin_domain: u32,
    pub ttl: u64,
    pub timestamp: u64,
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
}

#[event]
pub struct IntentQueueProcessedEvent {
    pub message_id: [u8; 32],
    pub first_index: u64,
    pub last_index: u64,
    pub fee_spent: u64,
}

#[event]
pub struct GatewayUpdatedEvent {
    pub old_gateway: Pubkey,
    pub new_gateway: Pubkey,
}

#[event]
pub struct MailboxUpdatedEvent {
    pub old_mailbox: Pubkey,
    pub new_mailbox: Pubkey,
}

#[event]
pub struct IgpUpdatedEvent {
    pub old_igp: Pubkey,
    pub new_igp: Pubkey,
    pub old_igp_type: InterchainGasPaymasterType,
    pub new_igp_type: InterchainGasPaymasterType,
}

#[event]
pub struct LighthouseUpdatedEvent {
    pub old_lighthouse: Pubkey,
    pub new_lighthouse: Pubkey,
}

#[event]
pub struct WatchtowerUpdatedEvent {
    pub old_watchtower: Pubkey,
    pub new_watchtower: Pubkey,
}

#[event]
pub struct MessageReceivedEvent {
    pub origin: u32,
    pub sender: Pubkey,
}

#[event]
pub struct AssetTransferFailed {
    pub asset: Pubkey,
    pub recipient: Pubkey,
    pub amount: u64,
}

#[event]
pub struct SettledEvent {
    pub intent_id: [u8; 32],
    pub recipient: Pubkey,
    pub asset: Pubkey,
    pub amount: u64,
}

#[event]
pub struct MessageGasLimitUpdatedEvent {
    pub old_limit: u64,
    pub new_limit: u64,
}

#[event]
pub struct MailboxDispatchAuthorityBumpUpdatedEvent {
    pub old_bump: u8,
    pub new_bump: u8,
}

#[event]
pub struct VaultAuthorityBumpUpdatedEvent {
    pub old_bump: u8,
    pub new_bump: u8,
}
