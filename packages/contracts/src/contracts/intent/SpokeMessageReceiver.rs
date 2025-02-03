use anchor_lang::prelude::*;
use crate::spoke_storage::SpokeStorageState;

declare_id!("MsgR111111111111111111111111111111111111111");

#[program]
pub mod spoke_message_receiver {
    use super::*;

    /// Message types
    pub const VAR_UPDATE: u8 = 1;
    pub const BATCH_SETTLEMENT: u8 = 2;

    /// Receives and processes a message from the gateway
    /// 
    /// # Arguments
    /// * `ctx` - The context for message reception
    /// * `message` - The message bytes to process
    pub fn receive_message(ctx: Context<ReceiveMessage>, message: Vec<u8>) -> Result<()> {
        require!(!message.is_empty(), CustomError::EmptyMessage);
        
        // First byte is the message type
        let message_type = message[0];
        let message_data = &message[1..];

        match message_type {
            VAR_UPDATE => process_var_update(ctx, message_data)?,
            BATCH_SETTLEMENT => process_batch_settlement(ctx, message_data)?,
            _ => return Err(CustomError::InvalidMessageType.into()),
        }

        Ok(())
    }
}

/// Processes a variable update message
fn process_var_update(ctx: Context<ReceiveMessage>, data: &[u8]) -> Result<()> {
    require!(data.len() >= 64, CustomError::InvalidMessageLength);
    
    let var_id = &data[..32];
    let new_value = &data[32..64];
    
    msg!("Processing var update for {:?}", var_id);
    
    // Update the appropriate variable based on var_id
    // This is a simplified implementation
    let state = &mut ctx.accounts.state;
    
    // Example: Update gateway if var_id matches
    if var_id == [1u8; 32] {
        let new_gateway = Pubkey::try_from(new_value)
            .map_err(|_| CustomError::InvalidPublicKey)?;
        state.gateway = new_gateway;
        msg!("Updated gateway to {}", new_gateway);
    }
    
    Ok(())
}

/// Processes a batch settlement message
fn process_batch_settlement(ctx: Context<ReceiveMessage>, data: &[u8]) -> Result<()> {
    require!(data.len() >= 32, CustomError::InvalidMessageLength);
    
    let state = &mut ctx.accounts.state;
    
    // Process each settlement in the batch
    let mut offset = 0;
    while offset < data.len() {
        require!(data.len() >= offset + 32, CustomError::InvalidMessageLength);
        
        let intent_hash = &data[offset..offset + 32];
        msg!("Processing settlement for intent {:?}", intent_hash);
        
        // Find and process the intent
        // This is a simplified implementation
        // In production, you would:
        // 1. Find the intent in the queue
        // 2. Verify the settlement data
        // 3. Update balances
        // 4. Remove the intent from the queue
        
        offset += 32;
    }
    
    Ok(())
}

#[derive(Accounts)]
pub struct ReceiveMessage<'info> {
    /// The state account to update
    #[account(mut)]
    pub state: Account<'info, SpokeStorageState>,
}

#[error_code]
pub enum CustomError {
    #[msg("Empty message")]
    EmptyMessage,
    #[msg("Invalid message type")]
    InvalidMessageType,
    #[msg("Invalid message length")]
    InvalidMessageLength,
    #[msg("Invalid public key")]
    InvalidPublicKey,
} 