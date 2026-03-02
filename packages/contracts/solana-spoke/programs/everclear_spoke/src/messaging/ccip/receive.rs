use anchor_lang::prelude::*;

use crate::{
    error::SpokeError,
    messaging::ccip::message::Any2SVMMessage,
    state::SpokeState,
};

pub fn receive_message_via_ccip<'info>(
    ctx: &ReceiveMessageCCIP<'info>,
    message: Any2SVMMessage,
) -> Result<Vec<u8>> {
    let state = &ctx.spoke_state;

    require!(
        state.ccip_offramp.is_some(),
        SpokeError::InvalidMessage
    );
    let ccip_offramp = state.ccip_offramp.unwrap();

    require!(
        ctx.offramp_program.key() == ccip_offramp,
        SpokeError::InvalidSender
    );

    require!(
        ctx.allowed_offramp.owner == &state.ccip_router.unwrap(),
        SpokeError::InvalidSender
    );

    let (expected_allowed_offramp, _) = Pubkey::find_program_address(
        &[
            b"allowed_offramp",
            &message.source_chain_selector.to_le_bytes(),
            ctx.offramp_program.key().as_ref(),
        ],
        &state.ccip_router.unwrap(),
    );
    require_keys_eq!(
        ctx.allowed_offramp.key(),
        expected_allowed_offramp,
        SpokeError::InvalidSender
    );

    require!(
        state.everclear_ccip_chain_selector.is_some(),
        SpokeError::InvalidOrigin
    );
    require!(
        message.source_chain_selector == state.everclear_ccip_chain_selector.unwrap(),
        SpokeError::InvalidOrigin
    );

    let expected_gateway = state.everclear_gateway;
    let start_idx = if let Some(pos) = expected_gateway.iter().position(|&b| b != 0) {
        pos
    } else {
        expected_gateway.len().saturating_sub(20)
    };
    let end_idx = (start_idx + 20).min(expected_gateway.len());
    let expected_addr = &expected_gateway[start_idx..end_idx];

    require!(
        message.sender == expected_addr,
        SpokeError::InvalidSender
    );

    Ok(message.data)
}

pub struct ReceiveMessageCCIP<'info> {
    pub authority: Signer<'info>,
    pub offramp_program: UncheckedAccount<'info>,
    pub allowed_offramp: UncheckedAccount<'info>,
    pub external_execution_config: UncheckedAccount<'info>,
    pub spoke_state: Account<'info, SpokeState>,
}
