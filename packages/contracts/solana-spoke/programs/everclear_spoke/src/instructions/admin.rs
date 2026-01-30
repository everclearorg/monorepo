use anchor_lang::prelude::*;

use crate::{
    events::{
        IgpUpdatedEvent, LighthouseUpdatedEvent, MailboxDispatchAuthorityBumpUpdatedEvent,
        MailboxUpdatedEvent, MessageGasLimitUpdatedEvent, MessagingProviderSwitchedEvent,
        VaultAuthorityBumpUpdatedEvent, WatchtowerUpdatedEvent,
    },
    hyperlane::InterchainGasPaymasterType,
    state::{MessagingProviderType, SpokeState},
};

#[event_cpi]
#[derive(Accounts)]
pub struct AdminState<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    pub admin: Signer<'info>,
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

pub fn update_igp(
    ctx: Context<AdminState>,
    new_igp: Pubkey,
    new_igp_type: InterchainGasPaymasterType,
) -> Result<()> {
    let old_igp = ctx.accounts.spoke_state.igp;
    let old_igp_type = ctx.accounts.spoke_state.igp_type;
    ctx.accounts.spoke_state.igp = new_igp;
    ctx.accounts.spoke_state.igp_type = new_igp_type;
    emit_cpi!(IgpUpdatedEvent {
        old_igp,
        new_igp,
        old_igp_type,
        new_igp_type
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

pub fn update_mailbox_dispatch_authority_bump(
    ctx: Context<AdminState>,
    new_bump: u8,
) -> Result<()> {
    let old_bump: u8 = ctx.accounts.spoke_state.mailbox_dispatch_authority_bump;
    ctx.accounts.spoke_state.mailbox_dispatch_authority_bump = new_bump;
    emit_cpi!(MailboxDispatchAuthorityBumpUpdatedEvent { old_bump, new_bump });
    Ok(())
}

pub fn update_vault_authority_bump(ctx: Context<AdminState>, new_bump: u8) -> Result<()> {
    let old_bump: u8 = ctx.accounts.spoke_state.vault_authority_bump;
    ctx.accounts.spoke_state.vault_authority_bump = new_bump;
    emit_cpi!(VaultAuthorityBumpUpdatedEvent { old_bump, new_bump });
    Ok(())
}

pub fn switch_to_ccip(
    ctx: Context<AdminState>,
    ccip_router: Pubkey,
    ccip_offramp: Pubkey,
    ccip_chain_selector: u64,
    everclear_ccip_chain_selector: u64,
    everclear_gateway: [u8; 32],
) -> Result<()> {
    ctx.accounts.spoke_state.ccip_router = Some(ccip_router);
    ctx.accounts.spoke_state.ccip_offramp = Some(ccip_offramp);
    ctx.accounts.spoke_state.ccip_chain_selector = Some(ccip_chain_selector);
    ctx.accounts.spoke_state.everclear_ccip_chain_selector = Some(everclear_ccip_chain_selector);
    ctx.accounts.spoke_state.everclear_gateway = everclear_gateway;
    ctx.accounts.spoke_state.messaging_provider = MessagingProviderType::CCIP;
    emit_cpi!(MessagingProviderSwitchedEvent {
        provider: MessagingProviderType::CCIP as u8,
    });
    Ok(())
}

pub fn rollback_to_hyperlane(ctx: Context<AdminState>) -> Result<()> {
    ctx.accounts.spoke_state.messaging_provider = MessagingProviderType::Hyperlane;
    emit_cpi!(MessagingProviderSwitchedEvent {
        provider: MessagingProviderType::Hyperlane as u8,
    });
    Ok(())
}
