use super::solana_ed25519_program::{
    Ed25519SignatureOffsets, DATA_START, PUBKEY_SERIALIZED_SIZE, SIGNATURE_OFFSETS_START,
    SIGNATURE_SERIALIZED_SIZE,
};
use anchor_lang::{
    prelude::*,
    solana_program::{
        ed25519_program,
        sysvar::instructions::{load_current_index_checked, load_instruction_at_checked},
    },
};
use bytemuck::bytes_of;

use crate::error::SpokeError;

use super::SignatureAccounts;
const PUBLIC_KEY_OFFSET: usize = DATA_START;
const SIGNATURE_OFFSET: usize = PUBLIC_KEY_OFFSET.saturating_add(PUBKEY_SERIALIZED_SIZE);
const MESSAGE_DATA_OFFSET: usize = SIGNATURE_OFFSET.saturating_add(SIGNATURE_SERIALIZED_SIZE);

pub fn verify_signature<T>(data: &T, signature: Vec<u8>, accounts: SignatureAccounts) -> Result<()>
where
    T: AnchorSerialize,
{
    let mut encoded_message = vec![];
    data.serialize(&mut encoded_message)?;

    // NOTE: signature programs are native in nodes but they requires lamports to run, thus this have
    // to be done in preinstructions.

    let current_instruction_idx = load_current_index_checked(&accounts.instruction_sysvar)?;

    require!(
        current_instruction_idx != 0,
        SpokeError::MissingEd25519Instruction
    );

    // NOTE: this will not underflow as current_instruction_idx != 0
    let preinstruction_idx = current_instruction_idx - 1;

    let preinstruction =
        load_instruction_at_checked(preinstruction_idx.into(), &accounts.instruction_sysvar)?;

    // check size
    require!(
        preinstruction.program_id == ed25519_program::ID,
        SpokeError::MissingEd25519Instruction
    );
    require!(
        preinstruction.accounts.is_empty(),
        SpokeError::InvalidFeeSignature
    );
    // NOTE: the data struct: 16 byte header (with all the offsets), 32 bytes (pubkey), 64 bytes (signature), msg
    require!(
        preinstruction.data.len()
            == DATA_START
                + PUBKEY_SERIALIZED_SIZE
                + SIGNATURE_SERIALIZED_SIZE
                + encoded_message.len(),
        SpokeError::InvalidFeeSignature
    );

    // check data
    // Byte 0: num of signatures
    require!(preinstruction.data[0] == 1, SpokeError::InvalidFeeSignature);
    // Byte 1: padding byte
    require!(preinstruction.data[1] == 0, SpokeError::InvalidFeeSignature);
    // Byte 2-16: offsets

    let offsets = Ed25519SignatureOffsets {
        signature_offset: SIGNATURE_OFFSET as u16,
        signature_instruction_index: u16::MAX,
        public_key_offset: PUBLIC_KEY_OFFSET as u16,
        public_key_instruction_index: u16::MAX,
        message_data_offset: MESSAGE_DATA_OFFSET as u16,
        message_data_size: encoded_message.len() as u16,
        message_instruction_index: u16::MAX,
    };
    require!(
        preinstruction.data[SIGNATURE_OFFSETS_START..DATA_START] == *bytes_of(&offsets),
        SpokeError::InvalidFeeSignature
    );

    // signing key used in verify call
    require!(
        preinstruction.data[PUBLIC_KEY_OFFSET..PUBLIC_KEY_OFFSET + PUBKEY_SERIALIZED_SIZE]
            == *accounts.signer.key().as_array(),
        SpokeError::InvalidFeeSignature
    );

    // signature used in verify call
    require!(
        preinstruction.data[SIGNATURE_OFFSET..SIGNATURE_OFFSET + SIGNATURE_SERIALIZED_SIZE]
            == signature,
        SpokeError::InvalidFeeSignature
    );

    // message used in verify call
    require!(
        preinstruction.data[MESSAGE_DATA_OFFSET..MESSAGE_DATA_OFFSET + encoded_message.len()]
            == encoded_message,
        SpokeError::InvalidFeeSignature
    );

    // NOTE: if all preinstruction calldata is verify, the preinstruction must succeed, or else it will revert the whole tx.
    Ok(())
}
