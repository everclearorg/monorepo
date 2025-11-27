use anchor_lang::prelude::*;

use crate::error::SpokeError;
use crate::events::OrderCreated;
use crate::instructions::fee_adapter::{
    handle_fees, FeeData, FeeParams, HandleFeeAccounts, SignatureAccounts,
};
use crate::instructions::{handle_new_intent, NewIntent, NewIntentAccounts};
use crate::utils::hash_intent_id_array;

/// Batch-create multiple intents and handle fees.
pub fn new_order(
    ctx: Context<NewIntent>,
    params: Vec<OrderParameters>,
    fee_param: FeeParams,
) -> Result<()> {
    let state = &mut ctx.accounts.spoke_state;

    require!(!state.paused, SpokeError::ContractPaused);
    require!(!params.is_empty(), SpokeError::EmptyParams);
    require!(
        !ctx.accounts.fee_adapter_state.paused,
        SpokeError::FeeAdapterPaused
    );

    // NOTE: asset is required to be the same from accounts.mint.
    let mut accounts = NewIntentAccounts {
        spoke_state: ctx.accounts.spoke_state.as_ref().clone(),
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

    let program_id = *ctx.program_id;

    let fee_data = FeeData {
        token_fee: fee_param.token_fee,
        native_fee: fee_param.native_fee,
        input_asset: ctx.accounts.mint.key(),
        deadline: fee_param.deadline,
    };
    let fee_accounts = HandleFeeAccounts {
        signature_accounts: SignatureAccounts {
            signer: ctx.accounts.fee_signer.to_account_info(),
            instruction_sysvar: ctx.accounts.instruction_sysvar.to_account_info(),
        },
        user_account: ctx.accounts.authority.to_account_info(),
        user_token_account: ctx.accounts.user_token_account.to_account_info(),
        user_authority_account: ctx.accounts.authority.to_account_info(),
        fee_reciever_account: ctx.accounts.fee_recipient.to_account_info(),
        fee_reciever_token_account: ctx.accounts.fee_recipient_token_account.to_account_info(),
        token_program: ctx.accounts.token_program.to_account_info(),
        system_program: ctx.accounts.system_program.to_account_info(),
    };

    handle_fees(fee_data, fee_param.signature, fee_accounts)?;

    let mut intent_ids: Vec<[u8; 32]> = Vec::with_capacity(params.len());
    for p in &params {
        let event_data = handle_new_intent(
            &mut accounts,
            program_id,
            p.receiver,
            p.output_asset,
            p.amount,
            p.amount_out_min,
            p.ttl,
            p.destinations.clone(),
            p.data.clone(),
            p.message_gas_limit,
        )?;

        emit_cpi!(event_data);

        intent_ids.push(event_data.intent_id);
    }

    let order_id = hash_intent_id_array(&intent_ids);

    emit_cpi!(OrderCreated {
        order_id,
        user: ctx.accounts.authority.key(),
        intent_ids: intent_ids.clone(),
        fee: fee_param.token_fee,
        native_value: fee_param.native_fee,
    });

    Ok(())
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct OrderParameters {
    pub destinations: Vec<u32>,
    pub receiver: Pubkey,
    pub output_asset: Pubkey,
    pub amount: u64,
    pub amount_out_min: u128,
    pub max_fee: u32,
    pub ttl: u64,
    pub data: Vec<u8>,
    pub message_gas_limit: u64,
}
