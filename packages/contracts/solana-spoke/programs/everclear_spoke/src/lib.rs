use anchor_lang::prelude::*;

pub mod consts;
pub mod error;
pub mod events;
pub mod hyperlane;
pub mod instructions;
pub mod state;

use error::SpokeError;
use events::*;
use hyperlane::mailbox::HandleInstruction;
use hyperlane::InterchainGasPaymasterType;
use instructions::*;
use state::SpokeState;

declare_id!("uvXqfnsfugQTAbd8Wy7xUBQDhcREMGZZeCUb1Y3fXLC");

#[program]
pub mod everclear_spoke {
    use super::*;

    /// Initialize the global state.
    /// This function creates the SpokeState (global config) PDA.
    #[access_control(ctx.accounts.ensure_owner_is_valid(&init.owner))]
    pub fn initialize(ctx: Context<Initialize>, init: SpokeInitializationParams) -> Result<()> {
        instructions::initialize(ctx, init)
    }

    /// Pause the program.
    /// Only the lighthouse or watchtower can call this.
    pub fn pause(ctx: Context<AdminState>) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.lighthouse == ctx.accounts.admin.key()
                || state.watchtower == ctx.accounts.admin.key(),
            SpokeError::NotAuthorizedToPause
        );
        state.paused = true;
        emit_cpi!(PausedEvent {});
        Ok(())
    }

    /// Unpause the program.
    pub fn unpause(ctx: Context<AdminState>) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.lighthouse == ctx.accounts.admin.key()
                || state.watchtower == ctx.accounts.admin.key(),
            SpokeError::NotAuthorizedToPause
        );
        state.paused = false;
        emit_cpi!(UnpausedEvent {});
        Ok(())
    }

    /// Create a new intent.
    /// The user "locks" funds (previously deposited) and creates an intent.
    /// For simplicity, we assume full deposit has been made before.
    pub fn new_intent(
        ctx: Context<NewIntent>,
        receiver: Pubkey,
        input_asset: Pubkey,
        output_asset: Pubkey,
        amount: u64,
        max_fee: u32,
        ttl: u64,
        destinations: Vec<u32>,
        data: Vec<u8>,
        message_gas_limit: u64,
    ) -> Result<()> {
        instructions::new_intent(
            ctx,
            receiver,
            input_asset,
            output_asset,
            amount,
            max_fee,
            ttl,
            destinations,
            data,
            message_gas_limit,
        )
    }

    /// Instruction relates to message receiving
    /// TODO: find a way to custom set the Discriminator as now its something like `hash(global:interchain_security_module)` while it needs to be
    /// `hyperlane-message-recipient:interchain-security-module`

    /// Receive a cross‑chain message via Hyperlane.
    /// In production, this would be invoked via CPI from Hyperlane's Mailbox.
    pub fn handle<'info>(
        ctx: Context<'_, '_, 'info, 'info, AuthState<'info>>,
        handle: HandleInstruction,
    ) -> Result<()> {
        instructions::handle(ctx, handle)
    }

    pub fn interchain_security_module(
        ctx: Context<InterchainSecurityModule>,
    ) -> Result<()> {
        instructions::interchain_security_module(ctx)
    }

    pub fn interchain_security_module_acconut_metas(
        ctx: Context<InterchainSecurityModuleAccountMetas>,
    ) -> Result<()> {
        instructions::interchain_security_module_account_metas(ctx)
    }

    pub fn handle_account_metas(
        ctx: Context<HandleAccountMetas>,
        handle: HandleInstruction,
    ) -> Result<AuthStateMetas> {
        instructions::handle_account_metas(ctx, handle)
    }

    /// Admin functions

    pub fn update_lighthouse(ctx: Context<AdminState>, new_lighthouse: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );

        instructions::update_lighthouse(ctx, new_lighthouse)
    }

    pub fn update_watchtower(ctx: Context<AdminState>, new_watchtower: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );

        instructions::update_watchtower(ctx, new_watchtower)
    }

    pub fn update_mailbox(ctx: Context<AdminState>, new_mailbox: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        // enforce only owner can do it
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );

        instructions::update_mailbox(ctx, new_mailbox)
    }

    /// new_igp contains the IGP address
    /// new_igp_type contains either the IGP address (as in new_igp), or the overhead IGP address if the IGP is an overhead IGP.
    pub fn update_igp(
        ctx: Context<AdminState>,
        new_igp: Pubkey,
        new_igp_type: InterchainGasPaymasterType,
    ) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        // enforce only owner can do it
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );

        instructions::update_igp(ctx, new_igp, new_igp_type)
    }

    pub fn update_message_gas_limit(ctx: Context<AdminState>, new_limit: u64) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );

        instructions::update_message_gas_limit(ctx, new_limit)
    }
}

// =====================================================================
// ACCOUNTS, STATE, EVENTS, ERRORS, & HELPER FUNCTIONS
// =====================================================================

/// Context for Hyperlane dispatch: We require a Hyperlane mailbox account.
#[derive(Accounts)]
pub struct HyperlaneDispatch<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    /// CHECK: This account must be the Hyperlane Mailbox program.
    pub hyperlane_mailbox: UncheckedAccount<'info>,
}

/// A simple record tracking a user's balance for a given asset.
#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub struct BalanceRecord {
    pub asset: Pubkey,
    pub user: Pubkey,
    pub amount: u64,
}

impl BalanceRecord {
    pub const SIZE: usize = 32 + 32 + 8;
}
