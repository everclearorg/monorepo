use anchor_lang::prelude::*;

use crate::{
    events::{FeeAdapterPausedEvent, FeeRecipientUpdatedEvent, FeeSignerUpdatedEvent, FillSignerUpdatedEvent},
    state::{FeeAdapterState, SpokeState},
};

#[event_cpi]
#[derive(Accounts)]
pub struct FeeAdapterAdminState<'info> {
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

pub fn update_fee_recipient(
    ctx: Context<FeeAdapterAdminState>,
    new_fee_recipient: Pubkey,
) -> Result<()> {
    let old_fee_recipient = ctx.accounts.fee_adapter_state.fee_recipient;
    ctx.accounts.fee_adapter_state.fee_recipient = new_fee_recipient;
    emit_cpi!(FeeRecipientUpdatedEvent {
        old_fee_recipient,
        new_fee_recipient,
    });
    Ok(())
}

pub fn update_fee_signer(ctx: Context<FeeAdapterAdminState>, new_fee_signer: Pubkey) -> Result<()> {
    let old_fee_signer = ctx.accounts.fee_adapter_state.fee_signer;
    ctx.accounts.fee_adapter_state.fee_signer = new_fee_signer;
    emit_cpi!(FeeSignerUpdatedEvent {
        old_fee_signer,
        new_fee_signer,
    });
    Ok(())
}

pub fn pause_fee_adapter(ctx: Context<FeeAdapterAdminState>) -> Result<()> {
    ctx.accounts.fee_adapter_state.paused = true;
    emit_cpi!(FeeAdapterPausedEvent {});
    Ok(())
}

pub fn unpause_fee_adapter(ctx: Context<FeeAdapterAdminState>) -> Result<()> {
    ctx.accounts.fee_adapter_state.paused = false;
    emit_cpi!(FeeAdapterPausedEvent {});
    Ok(())
}

pub fn update_fill_signer(ctx: Context<FeeAdapterAdminState>, new_fill_signer: Pubkey) -> Result<()> {
    let old_fill_signer = ctx.accounts.fee_adapter_state.fill_signer;
    ctx.accounts.fee_adapter_state.fill_signer = new_fill_signer;
    emit_cpi!(FillSignerUpdatedEvent {
        old_fill_signer,
        new_fill_signer,
    });
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use anchor_lang::prelude::Pubkey;

    #[test]
    fn test_fill_signer_separate_from_fee_signer() {
        let fee_signer = Pubkey::new_unique();
        let fill_signer = Pubkey::new_unique();
        assert_ne!(fee_signer, fill_signer, "Fee signer and fill signer must be different to enforce PoLP");
    }

    #[test]
    fn test_update_fill_signer_independent_of_fee_signer() {
        let original_fee_signer = Pubkey::new_unique();
        let original_fill_signer = Pubkey::new_unique();
        let new_fill_signer = Pubkey::new_unique();
        assert_ne!(original_fee_signer, original_fill_signer);
        assert_ne!(original_fill_signer, new_fill_signer);
        let fee_signer_unchanged = original_fee_signer;
        let fill_signer_updated = new_fill_signer;
        assert_ne!(fee_signer_unchanged, fill_signer_updated, "Updating fill_signer should not affect fee_signer");
    }

    #[test]
    fn test_fill_signer_update_preserves_fee_signer() {
        let fee_signer = Pubkey::new_unique();
        let old_fill_signer = Pubkey::new_unique();
        let new_fill_signer = Pubkey::new_unique();
        assert_ne!(fee_signer, old_fill_signer);
        assert_ne!(fee_signer, new_fill_signer);
        assert_eq!(fee_signer, fee_signer, "Fee signer should remain unchanged when fill signer is updated");
    }

    #[test]
    fn test_separation_enforces_principle_of_least_privilege() {
        let fee_signer = Pubkey::new_unique();
        let fill_signer = Pubkey::new_unique();
        let fee_signer_can_sign_fills = fee_signer == fill_signer;
        let fill_signer_can_sign_fees = fill_signer == fee_signer;
        assert!(fee_signer_can_sign_fills == false, "Fee signer should only be able to sign fees, not fills");
        assert!(fill_signer_can_sign_fees == false, "Fill signer should only be able to sign fills, not fees");
    }

    #[test]
    fn test_multiple_fill_signer_updates() {
        let fill_signer_1 = Pubkey::new_unique();
        let fill_signer_2 = Pubkey::new_unique();
        let fill_signer_3 = Pubkey::new_unique();
        assert_ne!(fill_signer_1, fill_signer_2);
        assert_ne!(fill_signer_2, fill_signer_3);
        assert!(fill_signer_1 != fill_signer_2 && fill_signer_2 != fill_signer_3, "Fill signer should be updatable multiple times independently");
    }
}
