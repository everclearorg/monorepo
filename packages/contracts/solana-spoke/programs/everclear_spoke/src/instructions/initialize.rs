use anchor_lang::prelude::*;

use crate::{
    error::SpokeError,
    events::InitializedEvent,
    state::{QueueState, SpokeState},
};

pub fn initialize(ctx: Context<Initialize>, init: SpokeInitializationParams) -> Result<()> {
    let state = &mut ctx.accounts.spoke_state;

    require!(
        state.initialized_version == 0,
        SpokeError::AlreadyInitialized
    );
    state.initialized_version = 1;

    state.paused = false;
    state.domain = init.domain;
    state.gateway = init.gateway;
    state.message_receiver = init.message_receiver;
    state.lighthouse = init.lighthouse;
    state.watchtower = init.watchtower;
    state.call_executor = init.call_executor;
    state.everclear = init.hub_domain;
    state.message_gas_limit = init.message_gas_limit;
    state.nonce = 0;

    // Initialize our mappings and queues
    state.intent_queue = QueueState::new();

    // Set owner to the payer (deployer)
    state.owner = init.owner;
    state.bump = ctx.bumps.spoke_state;

    emit!(InitializedEvent {
        owner: state.owner,
        domain: state.domain,
        everclear: state.everclear,
    });
    Ok(())
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = payer,
        space = 8 + SpokeState::SIZE,
        seeds = [b"spoke-state"],
        bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    #[account(mut)]
    pub payer: Signer<'info>,
    pub system_program: Program<'info, System>,
}

impl<'info> Initialize<'info> {
    pub fn ensure_owner_is_valid(&self, new_owner: &Pubkey) -> Result<()> {
        require!(*new_owner != Pubkey::default(), SpokeError::InvalidOwner);
        Ok(())
    }
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct SpokeInitializationParams {
    pub domain: u32,
    pub hub_domain: u32,
    pub lighthouse: Pubkey,
    pub watchtower: Pubkey,
    pub call_executor: Pubkey,
    pub message_receiver: Pubkey,
    pub gateway: Pubkey,
    pub message_gas_limit: u64,
    pub owner: Pubkey,
}
