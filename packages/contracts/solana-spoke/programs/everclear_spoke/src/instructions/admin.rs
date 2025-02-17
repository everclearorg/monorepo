use anchor_lang::prelude::*;

use crate::{events::{GatewayUpdatedEvent, LighthouseUpdatedEvent, MailboxUpdatedEvent, WatchtowerUpdatedEvent, MessageGasLimitUpdatedEvent}, state::SpokeState};

pub fn update_gateway(state: &mut SpokeState, new_gateway: Pubkey) -> Result<()> {
    let old = state.gateway;
    state.gateway = new_gateway;
    emit!(GatewayUpdatedEvent { old_gateway: old, new_gateway });
    Ok(())
}

pub fn update_lighthouse(state: &mut SpokeState, new_lighthouse: Pubkey) -> Result<()> {
    let old = state.lighthouse;
    state.lighthouse = new_lighthouse;
    emit!(LighthouseUpdatedEvent {
        old_lighthouse: old,
        new_lighthouse,
    });
    Ok(())
}

pub fn update_watchtower(state: &mut SpokeState, new_watchtower: Pubkey) -> Result<()> {
    let old = state.watchtower;
    state.watchtower = new_watchtower;
    emit!(WatchtowerUpdatedEvent {
        old_watchtower: old,
        new_watchtower,
    });
    Ok(())
}

pub fn update_mailbox(state: &mut SpokeState, new_mailbox: Pubkey) -> Result<()> {
    let old = state.mailbox;
    state.mailbox = new_mailbox;
    emit!(MailboxUpdatedEvent {
        old_mailbox: old,
        new_mailbox,
    });
    Ok(())
}

pub fn update_message_gas_limit(state: &mut SpokeState, new_limit: u64) -> Result<()> {
    let old: u64 = state.message_gas_limit;
    state.message_gas_limit = new_limit;
    emit ! (MessageGasLimitUpdatedEvent {
        old_limit: old,
        new_limit,
    });
    Ok(())
}
