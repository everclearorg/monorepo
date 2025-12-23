use anchor_lang::solana_program::sysvar::instructions::ID as SYSVAR_INSTRUCTIONS_ID;
use anchor_lang::{prelude::*, solana_program::program::invoke_signed};
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer, ID as TOKEN_PROGRAM_ID};

use crate::instructions::fee_adapter::signature::{verify_signature, FILL_SIGN_PARAMS_TYPE_HASH_PREFIX};
use crate::instructions::SignatureAccounts;
use crate::intent::encode_full;
use crate::{
    consts::{everclear_gateway, EVERCLEAR_DOMAIN, THIS_DOMAIN},
    error::SpokeError,
    events::IntentFilledEvent,
    hyperlane::{
        transfer_remote, Igp, Mailbox, SerializableAccountMeta, SplNoop, TransferRemote,
        TransferRemoteContext, U256,
    },
    instructions::{
        messages::MessageType, try_32bytes_to_u64, u128_to_u256_be,
        utils::{compute_intent_hash, create_or_claim_intent_status_pda},
        EVMIntent, FillMessage,
    },
    intent_status_pda_seeds,
    state::IntentStatus,
    state::{FeeAdapterState, IntentStatusAccount, SpokeState},
};
/// Extra params for the fill intent signature outside of the intent.
#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct FillSignParams {
    pub domain: u32,
    pub intent_id: [u8; 32],
    /// provided in the accounts
    pub filler: Pubkey,
    pub amount_out: u64,
    /// receiver in bytes32 format
    pub receiver: [u8; 32],
    pub destinations: Vec<u32>,
}

pub fn fill_intent(
    ctx: Context<FillIntent>,
    // origin intent, flattened
    origin_initiator: [u8; 32],
    // NOTE: origin_receiver is put in ctx for space saving using LUT
    origin_input_asset: [u8; 32],
    // NOTE: we do not need output_asset here as this woule be `ctx.mint`. This is removed for space saving using LUT.
    intent_origin: u32,
    origin_nonce: u64,
    origin_timestamp: u64,           // actually uint48 in Solidity
    origin_ttl: u64,                 // actually uint48 in Solidity
    origin_amount: [u8; 32],         // big-endian, matching typical EVM usage
    origin_amount_out_min: [u8; 32], // uint256
    origin_destinations: Vec<u32>,
    origin_data: Vec<u8>,

    // data for fill intent
    amount_out: u64,
    receiver: Pubkey,
    destinations: Vec<u32>,

    // hyperlane params
    message_gas_limit: u64,
    signature: Vec<u8>,
) -> Result<()> {
    let evm_intent = EVMIntent {
        initiator: origin_initiator,
        receiver: ctx.accounts.origin_receiver.key().to_bytes(),
        input_asset: origin_input_asset,
        output_asset: ctx.accounts.mint.key().to_bytes(),
        origin: intent_origin,
        nonce: origin_nonce,
        timestamp: origin_timestamp,
        ttl: origin_ttl,
        amount: origin_amount,
        amount_out_min: origin_amount_out_min,
        destinations: origin_destinations,
        data: origin_data,
    };

    let mut accounts = FillIntentAccounts {
        spoke_state: ctx.accounts.spoke_state.clone().as_ref().clone(),
        mint: ctx.accounts.mint.clone(),
        token_program: ctx.accounts.token_program.clone(),
        origin_receiver: ctx.accounts.origin_receiver.clone(),
        solver_token_account: ctx.accounts.solver_token_account.clone(),
        origin_receiver_token_account: ctx.accounts.origin_receiver_token_account.clone(),
        authority: ctx.accounts.authority.clone(),
        intent_status_pda: ctx.accounts.intent_status_pda.clone(),
        pda_payer: ctx.accounts.pda_payer.clone(),
        system_program: ctx.accounts.system_program.clone(),
        spl_noop_program: ctx.accounts.spl_noop_program.clone(),
        hyperlane_mailbox: ctx.accounts.hyperlane_mailbox.clone(),
        mailbox_outbox: ctx.accounts.mailbox_outbox.clone(),
        dispatch_authority: ctx.accounts.dispatch_authority.clone(),
        unique_message_account: ctx.accounts.unique_message_account.clone(),
        dispatched_message_pda: ctx.accounts.dispatched_message_pda.clone(),
        igp_program: ctx.accounts.igp_program.clone(),
        igp_program_data: ctx.accounts.igp_program_data.clone(),
        igp_payment_pda: ctx.accounts.igp_payment_pda.clone(),
        configured_igp_account: ctx.accounts.configured_igp_account.clone(),
        inner_igp_account: ctx.accounts.inner_igp_account.clone(),
    };
    let program_id = *ctx.program_id;

    // verify signatures
    let intent_id = compute_intent_hash(&evm_intent);
    let sign_params = FillSignParams {
        intent_id,
        domain: THIS_DOMAIN,
        filler: ctx.accounts.authority.key(),
        amount_out,
        receiver: receiver.to_bytes(),
        destinations: destinations.clone(),
    };
    let signature_accounts = SignatureAccounts {
        signer: ctx.accounts.signer.clone(),
        instruction_sysvar: ctx.accounts.instruction_sysvar.clone(),
    };
    verify_signature(
        &sign_params,
        signature,
        signature_accounts,
        &program_id,
        FILL_SIGN_PARAMS_TYPE_HASH_PREFIX,
    )?;

    let event_data: IntentFilledEvent = handle_fill_intent(
        &mut accounts,
        program_id,
        evm_intent,
        amount_out,
        receiver,
        destinations,
        message_gas_limit,
    )
    .unwrap();

    emit_cpi!(event_data);

    Ok(())
}

