use crate::{
    consts::everclear_gateway,
    hyperlane::{
        transfer_remote, Igp, Mailbox, SplNoop, TransferRemote, TransferRemoteContext, U256,
    },
    instructions::MessageType,
};
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer, ID as TOKEN_PROGRAM_ID};

use crate::{
    consts::{DEFAULT_NORMALIZED_DECIMALS, EVERCLEAR_DOMAIN},
    error::SpokeError,
    events::IntentAddedEvent,
    intent::{encode_full, u64_to_u256_be, EVMIntent},
    state::SpokeState,
    state::{IntentStatus, IntentStatusAccount},
    utils::{compute_intent_hash, normalize_decimals},
};

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
    message_gas_limit: u64,
) -> Result<()> {
    // Clone to allow mut ref before move
    let spoke_state = ctx.accounts.spoke_state.clone();

    let state = &mut ctx.accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);
    require!(!destinations.is_empty(), SpokeError::InvalidOperation);
    require!(destinations.len() <= 10, SpokeError::InvalidIntent);

    // If a single destination and ttl != 0, require output_asset is non-zero.
    if destinations.len() == 1 {
        require!(output_asset != Pubkey::default(), SpokeError::InvalidIntent);
    } else {
        // For multi-destination, ttl must be 0 and output_asset must be default.
        require!(
            ttl == 0 && output_asset == Pubkey::default(),
            SpokeError::InvalidIntent
        );
    }
    // Check max_fee is within allowed range (for example, <= 10_000 for basis points)
    require!(max_fee <= 10_000, SpokeError::MaxFeeExceeded);
    // NOTE: we do not need to check data len as this is implicitly done with solana tx size limitation of 1232 bytes

    let minted_decimals = ctx.accounts.mint.decimals;
    let normalized_amount =
        normalize_decimals(amount, minted_decimals, DEFAULT_NORMALIZED_DECIMALS)?;
    require!(normalized_amount > 0, SpokeError::ZeroAmount); // Add zero amount check like Solidity

    // Transfer from user's token account -> program's vault
    let cpi_accounts = Transfer {
        from: ctx.accounts.user_token_account.to_account_info(),
        to: ctx.accounts.program_vault_account.to_account_info(),
        authority: ctx.accounts.authority.to_account_info(),
    };
    let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
    token::transfer(cpi_ctx, amount)?;

    // Update global nonce and create intent_id
    let new_nonce = state
        .nonce
        .checked_add(1)
        .ok_or(error!(SpokeError::InvalidOperation))?;
    state.nonce = new_nonce;
    let clock = Clock::get()?;

    // Now create your EVMIntent
    let evm_intent = EVMIntent {
        initiator: ctx.accounts.authority.key().to_bytes(),
        receiver: receiver.to_bytes(),
        input_asset: input_asset.to_bytes(),
        output_asset: output_asset.to_bytes(),
        max_fee,              // watch out for 24-bit range if that matters
        origin: state.domain, // your "origin_domain"
        nonce: new_nonce,
        timestamp: clock.unix_timestamp as u64,
        ttl,
        amount: u64_to_u256_be(normalized_amount),
        destinations: destinations.clone(),
        data: data.clone(),
    };

    // Hash the EVM intent information
    let intent_id = compute_intent_hash(&evm_intent);

    // Produce the EVM ABI message:
    // NOTE: message type should be
    let evm_encoded_message = encode_full(MessageType::Intent, &evm_intent);

    // Also, record a minimal status mapping (we only record the intent_id and its status).
    state.status.push(IntentStatusAccount {
        key: intent_id,
        status: IntentStatus::Added,
    });

    // Build your TransferRemote
    let xfer = TransferRemote {
        destination_domain: EVERCLEAR_DOMAIN,
        recipient: everclear_gateway(),
        amount_or_id: U256::from(normalized_amount),
        gas_amount: message_gas_limit,
        message_body: evm_encoded_message, // now in EVM ABI format
    };

    // TODO: make this no_copy
    // Build your TransferRemoteContext in a local variable (so it doesn't drop too soon)
    let mut transfer_remote_context = TransferRemoteContext {
        spoke_state,
        system_program: ctx.accounts.system_program.clone(),
        spl_noop_program: ctx.accounts.spl_noop_program.clone(),
        mailbox_program: ctx.accounts.hyperlane_mailbox.clone(),
        mailbox_outbox: ctx.accounts.mailbox_outbox.to_account_info(),
        dispatch_authority: ctx.accounts.dispatch_authority.to_account_info(),
        // TODO: need to figure out how this is used for the IGP payer and whether this is correct
        sender_wallet: ctx.accounts.authority.to_account_info(),
        unique_message_account: ctx.accounts.unique_message_account.to_account_info(),
        dispatched_message_pda: ctx.accounts.dispatched_message_pda.to_account_info(),
        igp_program: ctx.accounts.igp_program.clone(),
        igp_program_data: ctx.accounts.igp_program_data.to_account_info(),
        igp_payment_pda: ctx.accounts.igp_payment_pda.to_account_info(),
        configured_igp_account: ctx.accounts.configured_igp_account.to_account_info(),
        inner_igp_account: ctx.accounts.inner_igp_account.clone(),
    };

    // Now create the Anchor Context, referencing your local `transfer_remote_context`.
    let transfer_ctx = Context::new(
        ctx.program_id,
        &mut transfer_remote_context, // pass a mutable reference
        &[],                          // remaining accounts if needed
        Default::default(),           // any custom context seeds if needed
    );

    // 3) Use `transfer_ctx` safely
    transfer_remote(transfer_ctx, xfer)?;

    // Emit an event with full intent details.
    emit_cpi!(IntentAddedEvent {
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
    Ok(())
}

#[event_cpi]
#[derive(Accounts)]
pub struct NewIntent<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump,
        realloc = 8 + std::mem::size_of::<SpokeState>() +
            (std::mem::size_of::<IntentStatusAccount>() * (spoke_state.status.len() + 1)),
        realloc::payer = authority,
        realloc::zero = false,
    )]
    pub spoke_state: Account<'info, SpokeState>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub mint: Account<'info, Mint>,
    #[account(
        mut,
        associated_token::mint = mint,
        associated_token::authority = authority,
        associated_token::token_program = token_program,
    )]
    pub user_token_account: Account<'info, TokenAccount>,
    #[account(
        mut,
        associated_token::mint = mint,
        associated_token::authority = crate::ID,
        associated_token::token_program = token_program,
    )]
    pub program_vault_account: Account<'info, TokenAccount>,

    #[account(address = TOKEN_PROGRAM_ID)]
    pub token_program: Program<'info, Token>,

    /// CHECK: The Hyperlane Mailbox program (by address only).
    #[account(address = spoke_state.mailbox)]
    pub hyperlane_mailbox: Interface<'info, Mailbox>,

    // The system program
    pub system_program: Program<'info, System>,

    // The SPL-Noop program
    pub spl_noop_program: Program<'info, SplNoop>,

    /// CHECK: Outbox data account – the Mailbox will check this
    #[account(mut)]
    pub mailbox_outbox: AccountInfo<'info>,

    /// CHECK: Dispatch authority (PDA)
    #[account(mut)]
    pub dispatch_authority: AccountInfo<'info>,

    /// CHECK: A unique message / gas payment account (signer)
    #[account(mut, signer)]
    pub unique_message_account: AccountInfo<'info>,

    /// CHECK: The message storage PDA
    #[account(mut)]
    pub dispatched_message_pda: AccountInfo<'info>,

    //  If using IGP:
    #[account(executable)]
    pub igp_program: Interface<'info, Igp>,

    /// CHECK:
    #[account(mut)]
    pub igp_program_data: AccountInfo<'info>,

    /// CHECK:
    #[account(mut)]
    pub igp_payment_pda: AccountInfo<'info>,

    /// CHECK:
    #[account(mut)]
    pub configured_igp_account: AccountInfo<'info>,

    /// CHECK:
    #[account(mut)]
    pub inner_igp_account: Option<AccountInfo<'info>>,
}
