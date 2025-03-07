//! Instructions for the Hyperlane Sealevel Mailbox program.

use crate::{error::SpokeError, hyperlane::primitive_type::H256};
use anchor_lang::prelude::{
    borsh::{BorshDeserialize, BorshSerialize},
    *,
};

/// Instructions supported by the Mailbox program.
/// It needs to have the exact order with the enum defined in hyperlane for ser/de to work
/// ref: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/7c95140fa923562f4ee6a4ba171e626999d9bf13/rust/sealevel/programs/mailbox/src/instruction.rs#L18
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub enum MailboxInstruction {
    /// Initializes the program.
    Init(),
    /// Processes a message.
    InboxProcess(),
    /// Sets the default ISM.
    InboxSetDefaultIsm(Pubkey),
    /// Gets the recipient's ISM.
    InboxGetRecipientIsm(Pubkey),
    /// Dispatches a message.
    OutboxDispatch(OutboxDispatch),
}

impl MailboxInstruction {
    /// Serializes an instruction into a vector of bytes.
    pub fn into_instruction_data(self) -> Result<Vec<u8>> {
        self.try_to_vec()
            .map_err(|_err| error!(SpokeError::InvalidMessage))
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
