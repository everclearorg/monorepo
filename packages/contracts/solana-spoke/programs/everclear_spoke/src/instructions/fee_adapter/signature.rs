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

use crate::error::SpokeError;
use crate::consts::THIS_DOMAIN;

use super::SignatureAccounts;
const PUBLIC_KEY_OFFSET: usize = DATA_START;
const SIGNATURE_OFFSET: usize = PUBLIC_KEY_OFFSET.saturating_add(PUBKEY_SERIALIZED_SIZE);
const MESSAGE_DATA_OFFSET: usize = SIGNATURE_OFFSET.saturating_add(SIGNATURE_SERIALIZED_SIZE);
const DOMAIN_TYPE_HASH_PREFIX: &[u8] = b"EverclearFeeDomain";
// Function type hash prefixes for different fee data types
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
        
        assert_ne!(
            domain_hash1, domain_hash2,
            "Domain type hash should differ for different program IDs"
        );
    }

    #[test]
    fn test_domain_type_hash_includes_domain() {

        let program_id = Pubkey::new_unique();
        let domain_hash = compute_domain_type_hash(&program_id);
        
        let domain_hash2 = compute_domain_type_hash(&program_id);
        assert_eq!(
            domain_hash, domain_hash2,
            "Domain type hash should be deterministic for same program ID"
        );
        
        assert_eq!(
            domain_hash.len(), 32,
            "Domain type hash should be 32 bytes"
        );
    }

    #[test]
    fn test_function_type_hash_separation() {

        let fee_data_hash = compute_function_type_hash(FEE_DATA_TYPE_HASH_PREFIX);
        let batch_fee_data_hash = compute_function_type_hash(BATCH_FEE_DATA_TYPE_HASH_PREFIX);
        let fill_sign_params_hash = compute_function_type_hash(FILL_SIGN_PARAMS_TYPE_HASH_PREFIX);
        
        assert_ne!(
            fee_data_hash, batch_fee_data_hash,
            "FeeData and BatchFeeData should have different function type hashes"
        );
        assert_ne!(
            fee_data_hash, fill_sign_params_hash,
            "FeeData and FillSignParams should have different function type hashes"
        );
        assert_ne!(
            batch_fee_data_hash, fill_sign_params_hash,
            "BatchFeeData and FillSignParams should have different function type hashes"
        );
        
        // All hashes should be 32 bytes
        assert_eq!(fee_data_hash.len(), 32);
        assert_eq!(batch_fee_data_hash.len(), 32);
        assert_eq!(fill_sign_params_hash.len(), 32);
    }

    #[test]
    fn test_encoded_message_includes_type_hashes() {

        let program_id = Pubkey::new_unique();
        let test_data = vec![1u8, 2, 3, 4];
        
        let domain_type_hash = compute_domain_type_hash(&program_id);
        let function_type_hash = compute_function_type_hash(FEE_DATA_TYPE_HASH_PREFIX);
        
        let mut encoded_message = Vec::new();
        encoded_message.extend_from_slice(&domain_type_hash);
        encoded_message.extend_from_slice(&function_type_hash);
        encoded_message.extend_from_slice(&test_data);
        
        assert_eq!(
            &encoded_message[0..32], &domain_type_hash,
            "Encoded message should start with domain type hash"
        );
        
        assert_eq!(
            &encoded_message[32..64], &function_type_hash,
            "Encoded message should include function type hash after domain hash"
        );
        
        assert_eq!(
            &encoded_message[64..], &test_data,
            "Encoded message should end with serialized data"
        );
        
        assert_eq!(
            encoded_message.len(), 64 + test_data.len(),
            "Encoded message should have correct total length"
        );
    }

    #[test]
    fn test_type_hash_binding_prevents_cross_function_replay() {

        let program_id = Pubkey::new_unique();
        
        let fee_data_domain_hash = compute_domain_type_hash(&program_id);
        let fee_data_function_hash = compute_function_type_hash(FEE_DATA_TYPE_HASH_PREFIX);
        let test_data = vec![100u8, 200u8, 1, 2, 3];
        let mut fee_data_encoded = Vec::new();
        fee_data_encoded.extend_from_slice(&fee_data_domain_hash);
        fee_data_encoded.extend_from_slice(&fee_data_function_hash);
        fee_data_encoded.extend_from_slice(&test_data);
        
        let batch_domain_hash = compute_domain_type_hash(&program_id);
        let batch_function_hash = compute_function_type_hash(BATCH_FEE_DATA_TYPE_HASH_PREFIX);
        let mut batch_encoded = Vec::new();
        batch_encoded.extend_from_slice(&batch_domain_hash);
        batch_encoded.extend_from_slice(&batch_function_hash);
        batch_encoded.extend_from_slice(&test_data);
        
        assert_eq!(fee_data_domain_hash, batch_domain_hash);
        
        assert_ne!(fee_data_function_hash, batch_function_hash);
        
        assert_ne!(
            fee_data_encoded, batch_encoded,
            "Encoded messages for different functions should differ even with same data"
        );
    }
}
