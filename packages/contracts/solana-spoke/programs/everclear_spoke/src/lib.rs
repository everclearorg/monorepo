use anchor_lang::prelude::*;

pub mod consts;
pub mod state;
pub mod events;
pub mod instructions;
pub mod error;

use instructions::*;
use state::SpokeState;
use events::*;

declare_id!("uvXqfnsfugQTAbd8Wy7xUBQDhcREMGZZeCUb1Y3fXLC");


#[program]
pub mod everclear_spoke {
    use crate::error::SpokeError;

    use super::*;
    
    // TODO: Do we need to add initializer modifier to this?
    /// Initialize the global state.
    /// This function creates the SpokeState (global config) PDA.
    #[access_control(&ctx.accounts.ensure_owner_is_valid(&init.owner))]
    pub fn initialize(
        ctx: Context<Initialize>,
        init: SpokeInitializationParams,
    ) -> Result<()> {
        instructions::initialize(ctx, init)
    }

    /// Pause the program.
    /// Only the lighthouse or watchtower can call this.
    pub fn pause(ctx: Context<AuthState>) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.lighthouse == ctx.accounts.authority.key() || state.watchtower == ctx.accounts.authority.key(),
            SpokeError::NotAuthorizedToPause
        );
        state.paused = true;
        emit!(PausedEvent {});
        Ok(())
    }

    /// Unpause the program.
    pub fn unpause(ctx: Context<AuthState>) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.lighthouse == ctx.accounts.authority.key() || state.watchtower == ctx.accounts.authority.key(),
            SpokeError::NotAuthorizedToPause
        );
        state.paused = false;
        emit!(UnpausedEvent {});
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
    ) -> Result<()> {
        instructions::new_intent(ctx, receiver, input_asset, output_asset, amount, max_fee, ttl, destinations, data)
    }

    /// Process a batch of intents in the queue and dispatch a cross-chain message via Hyperlane.
    pub fn process_intent_queue(
        ctx: Context<AuthState>, 
        intents: Vec<Intent>,  // Pass full intents, not just count
        message_gas_limit: u64
    ) -> Result<()> {
        instructions::process_intent_queue(ctx, intents, message_gas_limit)
    }

    /// Receive a cross‑chain message via Hyperlane.
    /// In production, this would be invoked via CPI from Hyperlane's Mailbox.
    pub fn receive_message<'a>(
        ctx: Context<'_, '_, 'a, 'a, AuthState<'a>>,
        origin: u32,
        sender: Pubkey,
        payload: Vec<u8>,
    ) -> Result<()> {
        instructions::receive_message(ctx, origin, sender, payload, &ID)
    }

    /// Update the gateway address (admin only).
    pub fn update_gateway(ctx: Context<AuthState>, new_gateway: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        let authority = ctx.accounts.authority.key();
        require!(state.owner == authority, SpokeError::OnlyOwner);

        instructions::update_gateway(state, new_gateway)
    }

    pub fn update_lighthouse(ctx: Context<AuthState>, new_lighthouse: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(state.owner == ctx.accounts.authority.key(), SpokeError::OnlyOwner);

        instructions::update_lighthouse(state, new_lighthouse)
    }

    pub fn update_watchtower(ctx: Context<AuthState>, new_watchtower: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(state.owner == ctx.accounts.authority.key(), SpokeError::OnlyOwner);

        instructions::update_watchtower(state, new_watchtower)
    }

    pub fn update_mailbox(ctx: Context<AuthState>, new_mailbox: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        // enforce only owner can do it
        require!(state.owner == ctx.accounts.authority.key(), SpokeError::OnlyOwner);

        instructions::update_mailbox(state, new_mailbox)
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
