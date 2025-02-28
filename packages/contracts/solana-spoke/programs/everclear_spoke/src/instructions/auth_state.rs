use anchor_lang::prelude::*;
use anchor_spl::token::{Token, TokenAccount};

use crate::state::SpokeState;

#[event_cpi]
#[derive(Accounts)]
pub struct AuthState<'info> {
    // NOTE: authority will have to be the first account for the usage in receive_message
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = 8 + SpokeState::SIZE,
        seeds = [b"spoke-state"],
        bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    #[account(mut)]
    pub vault_token_account: Account<'info, TokenAccount>,
    /// CHECK: This is a PDA that signs for the vault
    pub vault_authority: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[event_cpi]
#[derive(Accounts)]
pub struct AdminState<'info> {
    #[account(mut)]
    pub spoke_state: Account<'info, SpokeState>,
    pub admin: Signer<'info>,
}
