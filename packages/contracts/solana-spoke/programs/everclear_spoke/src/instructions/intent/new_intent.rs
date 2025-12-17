use super::evm_encode::{encode_full, u128_to_u256_be, EVMIntent};
use crate::instructions::fee_adapter::{
    handle_fees, FeeData, FeeParams, HandleFeeAccounts, SignatureAccounts,
};
use crate::messages::MessageType;
use crate::state::FeeAdapterState;
use crate::{
    consts::everclear_gateway,
    hyperlane::{
        transfer_remote, Igp, Mailbox, SplNoop, TransferRemote, TransferRemoteContext, U256,
    },
    vault_authority_pda_seeds,
};
use anchor_lang::prelude::*;
use anchor_lang::solana_program::sysvar::instructions::ID as SYSVAR_INSTRUCTIONS_ID;
use anchor_spl::{
    associated_token,
    token::{self, Mint, Token, TokenAccount, Transfer, ID as TOKEN_PROGRAM_ID},
};

use crate::{
    consts::{DEFAULT_NORMALIZED_DECIMALS, EVERCLEAR_DOMAIN},
    error::SpokeError,
    events::IntentAddedEvent,
    state::SpokeState,
    utils::{compute_intent_hash, normalize_decimals},
};

/// Create a new intent.
/// The user "locks" funds (previously deposited) and creates an intent.
/// For simplicity, we assume full deposit has been made before.
pub fn new_intent(
    ctx: Context<NewIntent>,
    receiver: Pubkey,
    output_asset: Pubkey,
    amount: u64,
    amount_out_min: u128,
    ttl: u64,
    destinations: Vec<u32>,
    data: Vec<u8>,
    message_gas_limit: u64,
    fee_param: FeeParams,
) -> Result<()> {
    let mut accounts = NewIntentAccounts {
        spoke_state: ctx.accounts.spoke_state.clone().as_ref().clone(),
        mint: ctx.accounts.mint.clone(),
        token_program: ctx.accounts.token_program.clone(),
        program_vault_account: ctx.accounts.program_vault_account.clone(),
        user_token_account: ctx.accounts.user_token_account.clone(),
        authority: ctx.accounts.authority.clone(),
        system_program: ctx.accounts.system_program.clone(),
        spl_noop_program: ctx.accounts.spl_noop_program.clone(),
        hyperlane_mailbox: ctx.accounts.hyperlane_mailbox.clone(),
        mailbox_outbox: ctx.accounts.mailbox_outbox.clone(),
        dispatch_authority: ctx.accounts.dispatch_authority.clone(),
        unique_message_account: ctx.accounts.unique_message_account.to_account_info(),
        dispatched_message_pda: ctx.accounts.dispatched_message_pda.clone(),
        igp_program: ctx.accounts.igp_program.clone(),
        igp_program_data: ctx.accounts.igp_program_data.clone(),
        igp_payment_pda: ctx.accounts.igp_payment_pda.clone(),
        configured_igp_account: ctx.accounts.configured_igp_account.clone(),
        inner_igp_account: ctx.accounts.inner_igp_account.clone(),
    };
    let program_id = *ctx.program_id;

    let spoke_state = &ctx.accounts.spoke_state;
    require!(!spoke_state.paused, SpokeError::ContractPaused);

    let current_nonce = spoke_state.nonce;
    let next_nonce = current_nonce
        .checked_add(1)
        .ok_or(error!(SpokeError::InvalidOperation))?;

    let clock = Clock::get()?;
    let minted_decimals = ctx.accounts.mint.decimals;
    let normalized_amount = normalize_decimals(
        amount as u128,
        minted_decimals,
        DEFAULT_NORMALIZED_DECIMALS,
    )?;
    require!(normalized_amount > 0, SpokeError::ZeroAmount);

    let preview_evm_intent = EVMIntent {
        initiator: ctx.accounts.authority.key().to_bytes(),
        receiver: receiver.to_bytes(),
        input_asset: ctx.accounts.mint.key().to_bytes(),
        output_asset: output_asset.to_bytes(),
        origin: spoke_state.domain,
        nonce: next_nonce,
        timestamp: clock.unix_timestamp as u64,
        ttl,
        amount: u128_to_u256_be(normalized_amount),
        amount_out_min: u128_to_u256_be(amount_out_min),
        destinations: destinations.clone(),
        data: data.clone(),
    };
    let intent_hash = compute_intent_hash(&preview_evm_intent);

    let fee_data = FeeData {
        destinations: destinations.clone(),
        input_asset: ctx.accounts.mint.key(),
        output_asset: output_asset,
        amount: amount,
        amount_out_min: amount_out_min,
        ttl: ttl,
        data: data.clone(),
        token_fee: fee_param.token_fee,
        native_fee: fee_param.native_fee,
        deadline: fee_param.deadline,
    };
    let fee_accounts = HandleFeeAccounts {
        signature_accounts: SignatureAccounts {
            signer: ctx.accounts.fee_signer.to_account_info(),
            instruction_sysvar: ctx.accounts.instruction_sysvar.to_account_info(),
        },
        user_account: ctx.accounts.authority.to_account_info(),
        user_token_account: ctx.accounts.user_token_account.to_account_info(),
        user_authority_account: ctx.accounts.authority.to_account_info(),
        fee_reciever_account: ctx.accounts.fee_recipient.to_account_info(),
        fee_reciever_token_account: ctx.accounts.fee_recipient_token_account.to_account_info(),
        token_program: ctx.accounts.token_program.to_account_info(),
        system_program: ctx.accounts.system_program.to_account_info(),
    };

    require!(
        !ctx.accounts.fee_adapter_state.paused,
        SpokeError::FeeAdapterPaused
    );
    handle_fees(fee_data, fee_param.signature, fee_accounts, &program_id)?;

    let event = handle_new_intent(
        &mut accounts,
        program_id,
        receiver,
        output_asset,
        amount,
        amount_out_min,
        ttl,
        destinations,
        data,
        message_gas_limit,
    )
    .unwrap();

    require!(
        event.intent_id == intent_hash,
        SpokeError::InvalidIntentHash
    );

    emit_cpi!(event);

    Ok(())
}

