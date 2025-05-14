use anchor_lang::prelude::*;

use crate::{
    error::SpokeError,
    events::InitializedFeeAdapterEvent,
    state::{FeeAdapterState, SpokeState},
};

pub fn initialize_fee_adapter(
    ctx: Context<InitializeFeeAdapter>,
    fee_recipient: Pubkey,
    fee_signer: Pubkey,
) -> Result<()> {
    let state = &mut ctx.accounts.fee_adapter_state;

    require!(!state.initialized, SpokeError::AlreadyInitialized);
    state.initialized = true;
    state.paused = false;
    state.fee_recipient = fee_recipient;
    state.fee_signer = fee_signer;

    state.bump = ctx.bumps.fee_adapter_state;

    emit_cpi!(InitializedFeeAdapterEvent {
        fee_recipient,
        fee_signer,
    });
    Ok(())
}

#[event_cpi]
#[derive(Accounts)]
pub struct InitializeFeeAdapter<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    #[account(
        init,
        payer = payer,
        space = 8 + FeeAdapterState::SIZE,
        seeds = [b"fee-adapter-state"],
        bump
    )]
    pub fee_adapter_state: Account<'info, FeeAdapterState>,
    #[account(mut)]
    pub payer: Signer<'info>,
    pub system_program: Program<'info, System>,
}
