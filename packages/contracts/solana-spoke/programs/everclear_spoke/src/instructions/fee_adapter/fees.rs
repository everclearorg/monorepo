use anchor_lang::{prelude::*, system_program};
use anchor_spl::token;

use crate::error::SpokeError;

use super::signature::{verify_signature, FEE_DATA_TYPE_HASH_PREFIX, BATCH_FEE_DATA_TYPE_HASH_PREFIX};

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct FeeParams {
    pub token_fee: u64,
    pub native_fee: u64,
    pub deadline: u64,
    pub signature: Vec<u8>,
}

// HACK: Mark as event for serde derivation and expose it in idl types
// note this is not really an event.
#[event]
pub struct FeeData {
    pub destinations: Vec<u32>,
    pub input_asset: Pubkey,
    pub output_asset: Pubkey,
    pub amount: u64,
    pub amount_out_min: u128,
    pub ttl: u64,
    pub data: Vec<u8>,
    pub token_fee: u64,
    pub native_fee: u64,
    pub deadline: u64,
}
// For batch orders - only what's needed for signature
#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct BatchFeeData {
    pub native_fee: u64,
    pub params_hash: [u8; 32],  // Hash of the params array
    pub token_fee: u64,
    pub deadline: u64,
}

pub struct SignatureAccounts<'info> {
    pub signer: AccountInfo<'info>,
    pub instruction_sysvar: AccountInfo<'info>,
}

pub struct HandleFeeAccounts<'info> {
    pub signature_accounts: SignatureAccounts<'info>,
    pub user_account: AccountInfo<'info>,
    pub user_token_account: AccountInfo<'info>,
    pub user_authority_account: AccountInfo<'info>,
    pub fee_reciever_account: AccountInfo<'info>,
    pub fee_reciever_token_account: AccountInfo<'info>,
    pub token_program: AccountInfo<'info>,
    pub system_program: AccountInfo<'info>,
}

/// NOTE: the account is expected to be validated before the function invoke
pub fn handle_fees(
    fee: FeeData,
    signature: Vec<u8>,
    accounts: HandleFeeAccounts,
    program_id: &Pubkey,
) -> Result<()> {
    verify_signature(
        &fee,
        signature,
        accounts.signature_accounts,
        program_id,
        FEE_DATA_TYPE_HASH_PREFIX,
    )?;

    let clock = Clock::get()?;
    let current_timestamp = clock.unix_timestamp;
    if current_timestamp > fee.deadline.try_into()? {
        return err!(SpokeError::InvalidDeadline);
    }

    if fee.token_fee > 0 {
        // Transfer from user's token account -> fee reciever's vault
        let cpi_accounts = token::Transfer {
            from: accounts.user_token_account,
            to: accounts.fee_reciever_token_account,
            authority: accounts.user_authority_account,
        };
        let cpi_ctx = CpiContext::new(accounts.token_program, cpi_accounts);
        token::transfer(cpi_ctx, fee.token_fee)?;
    }

    if fee.native_fee > 0 {
        // send sol
        let transfer_accounts = system_program::Transfer {
            from: accounts.user_account,
            to: accounts.fee_reciever_account,
        };
        system_program::transfer(
            CpiContext::new(accounts.system_program, transfer_accounts),
            fee.native_fee,
        )?;
    }

    Ok(())
}


/// NOTE: the account is expected to be validated before the function invoke
pub fn handle_batch_fees(
    fee: BatchFeeData,
    signature: Vec<u8>,
    accounts: HandleFeeAccounts,
    program_id: &Pubkey,
) -> Result<()> {

    verify_signature(
        &fee,
        signature,
        accounts.signature_accounts,
        program_id,
        BATCH_FEE_DATA_TYPE_HASH_PREFIX,
    )?;

    let clock = Clock::get()?;
    let current_timestamp = clock.unix_timestamp;
    if current_timestamp > fee.deadline.try_into()? {
        return err!(SpokeError::InvalidDeadline);
    }

    if fee.token_fee > 0 {
        // Transfer from user's token account -> fee reciever's vault
        let cpi_accounts = token::Transfer {
            from: accounts.user_token_account,
            to: accounts.fee_reciever_token_account,
            authority: accounts.user_authority_account,
        };
        let cpi_ctx = CpiContext::new(accounts.token_program, cpi_accounts);
        token::transfer(cpi_ctx, fee.token_fee)?;
    }

    if fee.native_fee > 0 {
        // send sol
        let transfer_accounts = system_program::Transfer {
            from: accounts.user_account,
            to: accounts.fee_reciever_account,
        };
        system_program::transfer(
            CpiContext::new(accounts.system_program, transfer_accounts),
            fee.native_fee,
        )?;
    }

    Ok(())
}
