use super::solana_ed25519_program::{
    Ed25519SignatureOffsets, DATA_START, PUBKEY_SERIALIZED_SIZE, SIGNATURE_OFFSETS_START,
    SIGNATURE_SERIALIZED_SIZE,
};
use anchor_lang::{
    prelude::*,
    solana_program::{
        ed25519_program,
        keccak,
        sysvar::instructions::{load_current_index_checked, load_instruction_at_checked},
    },
};
use bytemuck::bytes_of;

use crate::consts::THIS_DOMAIN;
use crate::error::SpokeError;

use super::SignatureAccounts;

const PUBLIC_KEY_OFFSET: usize = DATA_START;
const SIGNATURE_OFFSET: usize = PUBLIC_KEY_OFFSET.saturating_add(PUBKEY_SERIALIZED_SIZE);
const MESSAGE_DATA_OFFSET: usize = SIGNATURE_OFFSET.saturating_add(SIGNATURE_SERIALIZED_SIZE);
const DOMAIN_TYPE_HASH_PREFIX: &[u8] = b"EverclearFeeDomain";
pub const FEE_DATA_TYPE_HASH_PREFIX: &[u8] = b"FeeData";
pub const BATCH_FEE_DATA_TYPE_HASH_PREFIX: &[u8] = b"BatchFeeData";
pub const FILL_SIGN_PARAMS_TYPE_HASH_PREFIX: &[u8] = b"FillSignParams";

fn compute_domain_type_hash(program_id: &Pubkey) -> [u8; 32] {
    let mut domain_data = Vec::new();
    domain_data.extend_from_slice(DOMAIN_TYPE_HASH_PREFIX);
    domain_data.extend_from_slice(&program_id.to_bytes());
    domain_data.extend_from_slice(&THIS_DOMAIN.to_le_bytes());
    keccak::hash(&domain_data).to_bytes()
}

fn compute_function_type_hash(function_prefix: &[u8]) -> [u8; 32] {
    keccak::hash(function_prefix).to_bytes()
}

pub fn verify_signature<T>(
    data: &T,
    signature: Vec<u8>,
    accounts: SignatureAccounts,
    program_id: &Pubkey,
    function_type_prefix: &[u8],
) -> Result<()>
where
    T: AnchorSerialize,
{
    let domain_type_hash = compute_domain_type_hash(program_id);
    let function_type_hash = compute_function_type_hash(function_type_prefix);
    let mut encoded_data = vec![];
    data.serialize(&mut encoded_data)?;
    let mut encoded_message = Vec::with_capacity(64 + encoded_data.len());
    encoded_message.extend_from_slice(&domain_type_hash);
    encoded_message.extend_from_slice(&function_type_hash);
    encoded_message.extend_from_slice(&encoded_data);

    let current_instruction_idx = load_current_index_checked(&accounts.instruction_sysvar)?;
    require!(current_instruction_idx != 0, SpokeError::MissingEd25519Instruction);
    let preinstruction_idx = current_instruction_idx - 1;
    let preinstruction =
        load_instruction_at_checked(preinstruction_idx.into(), &accounts.instruction_sysvar)?;
    require!(
        preinstruction.program_id == ed25519_program::ID,
        SpokeError::MissingEd25519Instruction
    );
    require!(
        preinstruction.accounts.is_empty(),
        SpokeError::InvalidFeeSignatureAccountsNotEmpty
    );
    let expected_len = DATA_START
        + PUBKEY_SERIALIZED_SIZE
        + SIGNATURE_SERIALIZED_SIZE
        + encoded_message.len();
    require!(
        preinstruction.data.len() == expected_len,
        SpokeError::InvalidFeeSignatureDataLength
    );
    require!(preinstruction.data[0] == 1, SpokeError::InvalidFeeSignatureNumSignatures);
    require!(preinstruction.data[1] == 0, SpokeError::InvalidFeeSignaturePadding);

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
        SpokeError::InvalidFeeSignatureOffsets
    );
    let preinstruction_pubkey =
        &preinstruction.data[PUBLIC_KEY_OFFSET..PUBLIC_KEY_OFFSET + PUBKEY_SERIALIZED_SIZE];
    let signer_key = accounts.signer.key();
    let expected_pubkey = signer_key.as_array();
    require!(
        preinstruction_pubkey == expected_pubkey,
        SpokeError::InvalidFeeSignaturePubkeyMismatch
    );
    require!(
        preinstruction.data[SIGNATURE_OFFSET..SIGNATURE_OFFSET + SIGNATURE_SERIALIZED_SIZE]
            == signature,
        SpokeError::InvalidFeeSignatureDataMismatch
    );
    require!(
        preinstruction.data[MESSAGE_DATA_OFFSET..MESSAGE_DATA_OFFSET + encoded_message.len()]
            == encoded_message,
        SpokeError::InvalidFeeSignatureMessageMismatch
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use anchor_lang::prelude::Pubkey;

    #[test]
    fn test_domain_type_hash_includes_program_id() {
        let program_id1 = Pubkey::new_unique();
        let program_id2 = Pubkey::new_unique();
        let domain_hash1 = compute_domain_type_hash(&program_id1);
        let domain_hash2 = compute_domain_type_hash(&program_id2);
        assert_ne!(domain_hash1, domain_hash2);
    }

    #[test]
    fn test_function_type_hash_separation() {
        let fee_data_hash = compute_function_type_hash(FEE_DATA_TYPE_HASH_PREFIX);
        let batch_fee_data_hash = compute_function_type_hash(BATCH_FEE_DATA_TYPE_HASH_PREFIX);
        let fill_sign_params_hash = compute_function_type_hash(FILL_SIGN_PARAMS_TYPE_HASH_PREFIX);
        assert_ne!(fee_data_hash, batch_fee_data_hash);
        assert_ne!(fee_data_hash, fill_sign_params_hash);
        assert_ne!(batch_fee_data_hash, fill_sign_params_hash);
    }
}
