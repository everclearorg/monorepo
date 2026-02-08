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

#[event]
#[derive(Clone)]
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

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct BatchFeeData {
    pub native_fee: u64,
    pub params_hash: [u8; 32],
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
    pub fee_receiver_account: AccountInfo<'info>,
    pub fee_receiver_token_account: AccountInfo<'info>,
    pub token_program: AccountInfo<'info>,
    pub system_program: AccountInfo<'info>,
}

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
        let cpi_accounts = token::Transfer {
            from: accounts.user_token_account,
            to: accounts.fee_receiver_token_account,
            authority: accounts.user_authority_account,
        };
        let cpi_ctx = CpiContext::new(accounts.token_program, cpi_accounts);
        token::transfer(cpi_ctx, fee.token_fee)?;
    }

    if fee.native_fee > 0 {
        let transfer_accounts = system_program::Transfer {
            from: accounts.user_account,
            to: accounts.fee_receiver_account,
        };
        system_program::transfer(
            CpiContext::new(accounts.system_program, transfer_accounts),
            fee.native_fee,
        )?;
    }

    Ok(())
}

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
        let cpi_accounts = token::Transfer {
            from: accounts.user_token_account,
            to: accounts.fee_receiver_token_account,
            authority: accounts.user_authority_account,
        };
        let cpi_ctx = CpiContext::new(accounts.token_program, cpi_accounts);
        token::transfer(cpi_ctx, fee.token_fee)?;
    }

    if fee.native_fee > 0 {
        let transfer_accounts = system_program::Transfer {
            from: accounts.user_account,
            to: accounts.fee_receiver_account,
        };
        system_program::transfer(
            CpiContext::new(accounts.system_program, transfer_accounts),
            fee.native_fee,
        )?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use anchor_lang::solana_program::account_info::AccountInfo;
    use anchor_lang::solana_program::pubkey::Pubkey;
    use anchor_lang::solana_program::system_program;

    fn create_mock_account_info_with_key(key: Pubkey) -> AccountInfo<'static> {
        let key = Box::leak(Box::new(key));
        let lamports = Box::leak(Box::new(0u64));
        let data = Box::leak(Box::new(Vec::<u8>::new()));
        AccountInfo::new(key, false, false, lamports, data, &system_program::ID, false, 0)
    }

    #[test]
    fn test_handle_fee_accounts_struct_creation_with_corrected_field_names() {
        let fee_receiver_key = Pubkey::new_unique();
        let fee_receiver_token_key = Pubkey::new_unique();
        let signature_accounts = SignatureAccounts {
            signer: create_mock_account_info_with_key(Pubkey::new_unique()),
            instruction_sysvar: create_mock_account_info_with_key(Pubkey::new_unique()),
        };
        let accounts = HandleFeeAccounts {
            signature_accounts,
            user_account: create_mock_account_info_with_key(Pubkey::new_unique()),
            user_token_account: create_mock_account_info_with_key(Pubkey::new_unique()),
            user_authority_account: create_mock_account_info_with_key(Pubkey::new_unique()),
            fee_receiver_account: create_mock_account_info_with_key(fee_receiver_key),
            fee_receiver_token_account: create_mock_account_info_with_key(fee_receiver_token_key),
            token_program: create_mock_account_info_with_key(Pubkey::new_unique()),
            system_program: create_mock_account_info_with_key(Pubkey::new_unique()),
        };
        assert_eq!(accounts.fee_receiver_account.key(), fee_receiver_key);
        assert_eq!(accounts.fee_receiver_token_account.key(), fee_receiver_token_key);
    }
}