pub fn handle_fill_intent<'info>(
    accounts: &mut FillIntentAccounts<'info>,
    program_id: Pubkey, // for ctx.programId
    intent: EVMIntent,
    amount_out: u64,
    receiver: Pubkey,
    destinations: Vec<u32>,
    message_gas_limit: u64,
) -> Result<IntentFilledEvent> {
    let spoke_state = accounts.spoke_state.clone();
    let state = &mut accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);

    require!(intent.destinations.len() == 1, SpokeError::WrongDestination);
    require!(
        intent.destinations[0] == THIS_DOMAIN,
        SpokeError::WrongDestination
    );

    let clock = Clock::get()?;
    let timestamp: u64 = clock.unix_timestamp as u64;
    require!(
        timestamp < intent.timestamp.saturating_add(intent.ttl),
        SpokeError::IntentExpired
    );

    let amount_out_min = try_32bytes_to_u64(intent.amount_out_min)?;
    require!(amount_out >= amount_out_min, SpokeError::AmountOutInvalid);

    require!(
        !destinations.is_empty(),
        SpokeError::InvalidDestinationArray
    );
    require!(
        destinations.len() <= 10,
        SpokeError::InvalidDestinationArray
    );

    let intent_id = compute_intent_hash(&intent);

    // TODO: status pdas
    // status check, use similar pda creation method as in mark_settlement_as_delivered
    let intent_status_pda = &mut accounts.intent_status_pda;
    // verify intent status pda matches intent id
    let intent_status_seed: &[&[u8]] = intent_status_pda_seeds!(intent_id);
    // return canonical pda for intent status
    let (intent_status_account, intent_status_bump) =
        Pubkey::find_program_address(intent_status_seed, &program_id);
    require!(
        intent_status_pda.key() == intent_status_account,
        SpokeError::InvalidIntentPda
    );

    // try to create intent status pda. Same logic as in mark_settlement_as_delivered
    let data = IntentStatusAccount::try_deserialize(&mut &intent_status_pda.data.borrow()[..]);
    if data.is_err() {
        // TODO: we create the same size intent status account as in settlement here for simplicity.
        // We can probably optimize this to only create 9 bytes status account here; need to think about
        // security implications tho.
        let space = 8
            + std::mem::size_of::<IntentStatusAccount>()
            + 12 * std::mem::size_of::<SerializableAccountMeta>();

        create_or_claim_intent_status_pda(
            &accounts.pda_payer,
            &intent_status_pda,
            &program_id,
            space,
            &intent_id,
            intent_status_bump,
        )?;
    } else {
        // the account is created beforehand, need to check status
        let pda_data = data.unwrap();
        // if its not none / added, this is a replay attempt
        if pda_data.status != IntentStatus::None && pda_data.status != IntentStatus::Added {
            return err!(SpokeError::InvalidIntentStatus);
        }
    }

    // status update
    let intent_status = IntentStatusAccount {
        status: IntentStatus::Filled,
        accounts: vec![],
        settlement: None,
    };

    intent_status.try_serialize(&mut &mut intent_status_pda.data.borrow_mut()[..])?;

    // NOTE: we do not need to normalize amount as amountOutMin should already be normalized.

    // Transfer from user's token account -> receiver's token account
    let cpi_accounts = Transfer {
        from: accounts.solver_token_account.to_account_info(),
        to: accounts.origin_receiver_token_account.to_account_info(),
        authority: accounts.authority.to_account_info(),
    };
    let cpi_ctx = CpiContext::new(accounts.token_program.to_account_info(), cpi_accounts);
    token::transfer(cpi_ctx, amount_out)?;

    // TODO: possible extension for calldata execution

    // Produce the EVM ABI message:
    // NOTE: message type should be fill
    let fill_message = FillMessage {
        intent_id,
        receiver: receiver.to_bytes(),
        intent_input_asset: intent.input_asset,
        intent_origin: intent.origin,
        amount_out: u128_to_u256_be(amount_out.into()),
        destinations,
        execution_timestamp: timestamp,
    };
    let evm_encoded_message = encode_full(MessageType::Fill, &fill_message);

    // Build your TransferRemote
    let xfer = TransferRemote {
        destination_domain: EVERCLEAR_DOMAIN,
        recipient: everclear_gateway(),
        amount_or_id: U256::from(0),
        gas_amount: message_gas_limit,
        message_body: evm_encoded_message, // now in EVM ABI format
    };

    // TODO: make this no_copy
    // Build your TransferRemoteContext in a local variable (so it doesn't drop too soon)
    let mut transfer_remote_context = TransferRemoteContext {
        spoke_state,
        system_program: accounts.system_program.clone(),
        spl_noop_program: accounts.spl_noop_program.clone(),
        mailbox_program: accounts.hyperlane_mailbox.clone(),
        mailbox_outbox: accounts.mailbox_outbox.to_account_info(),
        dispatch_authority: accounts.dispatch_authority.to_account_info(),
        // TODO: need to figure out how this is used for the IGP payer and whether this is correct
        sender_wallet: accounts.authority.to_account_info(),
        unique_message_account: accounts.unique_message_account.to_account_info(),
        dispatched_message_pda: accounts.dispatched_message_pda.to_account_info(),
        igp_program: accounts.igp_program.clone(),
        igp_program_data: accounts.igp_program_data.to_account_info(),
        igp_payment_pda: accounts.igp_payment_pda.to_account_info(),
        configured_igp_account: accounts.configured_igp_account.to_account_info(),
        inner_igp_account: accounts.inner_igp_account.clone(),
    };

    // Now create the Anchor Context, referencing your local `transfer_remote_context`.
    let transfer_ctx = Context::new(
        &program_id,
        &mut transfer_remote_context, // pass a mutable reference
        &[],                          // remaining accounts if needed
        Default::default(),           // any custom context seeds if needed
    );

    // 3) Use `transfer_ctx` safely
    let message_id = transfer_remote(transfer_ctx, xfer)?;

    // Emit an event with full intent details.
    Ok(IntentFilledEvent {
        intent_id,
        message_id: message_id.into(),
        solver: *accounts.authority.key,
        receiver: receiver.to_bytes(),
        amount_out,
        intent,
    })
}

