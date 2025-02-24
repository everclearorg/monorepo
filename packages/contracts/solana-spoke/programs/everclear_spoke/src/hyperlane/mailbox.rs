//! Instructions for the Hyperlane Sealevel Mailbox program.

use crate::{error::SpokeError, hyperlane::primitive_type::H256};
use anchor_lang::solana_program::{
    // instruction::{AccountMeta, Instruction as SolanaInstruction},
    pubkey::Pubkey,
};
use anchor_lang::{
    prelude::{
        borsh::{BorshDeserialize, BorshSerialize},
        *,
    },
    // solana_program::system_program,
};

// use crate::{mailbox_inbox_pda_seeds, mailbox_outbox_pda_seeds};

use super::OutboxDispatch;

/// The Protocol Fee configuration.
#[derive(BorshSerialize, BorshDeserialize, Debug, PartialEq, Eq, Clone, Default)]
// #[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
// #[cfg_attr(feature = "serde", serde(rename_all = "camelCase"))]
pub struct ProtocolFee {
    /// The current protocol fee, expressed in the lowest denomination.
    pub fee: u64,
    /// The beneficiary of protocol fees.
    pub beneficiary: Pubkey,
}

// /// The current message version.
// pub const VERSION: u8 = 3;

/// Instructions supported by the Mailbox program.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub enum MailboxInstruction {
    /// Initializes the program.
    Init(Init),
    /// Processes a message.
    InboxProcess(InboxProcess),
    /// Sets the default ISM.
    InboxSetDefaultIsm(Pubkey),
    /// Gets the recipient's ISM.
    InboxGetRecipientIsm(Pubkey),
    /// Dispatches a message.
    OutboxDispatch(OutboxDispatch),
    /// Gets the number of messages that have been dispatched.
    OutboxGetCount,
    /// Gets the latest checkpoint.
    OutboxGetLatestCheckpoint,
    /// Gets the root of the dispatched message merkle tree.
    OutboxGetRoot,
    /// Gets the owner of the Mailbox.
    GetOwner,
    /// Transfers ownership of the Mailbox.
    TransferOwnership(Option<Pubkey>),
    /// Transfers accumulated protocol fees to the beneficiary.
    ClaimProtocolFees,
    /// Sets the protocol fee configuration.
    SetProtocolFeeConfig(ProtocolFee),
}

impl MailboxInstruction {
    /// Serializes an instruction into a vector of bytes.
    pub fn into_instruction_data(self) -> Result<Vec<u8>> {
        Ok(self
            .try_to_vec()
            .map_err(|_err| SpokeError::InvalidMessage)?)
    }
}

/// Instruction data for the Init instruction.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub struct Init {
    /// The local domain of the Mailbox.
    pub local_domain: u32,
    /// The default ISM.
    pub default_ism: Pubkey,
    /// The maximum protocol fee that can be charged.
    pub max_protocol_fee: u64,
    /// The protocol fee configuration.
    pub protocol_fee: ProtocolFee,
}

/// Instruction data for the OutboxDispatch instruction.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub struct MailboxOutboxDispatch {
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

/// Instruction data for the InboxProcess instruction.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub struct InboxProcess {
    /// The metadata required by the ISM to process the message.
    pub metadata: Vec<u8>,
    /// The encoded message.
    pub message: Vec<u8>,
}

// /// Creates an Init instruction.
// pub fn init_instruction(
//     program_id: Pubkey,
//     local_domain: u32,
//     default_ism: Pubkey,
//     max_protocol_fee: u64,
//     protocol_fee: ProtocolFee,
//     payer: Pubkey,
// ) -> Result<SolanaInstruction> {
//     let (inbox_account, _inbox_bump) =
//         Pubkey::try_find_program_address(mailbox_inbox_pda_seeds!(), &program_id)
//             .ok_or(SpokeError::InvalidSeeds)?;
//     let (outbox_account, _outbox_bump) =
//         Pubkey::try_find_program_address(mailbox_outbox_pda_seeds!(), &program_id)
//             .ok_or(SpokeError::InvalidSeeds)?;

//     let instruction = SolanaInstruction {
//         program_id,
//         data: MailboxInstruction::Init(Init {
//             local_domain,
//             default_ism,
//             max_protocol_fee,
//             protocol_fee,
//         })
//         .into_instruction_data()?,
//         accounts: vec![
//             AccountMeta::new(system_program::id(), false),
//             AccountMeta::new(payer, true),
//             AccountMeta::new(inbox_account, false),
//             AccountMeta::new(outbox_account, false),
//         ],
//     };
//     Ok(instruction)
// }

// /// Creates a TransferOwnership instruction.
// pub fn transfer_ownership_instruction(
//     program_id: Pubkey,
//     owner_payer: Pubkey,
//     new_owner: Option<Pubkey>,
// ) -> Result<SolanaInstruction> {
//     let (outbox_account, _outbox_bump) =
//         Pubkey::try_find_program_address(mailbox_outbox_pda_seeds!(), &program_id)
//             .ok_or(SpokeError::InvalidSeeds)?;

//     // 0. `[writeable]` The Outbox PDA account.
//     // 1. `[signer]` The current owner.
//     let instruction = SolanaInstruction {
//         program_id,
//         data: MailboxInstruction::TransferOwnership(new_owner).into_instruction_data()?,
//         accounts: vec![
//             AccountMeta::new(outbox_account, false),
//             AccountMeta::new(owner_payer, true),
//         ],
//     };
//     Ok(instruction)
// }

// /// Creates an InboxSetDefaultIsm instruction.
// pub fn set_default_ism_instruction(
//     program_id: Pubkey,
//     owner_payer: Pubkey,
//     default_ism: Pubkey,
// ) -> Result<SolanaInstruction> {
//     let (inbox_account, _inbox_bump) =
//         Pubkey::try_find_program_address(mailbox_inbox_pda_seeds!(), &program_id)
//             .ok_or(SpokeError::InvalidSeeds)?;
//     let (outbox_account, _outbox_bump) =
//         Pubkey::try_find_program_address(mailbox_outbox_pda_seeds!(), &program_id)
//             .ok_or(SpokeError::InvalidSeeds)?;

//     // 0. `[writeable]` - The Inbox PDA account.
//     // 1. `[]` - The Outbox PDA account.
//     // 2. `[signer]` - The owner of the Mailbox.
//     let instruction = SolanaInstruction {
//         program_id,
//         data: MailboxInstruction::InboxSetDefaultIsm(default_ism).into_instruction_data()?,
//         accounts: vec![
//             AccountMeta::new(inbox_account, false),
//             AccountMeta::new_readonly(outbox_account, false),
//             AccountMeta::new(owner_payer, true),
//         ],
//     };
//     Ok(instruction)
// }

#[derive(Eq, PartialEq, AnchorSerialize, AnchorDeserialize, Debug)]
pub struct HandleInstruction {
    pub origin: u32,
    pub sender: H256,
    pub message: Vec<u8>,
}