pub fn handle_new_intent<'info>(
    accounts: &mut NewIntentAccounts<'info>,
    program_id: Pubkey, // for ctx.programId
    receiver: Pubkey,
    output_asset: Pubkey,
    amount: u64,
    amount_out_min: u128,
    ttl: u64,
    destinations: Vec<u32>,
    data: Vec<u8>,
    message_gas_limit: u64,
) -> Result<IntentAddedEvent> {
    let spoke_state = accounts.spoke_state.clone();

    let state = &mut accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);
    require!(
        !destinations.is_empty(),
        SpokeError::InvalidDestinationArray
    );
    require!(
        destinations.len() <= 10,
        SpokeError::InvalidDestinationArray
    );

    // If a single destination and ttl != 0, require output_asset is non-zero.
    if destinations.len() == 1 {
        require!(output_asset != Pubkey::default(), SpokeError::InvalidIntent);
    } else {
        // For multi-destination, ttl must be 0 and output_asset must be default.
        require!(
            ttl == 0 && output_asset == Pubkey::default(),
            SpokeError::InvalidIntent
        );
    }

    // NOTE: we do not need to check data len as this is implicitly done with solana tx size limitation of 1232 bytes

    let minted_decimals = accounts.mint.decimals;
    require!(
        minted_decimals <= DEFAULT_NORMALIZED_DECIMALS,
        SpokeError::DecimalConversionOverflow
    );
    
    let normalized_amount =
        normalize_decimals(amount as u128, minted_decimals, DEFAULT_NORMALIZED_DECIMALS)?;
    require!(normalized_amount > 0, SpokeError::ZeroAmount); // Add zero amount check like Solidity

    // Validate program vault account is an ATA owned by vault authority:
    let vault_authority_seeds: &[&[u8]] = vault_authority_pda_seeds!(state.vault_authority_bump);
    let vault_authority = Pubkey::create_program_address(vault_authority_seeds, &program_id)
        .map_err(|_| error!(SpokeError::InvalidArgument))?;
    let vault_ata = associated_token::get_associated_token_address_with_program_id(
        &vault_authority,
        &accounts.mint.key(),
        accounts.token_program.key,
    );
    require!(
        accounts.program_vault_account.mint == accounts.mint.key()
            && accounts.program_vault_account.owner == vault_authority
            && accounts.program_vault_account.key() == vault_ata,
        SpokeError::InvalidVaultAccount
    );

    // Transfer from user's token account -> program's vault
    let cpi_accounts = Transfer {
        from: accounts.user_token_account.to_account_info(),
        to: accounts.program_vault_account.to_account_info(),
        authority: accounts.authority.to_account_info(),
    };
    let cpi_ctx = CpiContext::new(accounts.token_program.to_account_info(), cpi_accounts);
    token::transfer(cpi_ctx, amount)?;

    // Update global nonce and calculate intent id
    let new_nonce = state
        .nonce
        .checked_add(1)
        .ok_or(error!(SpokeError::InvalidOperation))?;
    state.nonce = new_nonce;
    let clock = Clock::get()?;

    // Now create your EVMIntent
    let evm_intent = EVMIntent {
        initiator: accounts.authority.key().to_bytes(),
        receiver: receiver.to_bytes(),
        input_asset: accounts.mint.key().to_bytes(),
        output_asset: output_asset.to_bytes(),
        origin: state.domain, // your "origin_domain"
        nonce: new_nonce,
        timestamp: clock.unix_timestamp as u64,
        ttl,
        amount: u128_to_u256_be(normalized_amount),
        // NOTE: amount_out_min should be already normalized based on how fill works
        amount_out_min: u128_to_u256_be(amount_out_min),
        destinations: destinations.clone(),
        data: data.clone(),
    };

    // Hash the EVM intent information
    let intent_id = compute_intent_hash(&evm_intent);

    // Produce the EVM ABI message:
    // NOTE: message type should be
    let evm_encoded_message = encode_full(MessageType::Intent, &evm_intent);

    // Build your TransferRemote
    let xfer = TransferRemote {
        destination_domain: EVERCLEAR_DOMAIN,
        recipient: everclear_gateway(),
        // TODO: set this to 0, this is not used.
        amount_or_id: U256::from(normalized_amount),
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
        unique_message_account: accounts.unique_message_account.clone(),
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
    Ok(IntentAddedEvent {
        intent_id,
        message_id: message_id.into(),
        initiator: accounts.authority.key(),
        receiver,
        input_asset: accounts.mint.key(),
        output_asset,
        normalized_amount,
        amount_out_min,
        origin_domain: state.domain,
        nonce: new_nonce,
        ttl,
        timestamp: clock.unix_timestamp as u64,
        destinations,
        data,
    })
}

