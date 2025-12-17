use anchor_lang::prelude::*;

pub mod consts;
pub mod error;
pub mod events;
pub mod hyperlane;
pub mod instructions;
pub mod state;

use error::SpokeError;
use events::*;
use hyperlane::{
    mailbox::HandleInstruction, InterchainGasPaymasterType, SerializableAccountMeta,
    SimulationReturnData,
};
use instructions::fee_adapter::{
    CloseFeeAdapter, FeeAdapterAdminState, FeeParams, InitializeFeeAdapter, MigrateFeeAdapter,
    __client_accounts_fee_adapter_admin_state, __client_accounts_initialize_fee_adapter,
};

use instructions::new_order::OrderParameters;
use instructions::*;

declare_id!("everUnMiUkvZG8EyXAtW8HfMavCBTVeMhQszbrtpUQm");

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
    /// NOTE: max_fee is not used now and we do not support amountOutMin yet for swaps.
    pub fn new_intent(
        ctx: Context<NewIntent>,
        receiver: Pubkey,
        output_asset: Pubkey,
        amount: u64,
        amount_out_min: u128,
        ttl: u64,
        destinations: Vec<u32>,
        data: Vec<u8>,
        message_gas_limit: u64,
        fee_param: FeeParams,
    ) -> Result<()> {
        instructions::new_intent(
            ctx,
            receiver,
            output_asset,
            amount,
            amount_out_min,
            ttl,
            destinations,
            data,
            message_gas_limit,
            fee_param,
        )
    }

    pub fn new_order(
        ctx: Context<NewIntent>,
        params: Vec<OrderParameters>,
        fee_param: FeeParams,
    ) -> Result<()> {
        instructions::new_order(ctx, params, fee_param)
    }

    /// Fills a new intent.
    /// The user "locks" funds (previously deposited) and fills an intent.
    /// NOTE: different from EVM, we do not support pullFunds, i.e. we requires funds to be sent during the tx
    /// and not deposited prior in the spoke.
    pub fn fill_intent(
        ctx: Context<FillIntent>,
        // origin intent, flattened
        origin_initiator: [u8; 32],
        // NOTE: origin_receiver is put in ctx for space saving using LUT
        origin_input_asset: [u8; 32],
        // NOTE: we do not need output_asset here as this woule be `ctx.mint`. This is removed for space saving using LUT.
        intent_origin: u32,
        origin_nonce: u64,
        origin_timestamp: u64,           // actually uint48 in Solidity
        origin_ttl: u64,                 // actually uint48 in Solidity
        origin_amount: [u8; 32],         // big-endian, matching typical EVM usage
        origin_amount_out_min: [u8; 32], // uint256
        origin_destinations: Vec<u32>,
        origin_data: Vec<u8>,

        // data for fill intent
        amount_out: u64,
        receiver: Pubkey,
        destinations: Vec<u32>,

        // hyperlane params
        message_gas_limit: u64,
        signature: Vec<u8>,
    ) -> Result<()> {
        instructions::fill_intent(
            ctx,
            origin_initiator,
            origin_input_asset,
            intent_origin,
            origin_nonce,
            origin_timestamp,
            origin_ttl,
            origin_amount,
            origin_amount_out_min,
            origin_destinations,
            origin_data,
            amount_out,
            receiver,
            destinations,
            message_gas_limit,
            signature,
        )
    }

    // Instruction relates to message receiving

    /// Receive a cross‑chain message via Hyperlane.
    /// In production, this would be invoked via CPI from Hyperlane's Mailbox.
    #[instruction(discriminator = [33, 210, 5, 66, 196, 212, 239, 142])]
    pub fn handle(ctx: Context<HandleContext>, handle: HandleInstruction) -> Result<()> {
        instructions::handle(ctx, handle)
    }

    #[instruction(discriminator = [45, 18, 245, 87, 234, 46, 246, 15])]
    pub fn interchain_security_module(ctx: Context<InterchainSecurityModule>) -> Result<()> {
        instructions::interchain_security_module(ctx)
    }

    #[instruction(discriminator = [190, 214, 218, 129, 67, 97, 4, 76])]
    pub fn interchain_security_module_account_metas(
        ctx: Context<InterchainSecurityModuleAccountMetas>,
    ) -> Result<SimulationReturnData<Vec<SerializableAccountMeta>>> {
        instructions::interchain_security_module_account_metas(ctx)
    }

    #[instruction(discriminator = [194, 141, 30, 82, 241, 41, 169, 52])]
    pub fn handle_account_metas(
        ctx: Context<HandleAccountMetas>,
        handle: HandleInstruction,
    ) -> Result<SimulationReturnData<Vec<SerializableAccountMeta>>> {
        instructions::handle_account_metas(ctx, handle)
    }

    // Admin functions, note this do not need to conform with hyperlane interfaces as this is manually triggered by admin.
    pub fn handle_as_admin(ctx: Context<HandleContext>, handle: HandleInstruction) -> Result<()> {
        instructions::handle_as_admin(ctx, handle)
    }

    // settle delivered message
    pub fn settle_delivered_intent(
        ctx: Context<SettleDeliveredIntentContext>,
        settle_delivered_intent: SettleDeliveredIntentInstruction,
    ) -> Result<()> {
        instructions::settle_delivered_intent(ctx, settle_delivered_intent)
    }

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

    pub fn update_mailbox_dispatch_authority_bump(
        ctx: Context<AdminState>,
        new_bump: u8,
    ) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );

        instructions::update_mailbox_dispatch_authority_bump(ctx, new_bump)
    }

    pub fn update_vault_authority_bump(ctx: Context<AdminState>, new_bump: u8) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );

        instructions::update_vault_authority_bump(ctx, new_bump)
    }

    // Fee Adapter Functions

    pub fn initialize_fee_adapter(
        ctx: Context<InitializeFeeAdapter>,
        fee_recipient: Pubkey,
        fee_signer: Pubkey,
        fill_signer: Pubkey,
    ) -> Result<()> {
        let state = &ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.payer.key(),
            SpokeError::OnlyOwner
        );
        fee_adapter::initialize_fee_adapter(ctx, fee_recipient, fee_signer, fill_signer)
    }

    pub fn update_fee_recipient(
        ctx: Context<FeeAdapterAdminState>,
        fee_recipient: Pubkey,
    ) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );
        fee_adapter::update_fee_recipient(ctx, fee_recipient)
    }

    pub fn update_fee_signer(ctx: Context<FeeAdapterAdminState>, fee_signer: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );
        fee_adapter::update_fee_signer(ctx, fee_signer)
    }

    pub fn update_fill_signer(ctx: Context<FeeAdapterAdminState>, fill_signer: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );
        fee_adapter::update_fill_signer(ctx, fill_signer)
    }

    pub fn pause_fee_adapter(ctx: Context<FeeAdapterAdminState>) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );
        fee_adapter::pause_fee_adapter(ctx)
    }

    pub fn unpause_fee_adapter(ctx: Context<FeeAdapterAdminState>) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.admin.key(),
            SpokeError::OnlyOwner
        );
        fee_adapter::unpause_fee_adapter(ctx)
    }

    pub fn close_fee_adapter(ctx: Context<CloseFeeAdapter>) -> Result<()> {
        let state = &ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.payer.key(),
            SpokeError::OnlyOwner
        );
        fee_adapter::close_fee_adapter(ctx)
    }

    pub fn migrate_fee_adapter(
        ctx: Context<MigrateFeeAdapter>,
        fee_recipient: Pubkey,
        fee_signer: Pubkey,
        fill_signer: Pubkey,
    ) -> Result<()> {
        let state = &ctx.accounts.spoke_state;
        require!(
            state.owner == ctx.accounts.payer.key(),
            SpokeError::OnlyOwner
        );
        fee_adapter::migrate_fee_adapter(ctx, fee_recipient, fee_signer, fill_signer)
    }
}
