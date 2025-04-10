use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount};

use crate::{
    consts::DEFAULT_NORMALIZED_DECIMALS,
    error::SpokeError,
    events::SettledEvent,
    intent_status_pda_seeds,
    state::{IntentStatus, IntentStatusAccount, SpokeState},
    utils::normalize_decimals,
    vault_authority_pda_seeds,
};

// NOTE: because we verified authority when creating delivered intents, this
// endpoint do not need to be authenticated as it only settles authenticated delivered intents.
pub fn settle_delivered_intent(
    ctx: Context<SettleDeliveredIntentContext>,
    intent_id: SettleDeliveredIntentInstruction,
) -> Result<()> {
    // verify intent status pda matches intent id
    let intent_status_seed: &[&[u8]] = intent_status_pda_seeds!(intent_id.intent_id);
    // return canonical pda for intent status
    let (intent_status_account, _) =
        Pubkey::find_program_address(intent_status_seed, ctx.program_id);
    require!(
        ctx.accounts.intent_status_pda.key() == intent_status_account,
        SpokeError::InvalidIntentPda
    );
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
        ctx.accounts.recipient_token_account.key()
            == ctx.accounts.intent_status_pda.accounts[6].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );
    require!(
        ctx.accounts.vault_token_account.key() == ctx.accounts.intent_status_pda.accounts[7].pubkey,
        SpokeError::IncorrectSettlementAccounts
    );

    // SAFE: settlement existance is checked
    let settlement = ctx.accounts.intent_status_pda.settlement.clone().unwrap();

    // 2) Mark as settled in storage
    ctx.accounts.intent_status_pda.status = IntentStatus::Settled;

    // 3) Normalise the settlement amount
    let minted_decimals = ctx.accounts.mint_account.decimals;
    let amount = normalize_decimals(
        settlement.amount.low_u64(),
        DEFAULT_NORMALIZED_DECIMALS,
        minted_decimals,
    )?;
    if amount == 0 {
        return Ok(());
    }

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
    token::transfer(cpi_ctx, amount)?;

    emit_cpi!(SettledEvent {
        intent_id: settlement.intent_id,
        recipient: settlement.recipient,
        asset: settlement.asset,
        amount,
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
pub struct SettleDeliveredIntentContext {
    // NOTE: authority will have to be the first account for the usage in receive_message
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(mut)]
    pub spoke_state: Account<'info, SpokeState>,
    // NOTE: validation of intent pda is done inside call
    #[account(mut)]
    pub intent_status_pda: Account<'info, IntentStatusAccount>,

    /// CHECK: This is a PDA that signs for the vault
    pub vault_authority: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,

    pub mint_account: Account<'info, Mint>,

    pub recipient_token_account: Account<'info, TokenAccount>,

    pub vault_token_account: Account<'info, TokenAccount>,
}
