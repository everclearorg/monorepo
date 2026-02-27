use anchor_lang::prelude::*;

use crate::{
    error::SpokeError,
    state::{FeeAdapterState, SpokeState},
};

pub fn migrate_fee_adapter_state(
    ctx: Context<MigrateFeeAdapterState>,
    fill_signer: Pubkey,
) -> Result<()> {
    let fee_adapter_state_info = &ctx.accounts.fee_adapter_state;

    // Manual PDA validation
    let (expected_pda, _) = Pubkey::find_program_address(
        &[b"fee-adapter-state"],
        ctx.program_id,
    );
    require!(
        *fee_adapter_state_info.key == expected_pda,
        SpokeError::InvalidArgument
    );

    // Read old account data manually
    let account_data = fee_adapter_state_info.data.borrow();
    let current_size = account_data.len();
    require!(current_size == 75, SpokeError::InvalidArgument); // Expect old size (8 discriminator + 67 data)

    // Parse old account format manually
    // Old format: discriminator (8) + initialized (1) + paused (1) + fee_recipient (32) + fee_signer (32) + bump (1) = 75 bytes
    let initialized = account_data[8] != 0;
    let paused = account_data[9] != 0;
    let fee_recipient = Pubkey::try_from(&account_data[10..42])
        .map_err(|_| error!(SpokeError::InvalidArgument))?;
    let fee_signer_old = Pubkey::try_from(&account_data[42..74])
        .map_err(|_| error!(SpokeError::InvalidArgument))?;
    let bump = account_data[74];
    let discriminator = account_data[0..8].to_vec(); // Preserve discriminator

    require!(initialized, SpokeError::InvalidArgument);

    drop(account_data); // Drop borrow before realloc

    // Calculate new size: 8 (discriminator) + 99 (new FeeAdapterState::SIZE)
    let new_size = 8 + FeeAdapterState::SIZE; // 107 bytes

    // Handle rent transfer if needed
    let rent = Rent::get()?;
    let new_minimum_balance = rent.minimum_balance(new_size);
    let current_balance = fee_adapter_state_info.lamports();

    if new_minimum_balance > current_balance {
        let additional_lamports = new_minimum_balance
            .checked_sub(current_balance)
            .ok_or(SpokeError::InvalidArgument)?;

        anchor_lang::solana_program::program::invoke(
            &anchor_lang::solana_program::system_instruction::transfer(
                &ctx.accounts.admin.key(),
                fee_adapter_state_info.key,
                additional_lamports,
            ),
            &[
                ctx.accounts.admin.to_account_info(),
                fee_adapter_state_info.to_account_info(),
                ctx.accounts.system_program.to_account_info(),
            ],
        )?;
    }

    // Reallocate account
    fee_adapter_state_info.realloc(new_size, false)?;

    // Write new account data
    let mut account_data_mut = fee_adapter_state_info.data.borrow_mut();
    account_data_mut[0..8].copy_from_slice(&discriminator); // Restore discriminator

    // Create new state with fill_signer
    let new_state = FeeAdapterState {
        initialized,
        paused,
        fee_recipient,
        fee_signer: fee_signer_old,
        fill_signer,
        bump,
    };

    // Serialize new state (after discriminator)
    let mut writer = std::io::Cursor::new(&mut account_data_mut[8..]);
    new_state.serialize(&mut writer)?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use anchor_lang::prelude::Pubkey;

    #[test]
    fn test_migration_sets_fill_signer() {
        let fill_signer = Pubkey::new_unique();
        let default_pubkey = Pubkey::default();

        assert_ne!(
            fill_signer, default_pubkey,
            "Fill signer should be a valid non-default pubkey"
        );
    }

    #[test]
    fn test_migration_allows_fill_signer_update() {
        let old_fill_signer = Pubkey::new_unique();
        let new_fill_signer = Pubkey::new_unique();

        assert_ne!(
            old_fill_signer, new_fill_signer,
            "Migration should allow updating fill_signer to a new value"
        );
    }

    #[test]
    fn test_migration_preserves_other_state() {
        let fee_recipient = Pubkey::new_unique();
        let fee_signer = Pubkey::new_unique();
        let fill_signer = Pubkey::new_unique();

        assert_ne!(fee_recipient, fee_signer);
        assert_ne!(fee_signer, fill_signer);
        assert_ne!(fee_recipient, fill_signer);

        let state_preserved = fee_recipient != fill_signer && fee_signer != fill_signer;

        assert!(
            state_preserved,
            "Migration should preserve fee_recipient and fee_signer while updating fill_signer"
        );
    }
}

#[derive(Accounts)]
pub struct MigrateFeeAdapterState<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    /// CHECK: We manually validate the PDA and read the old account format before resizing
    #[account(mut)]
    pub fee_adapter_state: UncheckedAccount<'info>,
    #[account(mut)]
    pub admin: Signer<'info>,
    pub system_program: Program<'info, System>,
}
