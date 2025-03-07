//! Program instructions.

use anchor_lang::prelude::*;

use crate::{error::SpokeError, hyperlane::primitive_type::H256};

/// The program instructions for the Igp program.
/// They need to be the exact order (and with all the previous item) for enum ser/de to work.
/// ref: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/7c95140fa923562f4ee6a4ba171e626999d9bf13/rust/sealevel/programs/hyperlane-sealevel-igp/src/instruction.rs#L19
#[derive(AnchorDeserialize, AnchorSerialize, Debug, PartialEq)]
pub enum IgpInstruction {
    /// Initializes the program.
    Init,
    /// Initializes an IGP.
    InitIgp,
    /// Initializes an overhead IGP.
    InitOverheadIgp,
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

/// Pays for gas.
#[derive(AnchorDeserialize, AnchorSerialize, Debug, PartialEq)]
pub struct IgpPayForGas {
    /// The message ID.
    pub message_id: H256,
    /// The destination domain.
    pub destination_domain: u32,
    /// The gas amount.
    pub gas_amount: u64,
}

/// Quotes a gas payment.
#[derive(AnchorDeserialize, AnchorSerialize, Debug, PartialEq)]
pub struct QuoteGasPayment {
    /// The destination domain.
    pub destination_domain: u32,
    /// The gas amount.
    pub gas_amount: u64,
}