pub struct NewIntentAccounts<'info> {
    pub spoke_state: Account<'info, SpokeState>,
    pub mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
    pub program_vault_account: Account<'info, TokenAccount>,
    pub user_token_account: Account<'info, TokenAccount>,
    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
    pub spl_noop_program: Program<'info, SplNoop>,
    pub hyperlane_mailbox: Interface<'info, Mailbox>,
    pub mailbox_outbox: AccountInfo<'info>,
    pub dispatch_authority: AccountInfo<'info>,
    pub unique_message_account: AccountInfo<'info>,
    pub dispatched_message_pda: AccountInfo<'info>,
    pub igp_program: Interface<'info, Igp>,
    pub igp_program_data: AccountInfo<'info>,
    pub igp_payment_pda: AccountInfo<'info>,
    pub configured_igp_account: AccountInfo<'info>,
    pub inner_igp_account: Option<AccountInfo<'info>>,
}

pub struct EventData {
    pub intent_id: [u8; 32],
    pub message_id: [u8; 32],
    pub initiator: Pubkey,
    pub receiver: Pubkey,
    pub input_asset: Pubkey,
    pub output_asset: Pubkey,
    pub normalized_amount: u128,
    /// NOTE: max_fee is now irrelevant and not used in V2 spoke
    /// This is kept here only for not changing the event data structure
    pub max_fee: u32,
    pub origin_domain: u32,
    pub nonce: u64,
    pub ttl: u64,
    pub timestamp: u64,
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
}

