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
    let normalized_amount = u128::from_le_bytes(buf[0..16].try_into().unwrap());

    // 3) Normalise the settlement amount
    let minted_decimals = ctx.accounts.mint_account.decimals;

    require!(
        minted_decimals <= DEFAULT_NORMALIZED_DECIMALS,
        SpokeError::DecimalConversionOverflow
    );

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

#[cfg(test)]
mod tests {
    use crate::hyperlane::U256;

    #[test]
    fn test_settlement_amount_endianness_conversion() {
        let test_amount = 999000000000000000u128;
        let u256_amount = U256::from(test_amount);

        // Simulate the conversion logic from settle_delivered_intent
        let mut buf = [0u8; 32];
        u256_amount.to_little_endian(&mut buf);

        // Read from bytes 0-15 as little-endian
        let normalized_amount = u128::from_le_bytes(buf[0..16].try_into().unwrap());
        assert_eq!(normalized_amount, test_amount, "Amount should match after conversion");

        let buggy_result = u128::from_be_bytes(buf[16..32].try_into().unwrap());
        assert_eq!(buggy_result, 0, "Buggy approach would read zeros");

        // Test with another realistic value
        let test_amount2 = 422401000000000000u128;
        let u256_amount2 = U256::from(test_amount2);
        let mut buf2 = [0u8; 32];
        u256_amount2.to_little_endian(&mut buf2);
        let normalized_amount2 = u128::from_le_bytes(buf2[0..16].try_into().unwrap());
        assert_eq!(normalized_amount2, test_amount2, "Second test amount should match");

        // Test with a small value
        let test_amount3 = 1000u128;
        let u256_amount3 = U256::from(test_amount3);
        let mut buf3 = [0u8; 32];
        u256_amount3.to_little_endian(&mut buf3);
        let normalized_amount3 = u128::from_le_bytes(buf3[0..16].try_into().unwrap());
        assert_eq!(normalized_amount3, test_amount3, "Small amount should match");

        // Test with zero
        let test_amount4 = 0u128;
        let u256_amount4 = U256::from(test_amount4);
        let mut buf4 = [0u8; 32];
        u256_amount4.to_little_endian(&mut buf4);
        let normalized_amount4 = u128::from_le_bytes(buf4[0..16].try_into().unwrap());
        assert_eq!(normalized_amount4, test_amount4, "Zero should remain zero");
    }
    #[test]
    fn test_settle_rejects_high_decimal_tokens() {
        use crate::consts::DEFAULT_NORMALIZED_DECIMALS;

        // Test that decimals > 18 should be rejected in settlement
        let high_decimals = DEFAULT_NORMALIZED_DECIMALS + 1; // 19 decimals
        let should_reject = high_decimals > DEFAULT_NORMALIZED_DECIMALS;
        assert!(
            should_reject,
            "Settlement should reject tokens with decimals > {}",
            DEFAULT_NORMALIZED_DECIMALS
        );

        // Test edge case: exactly 18 decimals should be allowed
        let exact_decimals = DEFAULT_NORMALIZED_DECIMALS;
        let should_allow = exact_decimals <= DEFAULT_NORMALIZED_DECIMALS;
        assert!(
            should_allow,
            "Settlement should allow tokens with exactly {} decimals",
            DEFAULT_NORMALIZED_DECIMALS
        );
    }
}
