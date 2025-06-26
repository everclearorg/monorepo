use anchor_lang::prelude::*;

use crate::{error::SpokeError, hyperlane::mailbox::HandleInstruction, mark_message_as_delivered};

use super::HandleContext;

/// Receive a cross‑chain message via Hyperlane via admin.
/// This have the same interface as the hyperlane message `handle`, and should only be used if hyperlane fails
/// to transmit message.
pub fn handle_as_admin(ctx: Context<HandleContext>, handle: HandleInstruction) -> Result<()> {
    require!(
        ctx.accounts.authority.key() == ctx.accounts.spoke_state.owner,
        SpokeError::InvalidSender
    );

    mark_message_as_delivered(ctx, handle)
}
