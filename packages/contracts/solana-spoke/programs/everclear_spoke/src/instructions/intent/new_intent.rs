use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, Mint, TokenAccount, Transfer, ID as TOKEN_PROGRAM_ID};

use crate::{consts::{DEFAULT_NORMALIZED_DECIMALS, MAX_CALLDATA_SIZE}, error::SpokeError, events::IntentAddedEvent, state::{IntentStatus, IntentStatusAccount, SpokeState}, utils::{compute_intent_hash, normalize_decimals}};

/// Create a new intent.
/// The user "locks" funds (previously deposited) and creates an intent.
/// For simplicity, we assume full deposit has been made before.
pub fn new_intent(
    ctx: Context<NewIntent>,
    receiver: Pubkey,
    input_asset: Pubkey,
    output_asset: Pubkey,
    amount: u64,
    max_fee: u32,
    ttl: u64,
    destinations: Vec<u32>,
    data: Vec<u8>,
) -> Result<()> {
    let state = &mut ctx.accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);
    require!(destinations.len() > 0, SpokeError::InvalidOperation);
    require!(destinations.len() <= 10, SpokeError::InvalidIntent);

    // If a single destination and ttl != 0, require output_asset is non-zero.
    if destinations.len() == 1 {
        require!(output_asset != Pubkey::default(), SpokeError::InvalidIntent);
    } else {
        // For multi-destination, ttl must be 0 and output_asset must be default.
        require!(ttl == 0 && output_asset == Pubkey::default(), SpokeError::InvalidIntent);
    }
    // Check max_fee is within allowed range (for example, <= 10_000 for basis points)
    require!(max_fee <= 10_000, SpokeError::MaxFeeExceeded);
    require!(data.len() <= MAX_CALLDATA_SIZE, SpokeError::InvalidOperation);

    let minted_decimals = ctx.accounts.mint.decimals;
    let normalized_amount = normalize_decimals(
        amount,
        minted_decimals,
        DEFAULT_NORMALIZED_DECIMALS,
    )?;
    require!(normalized_amount > 0, SpokeError::ZeroAmount);  // Add zero amount check like Solidity

    // Transfer from user's token account -> program's vault
    let cpi_accounts = Transfer {
        from: ctx.accounts.user_token_account.to_account_info(),
        to: ctx.accounts.program_vault_account.to_account_info(),
        authority: ctx.accounts.authority.to_account_info(),
    };
    let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
    token::transfer(cpi_ctx, amount)?;

    // Update global nonce and create intent_id
    let new_nonce = state.nonce.checked_add(1).ok_or(SpokeError::InvalidOperation)?;
    state.nonce = new_nonce;
    let clock = Clock::get()?;
    
    // Create intent_id with all parameters
    // TODO: May need to encode this properly
    // TODO: Would need to update processIntentQueue logic on update
    // TODO: Check the clock operation here
    let new_intent_struct = Intent {
        initiator: ctx.accounts.authority.key(),
        receiver,
        input_asset,
        output_asset,
        max_fee,
        origin_domain: state.domain,
        nonce: new_nonce,
        timestamp: clock.unix_timestamp as u64,
        ttl,
        normalized_amount,
        destinations: destinations.clone(),
        data: data.clone(),
    };
    
    let intent_id = compute_intent_hash(&new_intent_struct);

    // Update intent queue and status
    state.intent_queue.push_back(intent_id);

    // Also, record a minimal status mapping (we only record the intent_id and its status).
    state.status.push(IntentStatusAccount{ key: intent_id, status: IntentStatus::Added });

    // Emit an event with full intent details.
    emit!(IntentAddedEvent {
        intent_id,
        initiator: ctx.accounts.authority.key(),
        receiver,
        input_asset,
        output_asset,
        normalized_amount,
        max_fee,
        origin_domain: state.domain,
        ttl,
        timestamp: clock.unix_timestamp as u64,
        destinations,
        data,
    });
    
    // TODO: Do we need this for off-chain logic?
    // let queue_index = state.intent_queue.last_index();   
    // emit!(IntentAddedEvent { ..., queue_index, ... });

    Ok(())
}

#[derive(Accounts)]
pub struct NewIntent<'info> {
    // The main state
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,

    // The user calling new_intent
    pub authority: Signer<'info>,

    // The mint of the token the user is depositing
    pub mint: Account<'info, Mint>,

    // The user's associated token account for that mint
    #[account(mut, constraint = user_token_account.mint == mint.key())]
    pub user_token_account: Account<'info, TokenAccount>,

    // The program's vault token account for that mint
    #[account(mut, constraint = program_vault_account.mint == mint.key())]
    pub program_vault_account: Account<'info, TokenAccount>,

    // The SPL token program
    // #[account(mut)]
    #[account(address = TOKEN_PROGRAM_ID)]
    pub token_program: Program<'info, Token>,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct Intent {
    pub initiator: Pubkey,
    pub receiver: Pubkey,
    pub input_asset: Pubkey,
    pub output_asset: Pubkey,
    pub max_fee: u32,
    pub origin_domain: u32,
    pub nonce: u64,
    pub timestamp: u64,
    pub ttl: u64,
    pub normalized_amount: u64,
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
}
