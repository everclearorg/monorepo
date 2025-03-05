//! Program instructions.

use anchor_lang::prelude::{
    borsh::{BorshDeserialize, BorshSerialize},
    *,
};

use anchor_lang::solana_program::pubkey::Pubkey;

use crate::{error::SpokeError, hyperlane::primitive_type::H256};

/// The program instructions.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub enum IgpInstruction {
    /// Pays for gas.
    IgpPayForGas(IgpPayForGas),
    /// Quotes a gas payment.
    QuoteGasPayment(QuoteGasPayment),
}

impl IgpInstruction {
    /// Serializes an instruction into a vector of bytes.
    pub fn into_instruction_data(self) -> Result<Vec<u8>> {
        self.try_to_vec()
            .map_err(|_| error!(SpokeError::InvalidMessage))
    }
}

/// Initializes an IGP.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub struct InitIgp {
    /// A salt used for deriving the IGP PDA.
    pub salt: H256,
    /// The owner of the IGP.
    pub owner: Option<Pubkey>,
    /// The beneficiary of the IGP.
    pub beneficiary: Pubkey,
}

/// Initializes an overhead IGP.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub struct InitOverheadIgp {
    /// A salt used for deriving the overhead IGP PDA.
    pub salt: H256,
    /// The owner of the overhead IGP.
    pub owner: Option<Pubkey>,
    /// The inner IGP.
    pub inner: Pubkey,
}

/// Pays for gas.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub struct IgpPayForGas {
    /// The message ID.
    pub message_id: H256,
    /// The destination domain.
    pub destination_domain: u32,
    /// The gas amount.
    pub gas_amount: u64,
}

/// Quotes a gas payment.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub struct QuoteGasPayment {
    /// The destination domain.
    pub destination_domain: u32,
    /// The gas amount.
    pub gas_amount: u64,
}
