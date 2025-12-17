use anchor_lang::prelude::*;

use crate::{
    error::SpokeError,
    events::InitializedFeeAdapterEvent,
    state::{FeeAdapterState, SpokeState},
};

pub fn close_fee_adapter(ctx: Context<CloseFeeAdapter>) -> Result<()> {
    let state = &ctx.accounts.spoke_state;
    require!(
        state.owner == ctx.accounts.payer.key(),
        SpokeError::OnlyOwner
    );
    
    let _fee_adapter_state = &ctx.accounts.fee_adapter_state;
    
    let lamports = ctx.accounts.fee_adapter_state.to_account_info().lamports();
    **ctx.accounts.fee_adapter_state.to_account_info().try_borrow_mut_lamports()? = 0;
    **ctx.accounts.payer.to_account_info().try_borrow_mut_lamports()? += lamports;
    
    let data = ctx.accounts.fee_adapter_state.to_account_info().try_borrow_mut_data()?;
    data.fill(0);
    
    ctx.accounts.fee_adapter_state.to_account_info().assign(&anchor_lang::solana_program::system_program::ID);
    
    Ok(())
}

pub fn migrate_fee_adapter(
    ctx: Context<MigrateFeeAdapter>,
    fee_recipient: Pubkey,
    fee_signer: Pubkey,
    fill_signer: Pubkey,
) -> Result<()> {
    let state = &ctx.accounts.spoke_state;
    require!(
        state.owner == ctx.accounts.payer.key(),
        SpokeError::OnlyOwner
    );
    
    let fee_adapter_state = &mut ctx.accounts.fee_adapter_state;
    
    // Initialize all fields
    fee_adapter_state.initialized = true;
    fee_adapter_state.paused = false;
    fee_adapter_state.fee_recipient = fee_recipient;
    fee_adapter_state.fee_signer = fee_signer;
    fee_adapter_state.fill_signer = fill_signer;
    fee_adapter_state.bump = ctx.bumps.fee_adapter_state;

    emit_cpi!(InitializedFeeAdapterEvent {
        fee_recipient,
        fee_signer,
        fill_signer,
    });
    Ok(())
}

#[event_cpi]
#[derive(Accounts)]
pub struct CloseFeeAdapter<'info> {
    #[account(
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    
    /// Account may have old layout - we try to close it
    /// If it can't be deserialized, this will fail and manual closure may be needed
    #[account(
        mut,
        close = payer,
        seeds = [b"fee-adapter-state"],
        bump
    )]
    pub fee_adapter_state: Account<'info, FeeAdapterState>,
    
    #[account(mut)]
    pub payer: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[event_cpi]
#[derive(Accounts)]
pub struct MigrateFeeAdapter<'info> {
    #[account(
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    
    /// Account should be closed/empty before calling this
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

