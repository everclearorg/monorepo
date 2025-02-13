use std::collections::HashMap;

use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};

use crate::{error::SpokeError, events::WithdrawnEvent, state::SpokeState};
use super::utils::vault_authority_seeds;

/// Withdraw SPL tokens from the program's vault.
/// This reduces the user's on‑chain balance and transfers tokens out.
pub fn withdraw(
    ctx: Context<Withdraw>,
    vault_authority_bump: u8,
    amount: u64,
    self_program_id: &Pubkey,
) -> Result<()> {
    let state = &ctx.accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);
    require!(amount > 0, SpokeError::InvalidAmount);

    // Check the user has sufficient balance.
    reduce_balance(&mut ctx.accounts.spoke_state.balances, ctx.accounts.mint.key(), ctx.accounts.user_authority.key(), amount)?;
    
    // Transfer tokens from the vault to the user's token account.
    // The vault is owned by a PDA (program_vault_authority).
    let seeds = vault_authority_seeds(self_program_id, &ctx.accounts.mint.key(), vault_authority_bump);
    let signer_seeds = [
        &seeds[0][..],
        &seeds[1][..],
        &seeds[2][..],
        &seeds[3][..],
    ];
    let signer = &[&signer_seeds[..]];

    let cpi_accounts = Transfer {
        from: ctx.accounts.from_token_account.to_account_info(),
        to: ctx.accounts.to_token_account.to_account_info(),
        authority: ctx.accounts.vault_authority.to_account_info(),
    };
    let cpi_ctx = CpiContext::new_with_signer(ctx.accounts.token_program.to_account_info(), cpi_accounts, signer);
    token::transfer(cpi_ctx, amount)?;
    emit!(WithdrawnEvent {
        user: ctx.accounts.user_authority.key(),
        asset: ctx.accounts.mint.key(),
        amount,
    });
    Ok(())
}

fn reduce_balance(
    balances: &mut HashMap<Pubkey, HashMap<Pubkey, u64>>,
    asset: Pubkey,
    user: Pubkey,
    amount: u64,
) -> Result<()> {
    let user_balance = balances.entry(asset).or_insert_with(HashMap::new);
    let current_balance = user_balance.get(&user).cloned().unwrap_or(0);
    require!(current_balance >= amount, SpokeError::InvalidAmount);
    *user_balance.entry(user).or_insert(current_balance - amount) = current_balance - amount;
    Ok(())
}

// Withdraw: Transfer tokens from program vault to user.
#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    #[account(mut)]
    pub user_authority: Signer<'info>,
    pub mint: Account<'info, Mint>,
    #[account(mut, constraint = from_token_account.mint == mint.key())]
    pub from_token_account: Account<'info, TokenAccount>,
    #[account(mut, constraint = to_token_account.mint == mint.key())]
    pub to_token_account: Account<'info, TokenAccount>,
    #[account(
        seeds = [b"vault"],
        bump,  // This will use the bump passed in through the instruction
    )]
    /// CHECK: This is a PDA that signs for the vault.
    pub vault_authority: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
}
