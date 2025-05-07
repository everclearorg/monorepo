use anchor_lang::prelude::*;

use crate::consts::DEFAULT_NORMALIZED_DECIMALS;
use crate::error::SpokeError;
use crate::events::OrderCreated;
use crate::instructions::{handle_new_intent, NewIntent, NewIntentAccounts};
use crate::intent::{u128_to_u256_be, EVMIntent};
use crate::types::OrderParameters;
use crate::utils::{hash_intent_id_array,compute_intent_hash ,normalize_decimals};

/// Batch-create multiple intents and handle fees.
pub fn new_order(
    ctx: Context<NewIntent>,
    fee: u64,
    deadline: i64,
    sig: Vec<u8>,
    params: Vec<OrderParameters>,
) -> Result<()> {
    // 1) Validate inputs
    require!(!params.is_empty(), SpokeError::EmptyParams);
    let asset = params[0].input_asset;
    for p in &params {
        require!(p.input_asset == asset, SpokeError::MultipleOrderAssets);
    }

    // handle_fees(&ctx, fee, asset, deadline, sig)?; yet to implement


    let mut accounts = NewIntentAccounts {
        spoke_state: ctx.accounts.spoke_state.clone(),
        mint: ctx.accounts.mint.clone(),
        token_program: ctx.accounts.token_program.clone(),
        program_vault_account: ctx.accounts.program_vault_account.clone(),
        user_token_account: ctx.accounts.user_token_account.clone(),
        authority: ctx.accounts.authority.clone(),
        system_program: ctx.accounts.system_program.clone(),
        spl_noop_program: ctx.accounts.spl_noop_program.clone(),
        hyperlane_mailbox: ctx.accounts.hyperlane_mailbox.clone(),
        mailbox_outbox: ctx.accounts.mailbox_outbox.clone(),
        dispatch_authority: ctx.accounts.dispatch_authority.clone(),
        unique_message_account: ctx.accounts.unique_message_account.clone(),
        dispatched_message_pda: ctx.accounts.dispatched_message_pda.clone(),
        igp_program: ctx.accounts.igp_program.clone(),
        igp_program_data: ctx.accounts.igp_program_data.clone(),
        igp_payment_pda: ctx.accounts.igp_payment_pda.clone(),
        configured_igp_account: ctx.accounts.configured_igp_account.clone(),
        inner_igp_account: ctx.accounts.inner_igp_account.clone(),
    };

    let program_id = ctx.program_id.clone();

    let mut intent_ids: Vec<[u8; 32]> = Vec::with_capacity(params.len());
    for p in &params {
        let _ = handle_new_intent(
            &mut accounts,
            program_id,
            p.receiver,
            p.input_asset,
            p.output_asset,
            p.amount,
            p.max_fee,
            p.ttl,
            p.destinations.clone(),
            p.data.clone(),
            p.message_gas_limit,
        );

        // Recompute intent ID exactly as in new_intent
        let minted_decimals = ctx.accounts.mint.decimals;
        let normalized_amt = normalize_decimals(
            p.amount as u128,
            minted_decimals,
            DEFAULT_NORMALIZED_DECIMALS,
        )?;
        let clock = Clock::get()?;
        let evm_intent = EVMIntent {
            initiator: ctx.accounts.authority.key().to_bytes(),
            receiver: p.receiver.to_bytes(),
            input_asset: p.input_asset.to_bytes(),
            output_asset: p.output_asset.to_bytes(),
            max_fee: p.max_fee,
            origin: ctx.accounts.spoke_state.domain,
            nonce: ctx.accounts.spoke_state.nonce,
            timestamp: clock.unix_timestamp as u64,
            ttl: p.ttl,
            amount: u128_to_u256_be(normalized_amt),
            destinations: p.destinations.clone(),
            data: p.data.clone(),
        };
        let intent_id = compute_intent_hash(&evm_intent);
        intent_ids.push(intent_id);
    }

    // 4) Derive order ID and emit event
    let order_id = hash_intent_id_array(&intent_ids);

    emit_cpi!(OrderCreated {
        order_id,
        user: ctx.accounts.authority.key(),
        intent_ids: intent_ids.clone(),
        fee,
        native_value: ctx.accounts.authority.lamports(),
    });

    Ok(())
}