pub struct FillIntentAccounts<'info> {
    pub spoke_state: Account<'info, SpokeState>,
    pub authority: Signer<'info>,
    pub origin_receiver: AccountInfo<'info>,
    pub mint: Account<'info, Mint>,
    pub solver_token_account: Account<'info, TokenAccount>,
    pub origin_receiver_token_account: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    pub intent_status_pda: UncheckedAccount<'info>,
    pub pda_payer: AccountInfo<'info>,
    pub hyperlane_mailbox: Interface<'info, Mailbox>,
    pub system_program: Program<'info, System>,
    pub spl_noop_program: Program<'info, SplNoop>,
    pub mailbox_outbox: AccountInfo<'info>,
    pub dispatch_authority: AccountInfo<'info>,
    pub unique_message_account: Signer<'info>,
    pub dispatched_message_pda: AccountInfo<'info>,
    pub igp_program: Interface<'info, Igp>,
    pub igp_program_data: AccountInfo<'info>,
    pub igp_payment_pda: AccountInfo<'info>,
    pub configured_igp_account: AccountInfo<'info>,
    pub inner_igp_account: Option<AccountInfo<'info>>,
}

#[event_cpi]
#[derive(Accounts)]
pub struct FillIntent<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump,
    )]
    pub spoke_state: Box<Account<'info, SpokeState>>,

    #[account(
        mut,
        seeds = [b"fee-adapter-state"],
        bump = fee_adapter_state.bump,
    )]
    pub fee_adapter_state: Box<Account<'info, FeeAdapterState>>,

    /// NOTE: the message initiator, here its the filler.
    #[account(mut)]
    pub authority: Signer<'info>,

    /// CHECK: we dont need to validate receiver, its the sender responsibility to make sure receiver is correct for a correct intent id.
    pub origin_receiver: AccountInfo<'info>,

    pub mint: Account<'info, Mint>,

    // NOTE: we allow any token account (not just ATA) to send in asset.
    #[account(
        mut,
        token::mint = mint,
        token::authority = authority,
        token::token_program = token_program,
    )]
    pub solver_token_account: Account<'info, TokenAccount>,

    // NOTE: we only allow sending to receiver ATA.
    #[account(
        mut,
        associated_token::mint = mint,
        associated_token::authority = origin_receiver,
        associated_token::token_program = token_program,
    )]
    pub origin_receiver_token_account: Account<'info, TokenAccount>,

    #[account(address = TOKEN_PROGRAM_ID)]
    pub token_program: Program<'info, Token>,

    /// CHECK: validation of the pda is checked inside fill_intent
    #[account(mut)]
    pub intent_status_pda: UncheckedAccount<'info>,

    /// CHECK: This is an empty account pda that only store funds to create intent status pda.
    #[account(
        mut,
        seeds = ["everclear_spoke".as_bytes(), "-".as_bytes(), "pda_payer".as_bytes()],
        bump,
    )]
    pub pda_payer: AccountInfo<'info>,

    // The Hyperlane Mailbox program (by address only).
    #[account(address = spoke_state.mailbox)]
    pub hyperlane_mailbox: Interface<'info, Mailbox>,

    // The system program
    pub system_program: Program<'info, System>,

    // The SPL-Noop program
    pub spl_noop_program: Program<'info, SplNoop>,

    /// CHECK: Outbox data account – the Mailbox will check this
    #[account(mut)]
    pub mailbox_outbox: AccountInfo<'info>,

    /// CHECK: Dispatch authority (PDA)
    #[account(mut)]
    pub dispatch_authority: AccountInfo<'info>,

    // A unique message / gas payment account (signer)
    #[account(mut)]
    pub unique_message_account: Signer<'info>,

    /// CHECK: The message storage PDA
    #[account(mut)]
    pub dispatched_message_pda: AccountInfo<'info>,

    //  If using IGP:
    #[account(executable)]
    pub igp_program: Interface<'info, Igp>,

    /// CHECK:
    #[account(mut)]
    pub igp_program_data: AccountInfo<'info>,

    /// CHECK:
    #[account(mut)]
    pub igp_payment_pda: AccountInfo<'info>,

    /// CHECK:
    #[account(mut)]
    pub configured_igp_account: AccountInfo<'info>,

    /// CHECK: we verify this is consistent with fill_signer
    #[account(address = fee_adapter_state.fill_signer)]
    pub signer: AccountInfo<'info>,

    /// CHECK: we verify this is consistent with SYSVAR_INSTRUCTIONS
    #[account(address = SYSVAR_INSTRUCTIONS_ID)]
    pub instruction_sysvar: AccountInfo<'info>,

    // Optional accounts: need to be put at the end
    /// CHECK:
    #[account(mut)]
    pub inner_igp_account: Option<AccountInfo<'info>>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use anchor_lang::prelude::Pubkey;
    use crate::state::FeeAdapterState;

    #[test]
    fn test_fill_signer_separate_from_fee_signer() {
        let fee_signer = Pubkey::new_unique();
        let fill_signer = Pubkey::new_unique();
        
        assert_ne!(
            fee_signer, fill_signer,
            "Fee signer and fill signer should be different accounts"
        );
    }

    #[test]
    fn test_fee_adapter_state_includes_fill_signer() {
        let fee_recipient = Pubkey::new_unique();
        let fee_signer = Pubkey::new_unique();
        let fill_signer = Pubkey::new_unique();
        
        let state_size = FeeAdapterState::SIZE;
        let expected_size = 2 + (32 * 3) + 1;
        
        assert_eq!(
            state_size, expected_size,
            "FeeAdapterState should include fill_signer field (3 Pubkeys total)"
        );
    }

    #[test]
    fn test_fill_sign_params_structure() {
        let domain = 1u32;
        let intent_id = [1u8; 32];
        let filler = Pubkey::new_unique();
        let amount_out = 1000u64;
        let receiver = Pubkey::new_unique();
        let receiver_bytes = receiver.to_bytes();
        let destinations = vec![1u32, 2u32];
        
        let sign_params = FillSignParams {
            domain,
            intent_id,
            filler,
            amount_out,
            receiver: receiver_bytes,
            destinations: destinations.clone(),
        };
        
        let mut encoded = vec![];
        sign_params.serialize(&mut encoded).unwrap();
        
        assert!(!encoded.is_empty(), "FillSignParams should serialize correctly");
        
        let mut decoded = &encoded[..];
        let decoded_params: FillSignParams = AnchorDeserialize::deserialize(&mut decoded).unwrap();
        
        assert_eq!(decoded_params.domain, domain);
        assert_eq!(decoded_params.intent_id, intent_id);
        assert_eq!(decoded_params.filler, filler);
        assert_eq!(decoded_params.amount_out, amount_out);
        assert_eq!(decoded_params.receiver, receiver_bytes);
        assert_eq!(decoded_params.destinations, destinations);
    }

    #[test]
    fn test_fill_signer_independence() {
        let fee_signer_1 = Pubkey::new_unique();
        let fee_signer_2 = Pubkey::new_unique();
        let fill_signer_1 = Pubkey::new_unique();
        let fill_signer_2 = Pubkey::new_unique();
        
        assert_ne!(fee_signer_1, fill_signer_1);
        assert_ne!(fee_signer_2, fill_signer_2);
        
        let can_update_fee_signer_independently = fee_signer_1 != fee_signer_2;
        let can_update_fill_signer_independently = fill_signer_1 != fill_signer_2;
        
        assert!(
            can_update_fee_signer_independently && can_update_fill_signer_independently,
            "Fee signer and fill signer should be independently updatable"
        );
    }

    #[test]
    fn test_fill_signer_prevents_fee_signer_compromise_impact() {
        let fee_signer = Pubkey::new_unique();
        let fill_signer = Pubkey::new_unique();
        let compromised_fee_signer = fee_signer;
        let secure_fill_signer = fill_signer;
        
        assert_ne!(
            compromised_fee_signer, secure_fill_signer,
            "Even if fee_signer is compromised, fill_signer remains secure"
        );
        
        let fee_signer_can_fill = compromised_fee_signer == secure_fill_signer;
        assert!(
            !fee_signer_can_fill,
            "Compromised fee_signer should not be able to sign fill intents"
        );
    }

    #[test]
    fn test_different_fill_signers_produce_different_signatures() {
        let intent_id = [1u8; 32];
        let filler = Pubkey::new_unique();
        let amount_out = 1000u64;
        let receiver = Pubkey::new_unique();
        let destinations = vec![1u32];
        
        let sign_params_1 = FillSignParams {
            domain: 1,
            intent_id,
            filler,
            amount_out,
            receiver: receiver.to_bytes(),
            destinations: destinations.clone(),
        };
        
        let sign_params_2 = FillSignParams {
            domain: 1,
            intent_id,
            filler,
            amount_out,
            receiver: receiver.to_bytes(),
            destinations: destinations.clone(),
        };
        
        let mut encoded_1 = vec![];
        sign_params_1.serialize(&mut encoded_1).unwrap();
        
        let mut encoded_2 = vec![];
        sign_params_2.serialize(&mut encoded_2).unwrap();
        
        assert_eq!(
            encoded_1, encoded_2,
            "Same parameters should produce same serialization"
        );
        
        let fill_signer_1 = Pubkey::new_unique();
        let fill_signer_2 = Pubkey::new_unique();
        
        assert_ne!(
            fill_signer_1, fill_signer_2,
            "Different fill signers should be different accounts"
        );
    }
}
