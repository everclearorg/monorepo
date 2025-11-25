use anchor_lang::prelude::*;

use crate::{
    hyperlane::{InterchainGasPaymasterType, SerializableAccountMeta},
    instructions::{messages::Settlement, EVMIntent},
};

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
pub struct IntentAddedEvent {
    pub intent_id: [u8; 32],
    pub message_id: [u8; 32],
    pub initiator: Pubkey,
    pub receiver: Pubkey,
    pub input_asset: Pubkey,
    pub output_asset: Pubkey,
    pub normalized_amount: u128,
    pub max_fee: u32,
    pub origin_domain: u32,
    pub nonce: u64,
    pub ttl: u64,
    pub timestamp: u64,
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
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
pub struct MessageDeliveredEvent {
    pub domain: u32,
    pub settlement: Settlement,
    pub account_metas: Vec<SerializableAccountMeta>,
}

#[event]
pub struct SettledEvent {
    pub intent_id: [u8; 32],
    pub recipient: Pubkey,
    pub asset: Pubkey,
    pub amount: u64,
    pub domain: u32,
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

#[event]
pub struct InitializedFeeAdapterEvent {
    pub fee_recipient: Pubkey,
    pub fee_signer: Pubkey,
}

#[event]
pub struct FeeRecipientUpdatedEvent {
    pub old_fee_recipient: Pubkey,
    pub new_fee_recipient: Pubkey,
}

#[event]
pub struct FeeSignerUpdatedEvent {
    pub old_fee_signer: Pubkey,
    pub new_fee_signer: Pubkey,
}

#[event]
pub struct FeeAdapterPausedEvent {}

#[event]
pub struct FeeAdapterUnpausedEvent {}

#[event]
pub struct OrderCreated {
    pub order_id: [u8; 32],
    pub user: Pubkey,
    pub intent_ids: Vec<[u8; 32]>,
    pub fee: u64,
    pub native_value: u64,
}

#[event]
pub struct IntentWithFeesAddedEvent {
    pub intent_id: [u8; 32],
    pub initiator: Pubkey,
    pub input_asset: Pubkey,
    /// native amount in Solana
    pub amount: u64,
    /// native amount in Solana
    pub fee: u64,
}

#[event]
pub struct IntentFilledEvent {
    pub intent_id: [u8; 32],
    pub message_id: [u8; 32],
    pub solver: Pubkey,
    pub receiver: [u8; 32],
    pub amount_out: u64,
    pub intent: EVMIntent,
}
