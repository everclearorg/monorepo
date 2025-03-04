use anchor_lang::prelude::*;

use crate::error::SpokeError;

use crate::intent::Intent;

pub(crate) fn vault_authority_seeds(
    program_id: &Pubkey,
    mint_pubkey: &Pubkey,
    bump: u8,
) -> [Vec<u8>; 4] {
    [
        b"vault".to_vec(),
        mint_pubkey.to_bytes().to_vec(),
        program_id.to_bytes().to_vec(),
        vec![bump],
    ]
}

pub(crate) fn normalize_decimals(
    amount: u64,
    minted_decimals: u8,
    target_decimals: u8,
) -> Result<u64> {
    if minted_decimals == target_decimals {
        // No scaling needed
        Ok(amount)
    } else if minted_decimals > target_decimals {
        // e.g. minted_decimals=9, target_decimals=6 => downscale
        let shift = minted_decimals - target_decimals;
        // prevent potential divide-by-zero or overshoot
        if shift > 12 {
            // you might fail or just saturate for large differences
            return err!(SpokeError::DecimalConversionOverflow);
        }
        Ok(amount / 10u64.pow(shift as u32))
    } else {
        // minted_decimals < target_decimals => upscale
        let shift = target_decimals - minted_decimals;
        // watch for overflow if we do big multiplications
        let factor = 10u64
            .checked_pow(shift as u32)
            .ok_or(error!(SpokeError::DecimalConversionOverflow))?;
        let scaled = amount
            .checked_mul(factor)
            .ok_or(error!(SpokeError::DecimalConversionOverflow))?;
        Ok(scaled)
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

pub(crate) fn compute_intent_hash(intent: &Intent) -> [u8; 32] {
    let mut hasher_input = Vec::new();

    // 1) Initiator
    hasher_input.extend_from_slice(intent.initiator.as_ref());

    // 2) Receiver
    hasher_input.extend_from_slice(intent.receiver.as_ref());

    // 3) InputAsset
    hasher_input.extend_from_slice(intent.input_asset.as_ref());

    // 4) OutputAsset
    hasher_input.extend_from_slice(intent.output_asset.as_ref());

    // 5) maxFee
    hasher_input.extend_from_slice(&intent.max_fee.to_be_bytes());

    // 6) originDomain
    hasher_input.extend_from_slice(&intent.origin_domain.to_be_bytes());

    // 7) nonce
    hasher_input.extend_from_slice(&intent.nonce.to_be_bytes());

    // 8) timestamp
    hasher_input.extend_from_slice(&intent.timestamp.to_be_bytes());

    // 9) ttl
    hasher_input.extend_from_slice(&intent.ttl.to_be_bytes());

    // 10) normalizedAmount
    hasher_input.extend_from_slice(&intent.normalized_amount.to_be_bytes());

    // 11) destinations (Borsh or plain "Vec<u8>" for them).
    //    If you want raw 4-byte concatenation for each, do it manually:
    //    for d in intent.destinations.iter() { hasher_input.extend_from_slice(&d.to_be_bytes()); }
    //
    //    Or, if your original code used `.try_to_vec()`, replicate that:
    //    let encoded_dest = intent.destinations.try_to_vec().unwrap();
    let encoded_dest = intent.destinations.try_to_vec().unwrap();
    hasher_input.extend_from_slice(&encoded_dest);

    // 12) data
    hasher_input.extend_from_slice(&intent.data);

    // 13) Return keccak256
    keccak_256(&hasher_input)
}
