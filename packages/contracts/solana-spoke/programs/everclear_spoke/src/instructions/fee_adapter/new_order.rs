use anchor_lang::prelude::*;

use crate::error::SpokeError;
use crate::events::{IntentAddedEvent, OrderCreated};
use crate::instructions::{handle_new_intent, NewIntent, NewIntentAccounts};
use crate::utils::hash_intent_id_array;

/// Batch-create multiple intents and handle fees.
pub fn new_order(
    ctx: Context<NewIntent>,
    fee: u64,
    deadline: i64,
    sig: Vec<u8>,
    params: Vec<OrderParameters>, // need to check transaction limit
) -> Result<()> {
    let state = &mut ctx.accounts.spoke_state;

    require!(!state.paused, SpokeError::ContractPaused);
    require!(!params.is_empty(), SpokeError::EmptyParams);

    let asset = params[0].input_asset;
    for p in &params {
        require!(p.input_asset == asset, SpokeError::MultipleOrderAssets);
    }

    let pre_balance = **ctx.accounts.program_vault_account.to_account_info().lamports.borrow();
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
        let event_data = handle_new_intent(
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
        )?;

        emit_cpi!(IntentAddedEvent {
            intent_id: event_data.intent_id,
            message_id: event_data.message_id,
            initiator: event_data.initiator,
            receiver: event_data.receiver,
            input_asset: event_data.input_asset,
            output_asset: event_data.output_asset,
            normalized_amount: event_data.normalized_amount,
            max_fee: event_data.max_fee,
            origin_domain: event_data.origin_domain,
            nonce: event_data.nonce,
            ttl: event_data.ttl,
            timestamp: event_data.timestamp,
            destinations: event_data.destinations,
            data: event_data.data,
        });

        intent_ids.push(event_data.intent_id);
    }

    let post_balance = **ctx.accounts.program_vault_account.to_account_info().lamports.borrow();
    let native_value = post_balance.saturating_sub(pre_balance);

    // 4) Derive order ID and emit event
    let order_id = hash_intent_id_array(&intent_ids);

    emit_cpi!(OrderCreated {
        order_id,
        user: ctx.accounts.authority.key(),
        intent_ids: intent_ids.clone(),
        fee,
        native_value,
    });

    Ok(())
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct OrderParameters {
    pub destinations: Vec<u32>,
    pub receiver: Pubkey,
    pub input_asset: Pubkey,
    pub output_asset: Pubkey,
    pub amount: u64,
    pub max_fee: u32,
    pub ttl: u64,
    pub data: Vec<u8>,
    pub message_gas_limit: u64,
}
