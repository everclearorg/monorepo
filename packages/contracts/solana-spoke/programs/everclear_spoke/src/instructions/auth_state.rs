use anchor_lang::prelude::*;
use anchor_spl::token::{Token, TokenAccount};

use crate::state::SpokeState;

#[derive(Accounts)]
pub struct AuthState<'info> {
    #[account(mut)]
    pub spoke_state: Account<'info, SpokeState>,
    pub authority: Signer<'info>,
    #[account(mut)]
    pub vault_token_account: Account<'info, TokenAccount>,
    /// CHECK: This is a PDA that signs for the vault
    pub vault_authority: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
    /// CHECK: This is the Hyperlane mailbox program
    pub hyperlane_mailbox: UncheckedAccount<'info>,
}
