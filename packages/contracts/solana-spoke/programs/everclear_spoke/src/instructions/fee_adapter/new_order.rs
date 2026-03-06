use anchor_lang::prelude::*;
use anchor_lang::solana_program::keccak;

use crate::error::SpokeError;
use crate::events::OrderCreated;
use crate::instructions::fee_adapter::{
    handle_batch_fees, BatchFeeData, FeeParams, HandleFeeAccounts, SignatureAccounts,
};
use crate::instructions::{handle_new_intent, NewIntent, NewIntentAccounts};
use crate::utils::hash_intent_id_array;

/// Batch-create multiple intents and handle fees.
pub fn new_order(
    ctx: Context<NewIntent>,
    params: Vec<OrderParameters>,
    fee_param: FeeParams,
) -> Result<()> {
    require!(!params.is_empty(), SpokeError::EmptyParams);
    require!(
        !ctx.accounts.fee_adapter_state.paused,
        SpokeError::FeeAdapterPaused
    );

    let program_id = *ctx.program_id;

    let params_hash = keccak::hash(&params.try_to_vec()?);

    let fee_data_for_signature = BatchFeeData {
        native_fee: fee_param.native_fee,
        params_hash: params_hash.to_bytes(),
        token_fee: fee_param.token_fee,
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
        fee_receiver_account: ctx.accounts.fee_recipient.to_account_info(),
        fee_receiver_token_account: ctx.accounts.fee_recipient_token_account.to_account_info(),
        token_program: ctx.accounts.token_program.to_account_info(),
        system_program: ctx.accounts.system_program.to_account_info(),
    };

    handle_batch_fees(fee_data_for_signature, fee_param.signature, fee_accounts, &program_id)?;

    // Slice passed to handle_new_intent: messaging (CCIP/Hyperlane) accounts only.
    // remaining_accounts layout: [ unique_1, dispatched_1, ..., unique_{n-1}, dispatched_{n-1}, (CCIP accounts when CCIP) ].
    // So the first 2*(n-1) are consumed per intent; the rest are passed to handle_new_intent.
    let num_extra_intents = params.len().saturating_sub(1);
    let messaging_start = num_extra_intents * 2;
    let remaining_accounts_slice: &[anchor_lang::prelude::AccountInfo] =
        &ctx.remaining_accounts[messaging_start..];

    let mut remaining_accounts_iter = ctx.remaining_accounts.iter();
    let mut intent_ids: Vec<[u8; 32]> = Vec::with_capacity(params.len());

    for (idx, p) in params.iter().enumerate() {
        let (unique_message_account, dispatched_message_pda) = if idx == 0 {
            (
                ctx.accounts.unique_message_account.to_account_info(),
                ctx.accounts.dispatched_message_pda.clone(),
            )
        } else {
            let unique_msg_info = remaining_accounts_iter
                .next()
                .ok_or(SpokeError::InvalidArgument)?;
            let dispatched_pda_info = remaining_accounts_iter
                .next()
                .ok_or(SpokeError::InvalidArgument)?;

            require!(
                unique_msg_info.is_signer,
                SpokeError::InvalidArgument
            );

            unsafe {
                (
                    std::mem::transmute::<AccountInfo, AccountInfo>(unique_msg_info.clone()),
                    std::mem::transmute::<AccountInfo, AccountInfo>(dispatched_pda_info.clone()),
                )
            }
        };

        // Box to stay under BPF stack limit (4KB)
        let mut accounts = Box::new(NewIntentAccounts {
            spoke_state: ctx.accounts.spoke_state.as_ref().clone(),
            mint: ctx.accounts.mint.clone(),
            token_program: ctx.accounts.token_program.clone(),
            program_vault_account: ctx.accounts.program_vault_account.clone(),
            user_token_account: ctx.accounts.user_token_account.clone(),
            authority: ctx.accounts.authority.clone(),
            system_program: ctx.accounts.system_program.clone(),
            spl_noop_program: ctx.accounts.spl_noop_program.clone(),
            hyperlane_mailbox: ctx.accounts.hyperlane_mailbox.to_account_info(),
            mailbox_outbox: ctx.accounts.mailbox_outbox.clone(),
            dispatch_authority: ctx.accounts.dispatch_authority.clone(),
            unique_message_account,
            dispatched_message_pda,
            igp_program: ctx.accounts.igp_program.to_account_info(),
            igp_program_data: ctx.accounts.igp_program_data.clone(),
            igp_payment_pda: ctx.accounts.igp_payment_pda.clone(),
            configured_igp_account: ctx.accounts.configured_igp_account.clone(),
            inner_igp_account: ctx.accounts.inner_igp_account.clone(),
        });

        let event_data = handle_new_intent(
            &mut *accounts,
            program_id,
            p.receiver,
            p.output_asset,
            p.amount,
            p.amount_out_min,
            p.ttl,
            p.destinations.clone(),
            p.data.clone(),
            p.message_gas_limit,
            remaining_accounts_slice,
        )?;

        emit_cpi!(event_data);

        intent_ids.push(event_data.intent_id);
    }

    // For Hyperlane, remaining_accounts has exactly 2*(n-1) (unique, dispatched) pairs.
    // For CCIP, remaining_accounts has 2*(n-1) pairs plus CCIP router/accounts; those extras
    // are passed via remaining_accounts_slice to handle_new_intent. Do not require iterator
    // exhausted so both flows are supported.

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_batch_requires_remaining_accounts() {
        let params = vec![
            OrderParameters {
                destinations: vec![1],
                receiver: Pubkey::new_unique(),
                output_asset: Pubkey::new_unique(),
                amount: 1000,
                amount_out_min: 900,
                max_fee: 100,
                ttl: 3600,
                data: vec![],
                message_gas_limit: 10000,
            },
            OrderParameters {
                destinations: vec![1],
                receiver: Pubkey::new_unique(),
                output_asset: Pubkey::new_unique(),
                amount: 2000,
                amount_out_min: 1800,
                max_fee: 100,
                ttl: 3600,
                data: vec![],
                message_gas_limit: 10000,
            },
        ];

        assert_eq!(params.len(), 2);
        let required_remaining_accounts = (params.len() - 1) * 2;
        assert_eq!(required_remaining_accounts, 2);
    }

    #[test]
    fn test_single_intent_no_remaining_accounts() {
        let params = vec![OrderParameters {
            destinations: vec![1],
            receiver: Pubkey::new_unique(),
            output_asset: Pubkey::new_unique(),
            amount: 1000,
            amount_out_min: 900,
            max_fee: 100,
            ttl: 3600,
            data: vec![],
            message_gas_limit: 10000,
        }];

        assert_eq!(params.len(), 1);
        let required_remaining_accounts = (params.len() - 1) * 2;
        assert_eq!(required_remaining_accounts, 0);
    }

    #[test]
    fn test_multiple_intents_require_correct_account_count() {
        for num_intents in 2..=5 {
            let params: Vec<OrderParameters> = (0..num_intents)
                .map(|_| OrderParameters {
                    destinations: vec![1],
                    receiver: Pubkey::new_unique(),
                    output_asset: Pubkey::new_unique(),
                    amount: 1000,
                    amount_out_min: 900,
                    max_fee: 100,
                    ttl: 3600,
                    data: vec![],
                    message_gas_limit: 10000,
                })
                .collect();

            let required_remaining_accounts = (params.len() - 1) * 2;
            assert_eq!(required_remaining_accounts, (num_intents - 1) * 2);
        }
    }

    #[test]
    fn test_order_parameters_serialization() {
        let params = OrderParameters {
            destinations: vec![1, 2, 3],
            receiver: Pubkey::new_unique(),
            output_asset: Pubkey::new_unique(),
            amount: 1000,
            amount_out_min: 900,
            max_fee: 100,
            ttl: 3600,
            data: vec![1, 2, 3, 4, 5],
            message_gas_limit: 10000,
        };

        let mut encoded = vec![];
        params.serialize(&mut encoded).unwrap();
        assert!(!encoded.is_empty());

        let decoded: OrderParameters = OrderParameters::deserialize(&mut &encoded[..]).unwrap();
        assert_eq!(decoded.destinations, params.destinations);
        assert_eq!(decoded.receiver, params.receiver);
        assert_eq!(decoded.output_asset, params.output_asset);
        assert_eq!(decoded.amount, params.amount);
        assert_eq!(decoded.amount_out_min, params.amount_out_min);
        assert_eq!(decoded.max_fee, params.max_fee);
        assert_eq!(decoded.ttl, params.ttl);
        assert_eq!(decoded.data, params.data);
        assert_eq!(decoded.message_gas_limit, params.message_gas_limit);
    }
}
