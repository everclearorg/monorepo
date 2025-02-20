use anchor_lang::prelude::*;

use crate::consts::EVERCLEAR_DOMAIN;
use crate::{error::SpokeError, utils::compute_intent_hash};

use crate::{AuthState, Intent};

/// Process a batch of intents in the queue and dispatch a cross-chain message via Hyperlane.
pub fn process_intent_queue(
    ctx: Context<AuthState>,
    intents: Vec<Intent>, // Pass full intents, not just count
    message_gas_limit: u64,
) -> Result<()> {
    let state = &mut ctx.accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);
    require!(intents.len() > 0, SpokeError::InvalidAmount);

    // Verify each intent matches the queue
    // NOTE: Commenting as not emitting the event
    // let old_first = state.intent_queue.first_index();

    // Format message using proper message lib
    let batch_message = format_intent_message_batch(&intents)?;

    // Call Hyperlane with proper gas handling
    let ix_data = {
        let mut data = Vec::new();
        data.extend_from_slice(&EVERCLEAR_DOMAIN.to_be_bytes());
        data.extend_from_slice(&state.gateway.to_bytes());
        data.extend_from_slice(&message_gas_limit.to_be_bytes());
        data.extend_from_slice(&batch_message);
        data
    };
    let ix = anchor_lang::solana_program::instruction::Instruction {
        program_id: ctx.accounts.hyperlane_mailbox.key(),
        accounts: vec![],
        data: ix_data,
    };
    // TODO: Not handling messageId or fee spent here
    anchor_lang::solana_program::program::invoke(
        &ix,
        &[ctx.accounts.hyperlane_mailbox.to_account_info()],
    )?;

    // TODO: Need the meesage_id and fee spent data from above
    // emit!(IntentQueueProcessedEvent {
    //     message_id,
    //     first_index: old_first,
    //     last_index: old_first + intents.len() as u64,
    //     fee_spent,
    // });
    Ok(())
}

fn format_intent_message_batch(intents: &[Intent]) -> Result<Vec<u8>> {
    // Example:
    let mut buffer = Vec::new();
    // e.g. prefix a message type byte
    buffer.push(1);
    // then Borsh‐encode the `Vec<Intent>`
    let encoded = intents.try_to_vec()?;
    buffer.extend_from_slice(&encoded);
    Ok(buffer)
}
