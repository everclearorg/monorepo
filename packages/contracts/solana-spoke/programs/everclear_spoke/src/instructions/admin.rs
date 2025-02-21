use anchor_lang::prelude::*;

use super::AdminState;
use crate::events::{
    GatewayUpdatedEvent, LighthouseUpdatedEvent, MailboxUpdatedEvent, MessageGasLimitUpdatedEvent,
    WatchtowerUpdatedEvent,
};

pub fn update_gateway(ctx: Context<AdminState>, new_gateway: Pubkey) -> Result<()> {
    let old = ctx.accounts.spoke_state.gateway;
    ctx.accounts.spoke_state.gateway = new_gateway;
    emit_cpi!(GatewayUpdatedEvent {
        old_gateway: old,
        new_gateway
    });
    Ok(())
}

pub fn update_lighthouse(ctx: Context<AdminState>, new_lighthouse: Pubkey) -> Result<()> {
    let old = ctx.accounts.spoke_state.lighthouse;
    ctx.accounts.spoke_state.lighthouse = new_lighthouse;
    emit_cpi!(LighthouseUpdatedEvent {
        old_lighthouse: old,
        new_lighthouse,
    });
    Ok(())
}

pub fn update_watchtower(ctx: Context<AdminState>, new_watchtower: Pubkey) -> Result<()> {
    let old = ctx.accounts.spoke_state.watchtower;
    ctx.accounts.spoke_state.watchtower = new_watchtower;
    emit_cpi!(WatchtowerUpdatedEvent {
        old_watchtower: old,
        new_watchtower,
    });
    Ok(())
}

pub fn update_mailbox(ctx: Context<AdminState>, new_mailbox: Pubkey) -> Result<()> {
    let old = ctx.accounts.spoke_state.mailbox;
    ctx.accounts.spoke_state.mailbox = new_mailbox;
    emit_cpi!(MailboxUpdatedEvent {
        old_mailbox: old,
        new_mailbox,
    });
    Ok(())
}

pub fn update_message_gas_limit(ctx: Context<AdminState>, new_limit: u64) -> Result<()> {
    let old: u64 = ctx.accounts.spoke_state.message_gas_limit;
    ctx.accounts.spoke_state.message_gas_limit = new_limit;
    emit_cpi!(MessageGasLimitUpdatedEvent {
        old_limit: old,
        new_limit,
    });
    Ok(())
}