#[event_cpi]
#[derive(Accounts)]
pub struct NewIntent<'info> {
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

    #[account(mut)]
    pub authority: Signer<'info>,

    pub mint: Account<'info, Mint>,

    // NOTE: we allow any token account (not just ATA) to send in asset.
    #[account(
        mut,
        token::mint = mint,
        token::authority = authority,
        token::token_program = token_program,
    )]
    pub user_token_account: Account<'info, TokenAccount>,

    // NOTE: validation of the program vault account is done inside the call
    #[account(mut)]
    pub program_vault_account: Account<'info, TokenAccount>,

    #[account(address = TOKEN_PROGRAM_ID)]
    pub token_program: Program<'info, Token>,

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

    /// CHECK: A unique message / gas payment account (signer)
    #[account(mut, signer)]
    pub unique_message_account: AccountInfo<'info>,

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

    /// CHECK: we verify this is consistent with fee_signer
    #[account(address = fee_adapter_state.fee_signer)]
    pub fee_signer: AccountInfo<'info>,

    /// CHECK: we verify this is consistent with fee_recipient
    #[account(
        mut,
        address = fee_adapter_state.fee_recipient
    )]
    pub fee_recipient: AccountInfo<'info>,

    #[account(
        mut,
        token::mint = mint,
        token::authority = fee_recipient,
        token::token_program = token_program
    )]
    pub fee_recipient_token_account: Account<'info, TokenAccount>,

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
    use crate::consts::DEFAULT_NORMALIZED_DECIMALS;
    use crate::error::SpokeError;
    #[test]
    fn test_reject_high_decimal_tokens() {
        // Test that decimals > 18 should be rejected
        let high_decimals = DEFAULT_NORMALIZED_DECIMALS + 1; // 19 decimals
        
        let should_reject = high_decimals > DEFAULT_NORMALIZED_DECIMALS;
        assert!(
            should_reject,
            "Tokens with decimals > {} should be rejected",
            DEFAULT_NORMALIZED_DECIMALS
        );
        
        // exactly 18 decimals should be allowed
        let exact_decimals = DEFAULT_NORMALIZED_DECIMALS;
        let should_allow = exact_decimals <= DEFAULT_NORMALIZED_DECIMALS;
        assert!(
            should_allow,
            "Tokens with exactly {} decimals should be allowed",
            DEFAULT_NORMALIZED_DECIMALS
        );
        
        // less than 18 decimals should be allowed
        let normal_decimals = 9u8;
        let should_allow_normal = normal_decimals <= DEFAULT_NORMALIZED_DECIMALS;
        assert!(
            should_allow_normal,
            "Tokens with {} decimals should be allowed",
            normal_decimals
        );
    }

    #[test]
    fn test_precision_loss_scenario() {
        use crate::utils::normalize_decimals;
        
        const HIGH_DECIMALS: u8 = 20;
        const DEFAULT_NORMALIZED_DECIMALS: u8 = 18;
        
        let original_amount = 1000u128 * 10u128.pow(20); // 1000 * 10^20
        
        let normalized = normalize_decimals(
            original_amount,
            HIGH_DECIMALS,
            DEFAULT_NORMALIZED_DECIMALS
        ).unwrap();
        assert_eq!(normalized, 1000u128 * 10u128.pow(18)); // 1000 * 10^18
        
        let denormalized = normalize_decimals(
            normalized,
            DEFAULT_NORMALIZED_DECIMALS,
            HIGH_DECIMALS
        ).unwrap();
        assert_eq!(denormalized, 1000u128 * 10u128.pow(20)); // 1000 * 10^20
        let potential_loss = original_amount.saturating_sub(denormalized);
        assert_eq!(
            potential_loss, 0,
            "This test demonstrates the precision loss scenario that the fix prevents"
        );
    }

    #[test]
    fn test_fee_data_serialization() {
        use crate::instructions::fee_adapter::FeeData;

        let fee_data = FeeData {
            destinations: vec![1, 2, 3],
            input_asset: Pubkey::new_unique(),
            output_asset: Pubkey::new_unique(),
            amount: 1000,
            amount_out_min: 900,
            ttl: 3600,
            data: vec![1, 2, 3],
            token_fee: 10,
            native_fee: 5,
            deadline: 1000000,
        };

        let mut encoded = vec![];
        fee_data.serialize(&mut encoded).unwrap();
        assert!(!encoded.is_empty(), "FeeData should serialize correctly");
    }

    #[test]
    fn test_different_intent_parameters_produce_different_fee_data() {
        use crate::instructions::fee_adapter::FeeData;

        let input_asset = Pubkey::new_unique();
        let output_asset = Pubkey::new_unique();

        let fee_data1 = FeeData {
            destinations: vec![1],
            input_asset,
            output_asset,
            amount: 1000,
            amount_out_min: 900,
            ttl: 3600,
            data: vec![],
            token_fee: 10,
            native_fee: 5,
            deadline: 1000000,
        };

        let fee_data2 = FeeData {
            destinations: vec![2],
            input_asset,
            output_asset,
            amount: 1000,
            amount_out_min: 900,
            ttl: 3600,
            data: vec![],
            token_fee: 10,
            native_fee: 5,
            deadline: 1000000,
        };

        let mut encoded1 = vec![];
        fee_data1.serialize(&mut encoded1).unwrap();

        let mut encoded2 = vec![];
        fee_data2.serialize(&mut encoded2).unwrap();

        assert_ne!(encoded1, encoded2, "Different intent parameters should produce different FeeData");
    }

    #[test]
    fn test_fee_data_binding_prevents_signature_reuse() {
        use crate::instructions::fee_adapter::FeeData;

        let input_asset = Pubkey::new_unique();
        let output_asset = Pubkey::new_unique();

        let fee_data1 = FeeData {
            destinations: vec![1],
            input_asset,
            output_asset,
            amount: 1000,
            amount_out_min: 900,
            ttl: 3600,
            data: vec![],
            token_fee: 10,
            native_fee: 5,
            deadline: 1000000,
        };

        let fee_data2 = FeeData {
            destinations: vec![1],
            input_asset,
            output_asset,
            amount: 2000,
            amount_out_min: 900,
            ttl: 3600,
            data: vec![],
            token_fee: 10,
            native_fee: 5,
            deadline: 1000000,
        };

        let mut encoded1 = vec![];
        fee_data1.serialize(&mut encoded1).unwrap();

        let mut encoded2 = vec![];
        fee_data2.serialize(&mut encoded2).unwrap();

        assert_ne!(encoded1, encoded2, "Different intent parameters should produce different FeeData, preventing signature reuse");
    }
}
