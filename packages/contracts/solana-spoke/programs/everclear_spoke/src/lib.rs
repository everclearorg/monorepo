use anchor_lang::prelude::*;

pub mod consts;
pub mod error;
pub mod events;
pub mod hyperlane;
pub mod instructions;
pub mod state;

use error::SpokeError;
use events::*;
use hyperlane::{mailbox::HandleInstruction, InterchainGasPaymasterType, SerializableAccountMeta};
use instructions::*;

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

    /// Receive a cross‑chain message via Hyperlane.
    /// In production, this would be invoked via CPI from Hyperlane's Mailbox.
    #[interface(hyperlane_message_recipient::handle)]
    pub fn handle<'info>(
        ctx: Context<'_, '_, 'info, 'info, AuthState<'info>>,
        handle: HandleInstruction,
    ) -> Result<()> {
        instructions::handle(ctx, handle)
    }

    #[interface(hyperlane_message_recipient::interchain_security_module)]
    pub fn interchain_security_module(ctx: Context<InterchainSecurityModule>) -> Result<()> {
        instructions::interchain_security_module(ctx)
    }

    #[interface(hyperlane_message_recipient::interchain_security_module_account_metas)]
    pub fn interchain_security_module_acconut_metas(
        ctx: Context<InterchainSecurityModuleAccountMetas>,
    ) -> Result<Vec<SerializableAccountMeta>> {
        instructions::interchain_security_module_account_metas(ctx)
    }

    #[interface(hyperlane_message_recipient::handle_account_metas)]
    pub fn handle_account_metas(
        ctx: Context<HandleAccountMetas>,
        handle: HandleInstruction,
    ) -> Result<Vec<SerializableAccountMeta>> {
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

    pub fn update_mailbox_dispatch_authority_bump(ctx: Context<AdminState>, new_bump: u8) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );

        instructions::update_mailbox_dispatch_authority_bump(ctx, new_bump)
    }
}
