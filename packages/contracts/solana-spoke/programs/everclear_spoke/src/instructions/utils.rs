use anchor_lang::prelude::*;
use anchor_lang::solana_program::program::invoke_signed;

use crate::error::SpokeError;
use crate::instructions::intent::{EVMEncode, EVMIntent};

pub(crate) fn normalize_decimals(
    amount: u128,
    minted_decimals: u8,
    target_decimals: u8,
) -> Result<u128> {
    match minted_decimals.cmp(&target_decimals) {
        // No scaling needed
        std::cmp::Ordering::Equal => Ok(amount),
        // e.g. minted_decimals=9, target_decimals=6 => downscale
        std::cmp::Ordering::Greater => {
            let shift = minted_decimals - target_decimals;
            // prevent potential divide-by-zero or overshoot
            if shift > 12 {
                // you might fail or just saturate for large differences
                return err!(SpokeError::DecimalConversionOverflow);
            };
            Ok(amount / u128::from(10u64.pow(shift as u32)))
        }
        // minted_decimals < target_decimals => upscale
        std::cmp::Ordering::Less => {
            let shift = target_decimals - minted_decimals;
            // watch for overflow if we do big multiplications
            let factor = 10u64
                .checked_pow(shift as u32)
                .ok_or(error!(SpokeError::DecimalConversionOverflow))?;
            let scaled = amount
                .checked_mul(u128::from(factor))
                .ok_or(error!(SpokeError::DecimalConversionOverflow))?;
            Ok(scaled)
        }
    }
}

/// Minimal keccak256 using the tiny_keccak crate.
fn keccak_256(data: &[u8]) -> [u8; 32] {
    use tiny_keccak::{Hasher, Keccak};
    let mut hasher = Keccak::v256();
    hasher.update(data);
    let mut output = [0u8; 32];
    hasher.finalize(&mut output);
    output
}

pub fn compute_intent_hash(intent: &EVMIntent) -> [u8; 32] {
    let encoded = intent.encode();
    keccak_256(&encoded)
}

pub fn hash_intent_id_array(intent_ids: &[[u8; 32]]) -> [u8; 32] {
    let mut bytes: Vec<u8> = Vec::with_capacity(intent_ids.len() * 32);
    for id in intent_ids {
        bytes.extend_from_slice(id);
    }
    keccak_256(&bytes)
}

pub fn create_or_claim_intent_status_pda<'info>(
    pda_payer: &AccountInfo<'info>,
    intent_status_pda: &AccountInfo<'info>,
    program_id: &Pubkey,
    space: usize,
    intent_id: &[u8; 32],
    intent_status_bump: u8,
) -> Result<()> {
    use anchor_lang::solana_program::{rent::Rent, system_instruction, system_program};
    use crate::intent_status_pda_seeds;

    let rent = Rent::get()?;
    let required_lamports = rent.minimum_balance(space);
    let existing_lamports = intent_status_pda.lamports();
    let account_owner = intent_status_pda.owner;
    let system_program_id = system_program::ID;
    let payer_seed = &["everclear_spoke".as_bytes(), "-".as_bytes(), "pda_payer".as_bytes()];
    let (_payer_pda, payer_pda_bump) = Pubkey::find_program_address(payer_seed, program_id);

    if existing_lamports == 0 {
        let create_transfer_ix =
            system_instruction::transfer(&pda_payer.key(), &intent_status_pda.key(), 1);
        invoke_signed(
            &create_transfer_ix,
            &[pda_payer.clone(), intent_status_pda.clone()],
            &[&["everclear_spoke".as_bytes(), "-".as_bytes(), "pda_payer".as_bytes(), &[payer_pda_bump]]],
        )?;
    }
    if account_owner == &system_program_id {
        let allocate_ix = system_instruction::allocate(&intent_status_pda.key(), space as u64);
        invoke_signed(
            &allocate_ix,
            &[intent_status_pda.clone()],
            &[intent_status_pda_seeds!(intent_id, intent_status_bump)],
        )?;
        let assign_ix = system_instruction::assign(&intent_status_pda.key(), program_id);
        invoke_signed(
            &assign_ix,
            &[intent_status_pda.clone()],
            &[intent_status_pda_seeds!(intent_id, intent_status_bump)],
        )?;
    }
    let current_lamports = intent_status_pda.lamports();
    if current_lamports < required_lamports {
        let transfer_lamports = required_lamports - current_lamports;
        let transfer_ix =
            system_instruction::transfer(&pda_payer.key(), &intent_status_pda.key(), transfer_lamports);
        invoke_signed(
            &transfer_ix,
            &[pda_payer.clone(), intent_status_pda.clone()],
            &[&["everclear_spoke".as_bytes(), "-".as_bytes(), "pda_payer".as_bytes(), &[payer_pda_bump]]],
        )?;
    }
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    use hex::FromHex;

    fn u128_to_u256_be(val: u128) -> [u8; 32] {
        let mut out = [0u8; 32];
        // copy val’s big-endian bytes into the last 8 bytes
        out[16..32].copy_from_slice(&val.to_be_bytes());
        out
    }

    #[test]
    fn test_compute_intent_hash() {
        // NOTE: this intent data is taken from actual intent from EVM
        let intent = EVMIntent {
            initiator: <[u8; 32]>::from_hex("00000000000000000000000065588b1121eb7dd41ba7d82a4f387548381584a9").unwrap(),
            receiver: <[u8; 32]>::from_hex("00000000000000000000000039096a17ba70fe5c1eddb923f940b2e6deae5c3b").unwrap(),
            input_asset: <[u8; 32]>::from_hex("000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913").unwrap(),
            output_asset: <[u8; 32]>::from_hex("00000000000000000000000094b008aa00579c1307b0ef2c499ad98a8ce58e58").unwrap(),
            origin: 8453,
            nonce: 168,
            timestamp: 1762404021,
            ttl: 7200,
            amount: u128_to_u256_be(422401000000000000),
            amount_out_min: u128_to_u256_be(422352),
            destinations: vec![10],
            data: vec![],
        };
        let intent_id = compute_intent_hash(&intent);
        assert_eq!(
            hex::encode(intent_id),
            "d6db7d3cefc524dc4717361e8b77c7cdca1f700971ae36c61823c17a38a7472a"
        );

        // NOTE: this is a made-up solana intent
        let solana_intent = EVMIntent {
            initiator: Pubkey::from_str_const("AUgefcX2VZq9v72gqXUg8rgUNxsbHV7RVWuw42yU4LyQ")
                .to_bytes(),
            receiver: Pubkey::from_str_const("1111111111113FiC6QTSLv7Up9gSeUwhPifXRCoH").to_bytes(),
            input_asset: Pubkey::from_str_const("EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v")
                .to_bytes(),
            output_asset: Pubkey::from_str_const("1111111111112q2Gg8TH19xwTZeyUCme313nZsTQ")
                .to_bytes(),
            origin: 1399811149,
            nonce: 35,
            timestamp: 1743782830,
            ttl: 0,
            amount: u128_to_u256_be(2000000000000000000),
            amount_out_min: u128_to_u256_be(0),
            destinations: vec![8453],
            data: vec![],
        };
        let intent_id = compute_intent_hash(&solana_intent);
        assert_eq!(
            hex::encode(intent_id),
            "8200900c8aa6b771a0cc3a6936d9313bfb9721f2506d4e6b884813c7f50db86e"
        );
    }
}
