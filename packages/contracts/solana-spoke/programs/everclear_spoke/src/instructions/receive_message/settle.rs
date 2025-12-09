use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::{
        spl_associated_token_account::instruction::create_associated_token_account_idempotent,
        AssociatedToken,
    },
    token::{self, Mint, Token, TokenAccount},
};

use crate::{
    consts::DEFAULT_NORMALIZED_DECIMALS,
    error::SpokeError,
    events::SettledEvent,
    state::{IntentStatus, IntentStatusAccount, SpokeState},
    utils::normalize_decimals,
    vault_authority_pda_seeds,
};

// NOTE: because we verified authority when creating delivered intents, this
// endpoint do not need to be authenticated as it only settles authenticated delivered intents.
pub fn settle_delivered_intent(
    ctx: Context<SettleDeliveredIntentContext>,
    _ix: SettleDeliveredIntentInstruction,
) -> Result<()> {
    // verifying the contract is not paused
    let state = &mut ctx.accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);

    // assert settlement exists and the status is delivered
    require!(
        ctx.accounts.intent_status_pda.settlement.is_some()
            && ctx.accounts.intent_status_pda.status == IntentStatus::Delivered,
        SpokeError::InvalidIntentStatus
    );
    // verify all account here matches the one in the intent status pda (except the event authority as they have seperate checks)
    require!(
        ctx.accounts.spoke_state.key() == ctx.accounts.intent_status_pda.accounts[0].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.intent_status_pda.key() == ctx.accounts.intent_status_pda.accounts[1].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.vault_authority.key() == ctx.accounts.intent_status_pda.accounts[2].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.token_program.key() == ctx.accounts.intent_status_pda.accounts[3].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.system_program.key() == ctx.accounts.intent_status_pda.accounts[4].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.mint_account.key() == ctx.accounts.intent_status_pda.accounts[5].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.associated_token_program.key()
            == ctx.accounts.intent_status_pda.accounts[6].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.recipient.key() == ctx.accounts.intent_status_pda.accounts[7].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.recipient_token_account.key()
            == ctx.accounts.intent_status_pda.accounts[8].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.vault_token_account.key() == ctx.accounts.intent_status_pda.accounts[9].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );

    // SAFE: settlement existence is checked
    let settlement = ctx.accounts.intent_status_pda.settlement.clone().unwrap();

    // 2) Mark as settled in storage
    ctx.accounts.intent_status_pda.status = IntentStatus::Settled;

    let mut buf = [0u8; 32];
    settlement.amount.to_little_endian(&mut buf);
    let normalized_amount = u128::from_be_bytes(buf[16..32].try_into().unwrap());

    // 3) Normalise the settlement amount
    let minted_decimals = ctx.accounts.mint_account.decimals;
    let amount = normalize_decimals(
        normalized_amount,
        DEFAULT_NORMALIZED_DECIMALS,
        minted_decimals,
    )?;

    require!(amount < u64::MAX.into(), SpokeError::InvalidAmount);

    if amount == 0 {
        return Ok(());
    }

    // Create ATA idempotently
    let create_idempotent_inst = create_associated_token_account_idempotent(
        ctx.accounts.authority.key,
        ctx.accounts.recipient.key,
        &ctx.accounts.mint_account.key(),
        ctx.accounts.token_program.key,
    );
    msg!("{:?}", create_idempotent_inst);
    anchor_lang::solana_program::program::invoke(
        &create_idempotent_inst,
        &[
            ctx.accounts.authority.to_account_info(),
            ctx.accounts.recipient_token_account.to_account_info(),
            ctx.accounts.recipient.to_account_info(),
            ctx.accounts.mint_account.to_account_info(),
            ctx.accounts.system_program.to_account_info(),
            ctx.accounts.token_program.to_account_info(),
        ],
    )?;

    let signer_seeds: &[&[u8]] =
        vault_authority_pda_seeds!(ctx.accounts.spoke_state.vault_authority_bump);
    let signer = &[signer_seeds];

    let cpi_accounts = anchor_spl::token::Transfer {
        from: ctx.accounts.vault_token_account.to_account_info(),
        to: ctx.accounts.recipient_token_account.to_account_info(),
        authority: ctx.accounts.vault_authority.to_account_info(),
    };
    let cpi_ctx = CpiContext::new_with_signer(
        ctx.accounts.token_program.to_account_info(),
        cpi_accounts,
        signer,
    );

    // NOTE: Removed the virtual balance logic
    token::transfer(cpi_ctx, amount as u64)?;

    emit_cpi!(SettledEvent {
        intent_id: settlement.intent_id,
        recipient: settlement.recipient,
        asset: settlement.asset,
        amount: amount as u64,
        domain: ctx.accounts.spoke_state.domain,
    });
    Ok(())
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct SettleDeliveredIntentInstruction {
    pub intent_id: [u8; 32],
}

#[event_cpi]
#[derive(Accounts)]
#[instruction(ix: SettleDeliveredIntentInstruction)]
pub struct SettleDeliveredIntentContext {
    // NOTE: authority will have to be the first account for the usage in receive_message
    #[account(mut)]
    pub authority: Signer<'info>,
    pub spoke_state: Account<'info, SpokeState>,
    #[account(
        mut,
        seeds = ["everclear_spoke".as_bytes(), "-".as_bytes(), "intent_status".as_bytes(), &ix.intent_id],
        bump,
    )]
    pub intent_status_pda: Account<'info, IntentStatusAccount>,

    /// CHECK: verification is done via the storage pda
    pub vault_authority: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,

    pub mint_account: Account<'info, Mint>,

    pub associated_token_program: Program<'info, AssociatedToken>,

    /// CHECK: verification is done via the storage pda
    pub recipient: UncheckedAccount<'info>,

    /// CHECK: verification is done via the storage pda
    #[account(mut)]
    pub recipient_token_account: UncheckedAccount<'info>,

    #[account(mut)]
    pub vault_token_account: Account<'info, TokenAccount>,
}
