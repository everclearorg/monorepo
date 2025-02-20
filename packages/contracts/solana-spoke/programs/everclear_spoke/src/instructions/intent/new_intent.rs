use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer, ID as TOKEN_PROGRAM_ID};
use crate::hyperlane::{transfer_remote, HyperlaneSealevelTokenPlugin, HyperlaneToken, TransferRemote, TransferRemoteContext, H256, U256, SplNoop, Mailbox, Igp};

use crate::{
    consts::{DEFAULT_NORMALIZED_DECIMALS, EVERCLEAR_DOMAIN, MAX_CALLDATA_SIZE},
    error::SpokeError,
    events::IntentAddedEvent,
    state::{IntentStatus, IntentStatusAccount, SpokeState},
    utils::{compute_intent_hash, normalize_decimals},
};

#[derive(Default, Debug, PartialEq, AnchorDeserialize, AnchorSerialize)]
pub struct HyperlanePlugin;

impl HyperlaneSealevelTokenPlugin for HyperlanePlugin {
    // We must define the required trait methods!
    fn initialize<'a, 'b>(
        _program_id: &Pubkey,
        _system_program: &'a AccountInfo<'b>,
        _token_account: &'a AccountInfo<'b>,
        _payer_account: &'a AccountInfo<'b>,
        _accounts_iter: &mut std::slice::Iter<'a, AccountInfo<'b>>,
    ) -> Result<Self> {
        // For example, do nothing:
        Ok(HyperlanePlugin)
    }

    fn transfer_in<'a, 'b>(
        _program_id: &Pubkey,
        _token: &HyperlaneToken<Self>,
        _sender_wallet: &'a AccountInfo<'b>,
        _accounts_iter: &mut std::slice::Iter<'a, AccountInfo<'b>>,
        _amount: u64,
    ) -> Result<()> {
        // For example, do nothing or do a CPI to spl_token:
        msg!("HyperlanePlugin::transfer_in called");
        Ok(())
    }
}


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
    let state = &mut ctx.accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);
    require!(destinations.len() > 0, SpokeError::InvalidOperation);
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
    require!(
        data.len() <= MAX_CALLDATA_SIZE,
        SpokeError::InvalidOperation
    );

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
        .ok_or(SpokeError::InvalidOperation)?;
    state.nonce = new_nonce;
    let clock = Clock::get()?;

    // Create intent_id with all parameters
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
    state.status.push(IntentStatusAccount {
        key: intent_id,
        status: IntentStatus::Added,
    });

    // Format message using proper message lib
    let xfer = TransferRemote {
        destination_domain: 1234,
        recipient: H256::zero(),
        amount_or_id: U256::from(normalized_amount),
        gas_amount: message_gas_limit,
    };

    // TODO: Need to use the batch message
    let batch_message = format_intent_message_batch(&[new_intent_struct])?;
    // Build your TransferRemoteContext in a local variable (so it doesn't drop too soon)
    let mut transfer_remote_context = TransferRemoteContext {
        system_program: ctx.accounts.system_program.clone(),
        spl_noop_program: ctx.accounts.spl_noop_program.clone(),
        token_account: ctx.accounts.program_vault_account.to_account_info(),
        mailbox_program: ctx.accounts.hyperlane_mailbox.clone(),
        mailbox_outbox: ctx.accounts.mailbox_outbox.to_account_info(),
        dispatch_authority: ctx.accounts.dispatch_authority.to_account_info(),
        sender_wallet: ctx.accounts.authority.to_account_info(),
        unique_message_account: ctx.accounts.unique_message_account.to_account_info(),
        dispatched_message_pda: ctx.accounts.dispatched_message_pda.to_account_info(),
        igp_program: ctx.accounts.igp_program.clone(),
        igp_program_data: ctx.accounts.igp_program_data.to_account_info(),
        igp_payment_pda: ctx.accounts.igp_payment_pda.to_account_info(),
        configured_igp_account: ctx.accounts.configured_igp_account.to_account_info(),
        inner_igp_account:ctx.accounts.inner_igp_account.clone(),
    };

    // Now create the Anchor Context, referencing your local `transfer_remote_context`.
    let transfer_ctx = Context::new(
        ctx.program_id,
        &mut transfer_remote_context, // pass a mutable reference
        &[],                          // remaining accounts if needed
        Default::default(),           // any custom context seeds if needed
    );


    // 3) Use `transfer_ctx` safely
    transfer_remote::<HyperlanePlugin>(transfer_ctx, xfer)?;

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

    //  emit!(IntentQueueProcessedEvent {
    //     message_id,
    //     first_index: old_first,
    //     last_index: old_first + intents.len() as u64,
    //     fee_spent,
    // });
    Ok(())
}

fn format_intent_message_batch(intents: &[Intent]) -> Result<Vec<u8>> {
    // Example:
    let mut buffer = Vec::new();
    // e.g. prefix a message type byte
    buffer.push(1);
    // then Borsh‐encode the `Vec<Intent>`
    let encoded = intents.try_to_vec()?;
    buffer.extend_from_slice(&encoded);
    Ok(buffer)
}

// pub fn mailbox_outbox_dispatch<'info>(
//     ctx: CpiContext<'_, '_, '_, 'info, Transfer<'info>>,
//     lamports: u64,
// ) -> Result<()> {
//     let ix = crate::solana_program::system_instruction::transfer(
//         ctx.accounts.from.key,
//         ctx.accounts.to.key,
//         lamports,
//     );
//     crate::solana_program::program::invoke_signed(
//         &ix,
//         &[ctx.accounts.from, ctx.accounts.to],
//         ctx.signer_seeds,
//     )
//     .map_err(Into::into)
// }

#[derive(Accounts)]
pub struct NewIntent<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,

    pub authority: Signer<'info>,

    pub mint: Account<'info, Mint>,
    #[account(mut, constraint = user_token_account.mint == mint.key())]
    pub user_token_account: Account<'info, TokenAccount>,
    #[account(mut, constraint = program_vault_account.mint == mint.key())]
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
