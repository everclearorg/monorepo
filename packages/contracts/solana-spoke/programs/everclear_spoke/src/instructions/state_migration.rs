//! Migration for SpokeState: realloc account to add CCIP fields (post-rebase with solana-swap).
//! Run once per deployment after upgrading the program. Safe to run only on accounts that
//! still have the old layout (pre-CCIP fields).

use anchor_lang::prelude::*;

use crate::{error::SpokeError, state::SpokeState};

/// Old SpokeState size (before CCIP fields). Must match pre-CCIP layout.
const OLD_SPOKE_STATE_SIZE: usize = 230;
/// New fields appended: Option::None (1) x4 + MessagingProviderType::Hyperlane (1) + [0u8;32] (32) = 37
const NEW_FIELDS_LEN: usize = 37;

pub fn migrate_spoke_state(ctx: Context<MigrateSpokeState>) -> Result<()> {
    let spoke_state_info = &ctx.accounts.spoke_state;

    let (expected_pda, _) = Pubkey::find_program_address(&[b"spoke-state"], ctx.program_id);
    require!(
        spoke_state_info.key() == expected_pda,
        SpokeError::InvalidArgument
    );

    let account_data = spoke_state_info.data.borrow();
    let current_size = account_data.len();
    let expected_old_size = 8 + OLD_SPOKE_STATE_SIZE;
    require!(
        current_size == expected_old_size,
        SpokeError::InvalidArgument
    );

    // Owner is at offset 8 + 1 + 1 + 4 + 4 + 32 + 32 + 8 + 8 = 98 (see SpokeState field order)
    const OWNER_OFFSET: usize = 8 + 1 + 1 + 4 + 4 + 32 + 32 + 8 + 8;
    let owner_bytes: [u8; 32] = account_data[OWNER_OFFSET..OWNER_OFFSET + 32]
        .try_into()
        .map_err(|_| error!(SpokeError::InvalidArgument))?;
    let owner = Pubkey::new_from_array(owner_bytes);
    require!(
        ctx.accounts.admin.key() == owner,
        SpokeError::OnlyOwner
    );

    drop(account_data);

    let new_size = 8 + SpokeState::SIZE;
    let rent = Rent::get()?;
    let new_minimum_balance = rent.minimum_balance(new_size);
    let current_balance = spoke_state_info.lamports();

    if new_minimum_balance > current_balance {
        let additional_lamports = new_minimum_balance
            .checked_sub(current_balance)
            .ok_or(SpokeError::InvalidArgument)?;
        anchor_lang::solana_program::program::invoke(
            &anchor_lang::solana_program::system_instruction::transfer(
                &ctx.accounts.admin.key(),
                &spoke_state_info.key(),
                additional_lamports,
            ),
            &[
                ctx.accounts.admin.to_account_info(),
                spoke_state_info.to_account_info(),
                ctx.accounts.system_program.to_account_info(),
            ],
        )?;
    }

    spoke_state_info.realloc(new_size, false)?;

    let mut data_mut = spoke_state_info.data.borrow_mut();
    // Append new fields: 4x Option::None (1 byte each) + MessagingProviderType::Hyperlane (0) + [0u8;32]
    let start = expected_old_size;
    data_mut[start] = 0; // ccip_router: None
    data_mut[start + 1] = 0; // ccip_offramp: None
    data_mut[start + 2] = 0; // ccip_chain_selector: None
    data_mut[start + 3] = 0; // everclear_ccip_chain_selector: None
    data_mut[start + 4] = 0; // messaging_provider: Hyperlane
    data_mut[start + 5..start + NEW_FIELDS_LEN].fill(0); // everclear_gateway [0u8;32]

    Ok(())
}

#[derive(Accounts)]
pub struct MigrateSpokeState<'info> {
    /// CHECK: SpokeState PDA; we validate size and owner manually before realloc
    #[account(mut)]
    pub spoke_state: UncheckedAccount<'info>,
    #[account(mut)]
    pub admin: Signer<'info>,
    pub system_program: Program<'info, System>,
}
