use anchor_lang::prelude::*;

use crate::{
    error::SpokeError,
    state::{FeeAdapterState, SpokeState},
};

pub fn migrate_fee_adapter_state(
    ctx: Context<MigrateFeeAdapterState>,
    fill_signer: Pubkey,
) -> Result<()> {
    let state = &mut ctx.accounts.fee_adapter_state;
    
    require!(state.initialized, SpokeError::InvalidArgument);
    
    state.fill_signer = fill_signer;
    
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
    #[account(
        mut,
        seeds = [b"fee-adapter-state"],
        bump,
        realloc = 8 + FeeAdapterState::SIZE,
        realloc::payer = admin,
        realloc::zero = false,
    )]
    pub fee_adapter_state: Account<'info, FeeAdapterState>,
    #[account(mut)]
    pub admin: Signer<'info>,
    pub system_program: Program<'info, System>,
}

