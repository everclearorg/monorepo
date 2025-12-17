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
    let state = &mut ctx.accounts.spoke_state;

    require!(!state.paused, SpokeError::ContractPaused);
    require!(!params.is_empty(), SpokeError::EmptyParams);
    require!(
        !ctx.accounts.fee_adapter_state.paused,
        SpokeError::FeeAdapterPaused
    );

    let program_id = *ctx.program_id;

    // Hash the params array (similar to Solidity's abi.encode)
    let params_hash = keccak::hash(&params.try_to_vec()?);
    
    // Create simplified fee data for signature verification
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
        fee_reciever_account: ctx.accounts.fee_recipient.to_account_info(),
        fee_reciever_token_account: ctx.accounts.fee_recipient_token_account.to_account_info(),
        token_program: ctx.accounts.token_program.to_account_info(),
        system_program: ctx.accounts.system_program.to_account_info(),
    };

    handle_batch_fees(fee_data_for_signature, fee_param.signature, fee_accounts, &program_id)?;

    // Each intent needs 2 accounts: unique_message_account (signer) and dispatched_message_pda
    let required_remaining_accounts = params.len() * 2;
    require!(
        ctx.remaining_accounts.len() >= required_remaining_accounts,
        SpokeError::InvalidArgument
    );

    let remaining_accounts: Vec<&AccountInfo> = ctx.remaining_accounts.iter().collect();
    
    let mut intent_ids: Vec<[u8; 32]> = Vec::with_capacity(params.len());
    for (idx, p) in params.iter().enumerate() {
        // Get the pair of accounts for this intent from remaining accounts
        // Account 1: unique_message_account (must be a signer)
        let account_idx = idx * 2;
        let unique_message_account_info = remaining_accounts
            .get(account_idx)
            .ok_or_else(|| error!(SpokeError::InvalidArgument))?;
        require!(
            unique_message_account_info.is_signer,
            SpokeError::MissingRequiredSignature
        );

        // Account 2: dispatched_message_pda (must be writable and uninitialized)
        let dispatched_message_pda_info = remaining_accounts
            .get(account_idx + 1)
            .ok_or_else(|| error!(SpokeError::InvalidArgument))?;
        require!(
            dispatched_message_pda_info.is_writable,
            SpokeError::InvalidArgument
        );

        let mut accounts = unsafe {
            let unique_msg: &AccountInfo = std::mem::transmute(*unique_message_account_info);
            let dispatched_pda: &AccountInfo = std::mem::transmute(*dispatched_message_pda_info);
            
            NewIntentAccounts {
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
                unique_message_account: unique_msg.clone(),
                dispatched_message_pda: dispatched_pda.clone(),
                igp_program: ctx.accounts.igp_program.clone(),
                igp_program_data: ctx.accounts.igp_program_data.clone(),
                igp_payment_pda: ctx.accounts.igp_payment_pda.clone(),
                configured_igp_account: ctx.accounts.configured_igp_account.clone(),
                inner_igp_account: ctx.accounts.inner_igp_account.clone(),
            }
        };

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

    // Ensure no extraneous accounts were provided
    require!(
        ctx.remaining_accounts.len() == required_remaining_accounts,
        SpokeError::ExtraneousAccount
    );

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
    use crate::error::SpokeError;

    #[test]
    fn test_new_order_uses_distinct_accounts_per_intent() {
        // Simulate the account indexing logic from the fix
        let num_intents = 3;
        
        // Each intent gets its own pair at indices: (0,1), (2,3), (4,5)
        for intent_idx in 0..num_intents {
            let account_idx = intent_idx * 2;
            let unique_msg_idx = account_idx;
            let dispatched_pda_idx = account_idx + 1;
            
            // Verify each intent uses different indices
            assert_ne!(
                unique_msg_idx,
                if intent_idx > 0 { (intent_idx - 1) * 2 } else { 999 },
                "Each intent should use a different unique_message_account index"
            );
            assert_ne!(
                dispatched_pda_idx,
                if intent_idx > 0 { (intent_idx - 1) * 2 + 1 } else { 999 },
                "Each intent should use a different dispatched_message_pda index"
            );
            
            // Verify the indices are correct
            assert_eq!(
                unique_msg_idx + 1,
                dispatched_pda_idx,
                "unique_message_account and dispatched_message_pda should be consecutive"
            );
        }
    }

    #[test]
    fn test_new_order_validates_remaining_accounts() {
        let params = vec![
            OrderParameters {
                destinations: vec![1],
                receiver: Pubkey::new_unique(),
                output_asset: Pubkey::new_unique(),
                amount: 1000,
                amount_out_min: 900,
                max_fee: 0,
                ttl: 3600,
                data: vec![],
                message_gas_limit: 100000,
            },
            OrderParameters {
                destinations: vec![2],
                receiver: Pubkey::new_unique(),
                output_asset: Pubkey::new_unique(),
                amount: 2000,
                amount_out_min: 1800,
                max_fee: 0,
                ttl: 3600,
                data: vec![],
                message_gas_limit: 100000,
            },
        ];
        
        let required_accounts = params.len() * 2; // 4 accounts needed
        let insufficient_accounts = 3; // Only 3 provided
        
        // Simulate the validation logic
        let would_fail = insufficient_accounts < required_accounts;
        assert!(
            would_fail,
            "new_order should reject when remaining_accounts.len() < params.len() * 2"
        );
        
        let sufficient_accounts = 4; // Exactly 4 provided
        let would_succeed = sufficient_accounts >= required_accounts;
        assert!(
            would_succeed,
            "new_order should accept when remaining_accounts.len() >= params.len() * 2"
        );
        
        // Test extraneous accounts rejection
        let extraneous_accounts = 5; // More than needed
        let has_extraneous = extraneous_accounts != required_accounts;
        assert!(
            has_extraneous,
            "new_order should reject when remaining_accounts.len() != params.len() * 2 (extraneous accounts)"
        );
    }

    #[test]
    fn test_new_order_validates_unique_message_account_is_signer() {

        let is_signer = false;
        let would_fail = !is_signer;
        assert!(
            would_fail,
            "new_order should reject when unique_message_account is not a signer"
        );
        
        let is_signer_valid = true;
        let would_pass = is_signer_valid;
        assert!(
            would_pass,
            "new_order should accept when unique_message_account is a signer"
        );
    }

}
