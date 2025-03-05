use anchor_lang::prelude::*;

use crate::{
    error::SpokeError, events::InitializedEvent, hyperlane::InterchainGasPaymasterType,
    state::SpokeState,
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
    state.message_receiver = init.message_receiver;
    state.lighthouse = init.lighthouse;
    state.watchtower = init.watchtower;
    state.call_executor = init.call_executor;
    state.everclear = init.hub_domain;
    state.message_gas_limit = init.message_gas_limit;
    state.nonce = 0;
    state.mailbox = init.mailbox;
    state.igp = init.igp;
    state.igp_type = init.igp_type;
    state.mailbox_dispatch_authority_bump = init.mailbox_dispatch_authority_bump;

    // Set owner to the payer (deployer)
    state.owner = init.owner;
    state.bump = ctx.bumps.spoke_state;

    emit_cpi!(InitializedEvent {
        owner: state.owner,
        domain: state.domain,
        everclear: state.everclear,
    });
    Ok(())
}

#[event_cpi]
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

impl Initialize<'_> {
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
    pub message_gas_limit: u64,
    pub owner: Pubkey,
    pub mailbox: Pubkey,
    pub igp: Pubkey,
    pub igp_type: InterchainGasPaymasterType,
    pub mailbox_dispatch_authority_bump: u8,
}
