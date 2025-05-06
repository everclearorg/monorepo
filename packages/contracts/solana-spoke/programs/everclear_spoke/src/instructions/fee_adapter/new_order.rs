use anchor_lang::prelude::*;

use crate::error::SpokeError;
use crate::events::OrderCreated;
use crate::instructions::{new_intent, NewIntent};
use crate::types::OrderParameters;
use crate::intent::{EVMIntent, u128_to_u256_be};
use crate::utils::{ compute_intent_hash, normalize_decimals};
use crate::consts::{DEFAULT_NORMALIZED_DECIMALS};

/// Batch-create multiple intents and handle fees.
pub fn new_order(
    ctx: Context<NewIntent>,
    fee: u64,
    deadline: i64,
    sig: Vec<u8>,
    params: Vec<OrderParameters>,
) -> Result<()> {
    // 1) Validate inputs
    require!(!params.is_empty(), SpokeError::EmptyParams);
    let asset = params[0].input_asset;
    for p in &params {
        require!(p.input_asset == asset, SpokeError::MultipleOrderAssets);
    }

    // handle_fees(&ctx, fee, asset, deadline, sig)?; yet to implement

    let accounts = &ctx.accounts;
    let state = &mut accounts.spoke_state;
   
    let mut intent_ids: Vec<[u8; 32]> = Vec::with_capacity(params.len());
    for p in &params {
        new_intent(
            ctx.clone(),
            p.receiver,
            p.input_asset,
            p.output_asset,
            p.amount,
            p.max_fee,
            p.ttl,
            p.destinations.clone(),
            p.data.clone(),
            p.message_gas_limit,
        )?;

        // Recompute intent ID exactly as in new_intent
        let minted_decimals = ctx.accounts.mint.decimals;
        let normalized_amt = normalize_decimals(
            p.amount as u128,
            minted_decimals,
            DEFAULT_NORMALIZED_DECIMALS,
        )?;
        let clock = Clock::get()?;
        let evm_intent = EVMIntent {
            initiator: ctx.accounts.authority.key().to_bytes(),
            receiver: p.receiver.to_bytes(),
            input_asset: p.input_asset.to_bytes(),
            output_asset: p.output_asset.to_bytes(),
            max_fee: p.max_fee,
            origin: ctx.accounts.spoke_state.domain,
            nonce: ctx.accounts.spoke_state.nonce,
            timestamp: clock.unix_timestamp as u64,
            ttl: p.ttl,
            amount: u128_to_u256_be(normalized_amt),
            destinations: p.destinations.clone(),
            data: p.data.clone(),
        };
        let intent_id = compute_intent_hash(&evm_intent);
        intent_ids.push(intent_id);
    }

    // 4) Derive order ID and emit event
    let order_id = compute_intent_hash(
        &intent_ids.iter().map(|id| id.as_ref()).collect::<Vec<_>>(),
    );
    emit!(OrderCreated {
        order_id,
        user: ctx.accounts.authority.key().to_bytes(),
        intent_ids: intent_ids.clone(),
        fee,
        native_value: ctx.accounts.authority.lamports(),
    });

    Ok(())
}





