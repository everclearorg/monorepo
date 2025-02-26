//! Instructions for the Hyperlane Sealevel Mailbox program.

use crate::{error::SpokeError, hyperlane::primitive_type::H256};
use anchor_lang::prelude::{
    borsh::{BorshDeserialize, BorshSerialize},
    *,
};

/// Instructions supported by the Mailbox program.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub enum MailboxInstruction {
    /// Dispatches a message.
    OutboxDispatch(OutboxDispatch),
}

impl MailboxInstruction {
    /// Serializes an instruction into a vector of bytes.
    pub fn into_instruction_data(self) -> Result<Vec<u8>> {
        Ok(self
            .try_to_vec()
            .map_err(|_err| SpokeError::InvalidMessage)?)
    }
}

/// Instruction data for the OutboxDispatch instruction.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub struct OutboxDispatch {
    /// The sender of the message.
    /// This is required and not implied because a program uses a dispatch authority PDA
    /// to sign the CPI on its behalf. Instruction processing logic prevents a program from
    /// specifying any message sender it wants by requiring the relevant dispatch authority
    /// to sign the CPI.
    pub sender: Pubkey,
    /// The destination domain of the message.
    pub destination_domain: u32,
    /// The remote recipient of the message.
    pub recipient: H256,
    /// The message body.
    pub message_body: Vec<u8>,
}

#[derive(Eq, PartialEq, AnchorSerialize, AnchorDeserialize, Debug)]
pub struct HandleInstruction {
    pub origin: u32,
    pub sender: H256,
    pub message: Vec<u8>,
}
