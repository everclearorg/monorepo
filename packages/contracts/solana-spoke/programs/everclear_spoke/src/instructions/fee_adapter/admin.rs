use anchor_lang::prelude::*;

use crate::{
    events::{FeeAdapterPausedEvent, FeeRecipientUpdatedEvent, FeeSignerUpdatedEvent, FillSignerUpdatedEvent},
    state::{FeeAdapterState, SpokeState},
};

#[event_cpi]
#[derive(Accounts)]
pub struct FeeAdapterAdminState<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    #[account(
        mut,
        seeds = [b"fee-adapter-state"],
        bump
    )]
    pub fee_adapter_state: Account<'info, FeeAdapterState>,
    pub admin: Signer<'info>,
}

pub fn update_fee_recipient(
    ctx: Context<FeeAdapterAdminState>,
    new_fee_recipient: Pubkey,
) -> Result<()> {
    let old_fee_recipient = ctx.accounts.fee_adapter_state.fee_recipient;
    ctx.accounts.fee_adapter_state.fee_recipient = new_fee_recipient;
    emit_cpi!(FeeRecipientUpdatedEvent {
        old_fee_recipient,
        new_fee_recipient,
    });
    Ok(())
}

pub fn update_fee_signer(ctx: Context<FeeAdapterAdminState>, new_fee_signer: Pubkey) -> Result<()> {
    let old_fee_signer = ctx.accounts.fee_adapter_state.fee_signer;
    ctx.accounts.fee_adapter_state.fee_signer = new_fee_signer;
    emit_cpi!(FeeSignerUpdatedEvent {
        old_fee_signer,
        new_fee_signer,
    });
    Ok(())
}

pub fn update_fill_signer(ctx: Context<FeeAdapterAdminState>, new_fill_signer: Pubkey) -> Result<()> {
    let old_fill_signer = ctx.accounts.fee_adapter_state.fill_signer;
    ctx.accounts.fee_adapter_state.fill_signer = new_fill_signer;
    emit_cpi!(FillSignerUpdatedEvent {
        old_fill_signer,
        new_fill_signer,
    });
    Ok(())
}

pub fn pause_fee_adapter(ctx: Context<FeeAdapterAdminState>) -> Result<()> {
    ctx.accounts.fee_adapter_state.paused = true;
    emit_cpi!(FeeAdapterPausedEvent {});
    Ok(())
}

pub fn unpause_fee_adapter(ctx: Context<FeeAdapterAdminState>) -> Result<()> {
    ctx.accounts.fee_adapter_state.paused = false;
    emit_cpi!(FeeAdapterPausedEvent {});
    Ok(())
}
