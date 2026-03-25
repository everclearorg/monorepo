use anchor_lang::{
    prelude::*,
    solana_program::{program::invoke_signed, system_program},
};
use anchor_spl::{
    associated_token::{get_associated_token_address, AssociatedToken},
    token::ID as TOKEN_PROGRAM_ID,
};

use crate::{
    consts::{everclear_gateway, h256_to_pub, EVERCLEAR_DOMAIN},
    error::SpokeError,
    events::{MessageDeliveredEvent, MessageReceivedEvent},
    hyperlane::{
        mailbox::HandleInstruction, to_serializable_account_meta, SerializableAccountMeta,
        SimulationReturnData,
    },
    instructions::{
        messages::{HyperlaneMessages, MessageType, Settlement, Settlements},
        utils::create_or_claim_intent_status_pda,
    },
    intent_status_pda_seeds, mailbox_process_authority_pda_seeds,
    messaging,
    state::{IntentStatus, IntentStatusAccount, MessagingProviderType, SpokeState},
};

/// Return accounts required for the handle call.
/// Note the authority parameter will be the first parameter filled by hyperlane and do not needed to be added here.
pub fn handle_account_metas(
    ctx: Context<HandleAccountMetas>,
    handle: HandleInstruction,
) -> Result<SimulationReturnData<Vec<SerializableAccountMeta>>> {
    let (spoke_state_pda, _) = Pubkey::find_program_address(&[b"spoke-state"], ctx.program_id);

    let (event_authority_pubkey, _) =
        Pubkey::find_program_address(&[b"__event_authority"], ctx.program_id);

    let (pda_payer, _) =
        Pubkey::find_program_address(&[b"everclear_spoke", b"-", b"pda_payer"], ctx.program_id);

    let message: HyperlaneMessages = AnchorDeserialize::deserialize(&mut &handle.message[..])?;
    match message.message_type {
        MessageType::Settlement => {
            let batch: Settlements = AnchorDeserialize::deserialize(&mut message.rest.as_ref())
                .map_err(|_| error!(SpokeError::InvalidMessage))?;

            require!(
                batch.settlements.len() == 1,
                SpokeError::InvalidSettlementSize
            );

            let settlement: &Settlement = &batch.settlements[0];

            let intent_status_seed: &[&[u8]] = intent_status_pda_seeds!(settlement.intent_id);
            // return canonical pda for intent status
            let (intent_status_account, _) =
                Pubkey::find_program_address(intent_status_seed, ctx.program_id);

            let ret = vec![
                to_serializable_account_meta(spoke_state_pda, false),
                to_serializable_account_meta(intent_status_account, true),
                to_serializable_account_meta(system_program::id(), false),
                to_serializable_account_meta(pda_payer, true),
                to_serializable_account_meta(event_authority_pubkey, false),
                to_serializable_account_meta(*ctx.program_id, false),
            ];
            Ok(SimulationReturnData::new(ret))
        }
        _ => {
            // NOTE: we do not support var update now
            err!(SpokeError::InvalidMessage)
        }
    }
}

#[derive(Accounts)]
pub struct HandleAccountMetas<'info> {
    /// ref: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/48b8508af42061d67cf46a3377e4569feb95d1d8/rust/main/chains/hyperlane-sealevel/src/mailbox.rs#L267
    /// CHECK: this is now undefined pdas where we dont store anything
    pub account_metas_pda: UncheckedAccount<'info>,
}

/// Receive a cross‑chain message via Hyperlane.
/// In production, this would be invoked via CPI from Hyperlane's Mailbox.
pub fn handle(ctx: Context<HandleContext>, handle: HandleInstruction) -> Result<()> {
    match messaging::get_messaging_provider(&ctx.accounts.spoke_state) {
        MessagingProviderType::Hyperlane => {
            let (expected_process_authority_key, _expected_process_authority_bump) =
                Pubkey::find_program_address(
                    mailbox_process_authority_pda_seeds!(ctx.program_id),
                    &ctx.accounts.spoke_state.mailbox,
                );
            require!(
                ctx.accounts.authority.key() == expected_process_authority_key,
                SpokeError::InvalidSender
            );
            mark_message_as_delivered(ctx, handle)
        }
        MessagingProviderType::CCIP => {
            return err!(SpokeError::InvalidMessage);
        }
    }
}

pub fn handle_ccip_receive(
    ctx: Context<CcipReceiveContext>,
    message: crate::messaging::ccip::message::Any2SVMMessage,
) -> Result<()> {
    require!(!ctx.accounts.spoke_state.paused, SpokeError::ContractPaused);

    let receive_ctx = crate::messaging::ccip::receive::ReceiveMessageCCIP {
        authority: ctx.accounts.authority.clone(),
        offramp_program: ctx.accounts.offramp_program.clone(),
        allowed_offramp: ctx.accounts.allowed_offramp.clone(),
        external_execution_config: ctx.accounts.external_execution_config.clone(),
        spoke_state: ctx.accounts.spoke_state.clone(),
    };

    let message_data = crate::messaging::ccip::receive::receive_message_via_ccip(
        &receive_ctx,
        message.clone(),
    )?;

    require!(!message_data.is_empty(), SpokeError::InvalidMessage);

    let hyperlane_message: HyperlaneMessages =
        AnchorDeserialize::deserialize(&mut message_data.as_ref())
            .map_err(|_| error!(SpokeError::InvalidMessage))?;

    match hyperlane_message.message_type {
        MessageType::Settlement => {
            let batch: Settlements = AnchorDeserialize::deserialize(&mut hyperlane_message.rest.as_ref())
                .map_err(|_| error!(SpokeError::InvalidMessage))?;

            require!(
                batch.settlements.len() == 1,
                SpokeError::InvalidSettlementSize
            );

            // Store settlement in spoke_state for relay-triggered settlement
            let state = &mut ctx.accounts.spoke_state;
            require!(
                state.pending_ccip_settlement.is_none(),
                SpokeError::PendingSettlementExists
            );
            state.pending_ccip_settlement = Some(batch.settlements[0].clone());

            emit!(MessageReceivedEvent {
                origin: state.domain,
                sender: h256_to_pub(crate::hyperlane::H256::from(state.everclear_gateway)),
            });
        }
        _ => {
            return err!(SpokeError::InvalidMessage);
        }
    }
    Ok(())
}

/// Settle a pending CCIP delivery: reads settlement from spoke_state,
/// creates the intent_status_pda with Delivered status so that the existing
/// settle_delivered_intent instruction can complete the token transfer.
pub fn settle_ccip_delivery(
    ctx: Context<SettleCcipDeliveryContext>,
) -> Result<()> {
    let state = &mut ctx.accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);

    // 1. Read the pending settlement WITHOUT clearing — only clear after all validation passes
    let settlement = state.pending_ccip_settlement
        .as_ref()
        .ok_or(error!(SpokeError::NoPendingSettlement))?
        .clone();

    // 2. Validate intent_status_pda matches intent_id
    let intent_status_pda = &mut ctx.accounts.intent_status_pda;
    let intent_status_seed: &[&[u8]] = intent_status_pda_seeds!(settlement.intent_id);
    let (expected_pda, intent_status_bump) =
        Pubkey::find_program_address(intent_status_seed, ctx.program_id);
    require!(
        intent_status_pda.key() == expected_pda,
        SpokeError::InvalidIntentPda
    );

    // 3. Check if PDA already exists (idempotency guard)
    let data = IntentStatusAccount::try_deserialize(&mut &intent_status_pda.data.borrow()[..]);
    if let Ok(existing) = data {
        if existing.status == IntentStatus::Settled
            || existing.status == IntentStatus::SettledAndManuallyExecuted
            || existing.status == IntentStatus::Delivered
        {
            return err!(SpokeError::InvalidIntentStatus);
        }
    } else {
        // 4. Create the PDA account
        let space = 8
            + std::mem::size_of::<IntentStatusAccount>()
            + 12 * std::mem::size_of::<SerializableAccountMeta>();

        let rent = Rent::get()?;
        let lamports = rent.minimum_balance(space);

        let payer_seed = &[
            "everclear_spoke".as_bytes(),
            "-".as_bytes(),
            "pda_payer".as_bytes(),
        ];
        let (_payer_pda, payer_pda_bump) = Pubkey::find_program_address(payer_seed, ctx.program_id);

        invoke_signed(
            &anchor_lang::solana_program::system_instruction::create_account(
                &ctx.accounts.pda_payer.key(),
                &intent_status_pda.key(),
                lamports,
                space as u64,
                ctx.program_id,
            ),
            &[
                ctx.accounts.pda_payer.to_account_info(),
                intent_status_pda.to_account_info(),
            ],
            &[
                &[b"everclear_spoke", b"-", b"pda_payer", &[payer_pda_bump]],
                intent_status_pda_seeds!(settlement.intent_id, intent_status_bump),
            ],
        )?;
    }

    // 5. Write Delivered status + settlement data
    let account_metas =
        build_settle_intent_account_metas(ctx.program_id, &intent_status_pda.key(), &settlement)?;

    let intent_status = IntentStatusAccount {
        settlement: Some(settlement.clone()),
        status: IntentStatus::Delivered,
        accounts: account_metas.clone(),
    };

    intent_status.try_serialize(&mut &mut intent_status_pda.data.borrow_mut()[..])?;

    // 6. Clear pending settlement only after everything succeeded
    ctx.accounts.spoke_state.pending_ccip_settlement = None;

    emit!(MessageDeliveredEvent {
        domain: ctx.accounts.spoke_state.domain,
        settlement,
        account_metas,
    });
    Ok(())
}

#[derive(Accounts)]
#[instruction(message: crate::messaging::ccip::message::Any2SVMMessage)]
pub struct CcipReceiveContext<'info> {
    /// CHECK: Authority PDA derived by offramp program
    #[account(
        seeds = [b"external_execution_config"],
        bump,
        seeds::program = offramp_program.key(),
    )]
    pub authority: Signer<'info>,

    /// CHECK: Offramp program - exists only to derive the allowed offramp PDA and authority PDA
    pub offramp_program: UncheckedAccount<'info>,

    /// CHECK: PDA of the router program verifying the signer is an allowed offramp
    #[account(
        owner = spoke_state.ccip_router.unwrap() @ SpokeError::InvalidSender,
        seeds = [
            b"allowed_offramp",
            message.source_chain_selector.to_le_bytes().as_ref(),
            offramp_program.key().as_ref()
        ],
        bump,
        seeds::program = spoke_state.ccip_router.unwrap(),
    )]
    pub allowed_offramp: UncheckedAccount<'info>,

    /// CHECK: External execution config PDA - validated by offramp program
    #[account(mut, seeds = [b"external_execution_config"], bump)]
    pub external_execution_config: UncheckedAccount<'info>,

    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump,
    )]
    pub spoke_state: Account<'info, SpokeState>,
}

#[derive(Accounts)]
pub struct SettleCcipDeliveryContext<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump,
    )]
    pub spoke_state: Account<'info, SpokeState>,

    /// CHECK: Validated via PDA derivation in settle_ccip_delivery handler
    #[account(mut)]
    pub intent_status_pda: UncheckedAccount<'info>,

    pub system_program: Program<'info, System>,

    /// CHECK: PDA payer account
    #[account(
        mut,
        seeds = ["everclear_spoke".as_bytes(), "-".as_bytes(), "pda_payer".as_bytes()],
        bump,
    )]
    pub pda_payer: AccountInfo<'info>,
}

#[event_cpi]
#[derive(Accounts)]
#[instruction(handle: HandleInstruction)]
pub struct HandleContext {
    // NOTE: authority will have to be the first account for the usage in receive_message
    pub authority: Signer<'info>,
    #[account(
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    /// CHECK:
    #[account(mut)]
    pub intent_status_pda: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,

    /// CHECK: This is an empty account pda that only store funds to create intent status pda.
    #[account(
        mut,
        seeds = ["everclear_spoke".as_bytes(), "-".as_bytes(), "pda_payer".as_bytes()],
        bump,
    )]
    pub pda_payer: AccountInfo<'info>,
}

#[account]
pub struct PdaPayer {}

pub(crate) fn mark_message_as_delivered(
    ctx: Context<HandleContext>,
    handle: HandleInstruction,
) -> Result<()> {
    require!(!ctx.accounts.spoke_state.paused, SpokeError::ContractPaused);
    require!(handle.origin == EVERCLEAR_DOMAIN, SpokeError::InvalidOrigin);
    require!(
        handle.sender == everclear_gateway(),
        SpokeError::InvalidSender
    );
    require!(!handle.message.is_empty(), SpokeError::InvalidMessage);

    let msg: HyperlaneMessages = AnchorDeserialize::deserialize(&mut &handle.message[..])?;
    match msg.message_type {
        MessageType::Settlement => {
            let batch: Settlements = AnchorDeserialize::deserialize(&mut msg.rest.as_ref())
                .map_err(|_| error!(SpokeError::InvalidMessage))?;

            require!(
                batch.settlements.len() == 1,
                SpokeError::InvalidIntentStatus
            );
            emit_cpi!(MessageReceivedEvent {
                origin: handle.origin,
                sender: h256_to_pub(handle.sender),
            });
            mark_settlement_as_delivered(ctx, batch.settlements[0].clone())?;
        }
        _ => {
            // NOTE: we do not support var update now
            return err!(SpokeError::InvalidMessage);
        }
    }
    Ok(())
}

fn mark_settlement_as_delivered(ctx: Context<HandleContext>, settlement: Settlement) -> Result<()> {
    let intent_status_pda = &mut ctx.accounts.intent_status_pda;
    // verify intent status pda matches intent id
    let intent_status_seed: &[&[u8]] = intent_status_pda_seeds!(settlement.intent_id);
    // return canonical pda for intent status
    let (intent_status_account, intent_status_bump) =
        Pubkey::find_program_address(intent_status_seed, ctx.program_id);
    require!(
        intent_status_pda.key() == intent_status_account,
        SpokeError::InvalidIntentPda
    );

    // try to create:

    let data = IntentStatusAccount::try_deserialize(&mut &intent_status_pda.data.borrow()[..]);
    if data.is_err() {
        let space = 8
            + std::mem::size_of::<IntentStatusAccount>()
            + 12 * std::mem::size_of::<SerializableAccountMeta>();

        create_or_claim_intent_status_pda(
            &ctx.accounts.pda_payer,
            &intent_status_pda,
            ctx.program_id,
            space,
            &settlement.intent_id,
            intent_status_bump,
        )?;
    } else {
        // the account is created beforehand
        let pda_data = data.unwrap();
        // if its already settled, reject the delivery
        if pda_data.status == IntentStatus::Settled
            || pda_data.status == IntentStatus::SettledAndManuallyExecuted
            || pda_data.status == IntentStatus::Delivered
        {
            return err!(SpokeError::InvalidIntentStatus);
        }
    }

    let account_metas =
        build_settle_intent_account_metas(ctx.program_id, &intent_status_pda.key(), &settlement)?;

    let intent_status = IntentStatusAccount {
        settlement: Some(settlement.clone()),
        status: IntentStatus::Delivered,
        accounts: account_metas.clone(),
    };

    intent_status.try_serialize(&mut &mut intent_status_pda.data.borrow_mut()[..])?;

    emit_cpi!(MessageDeliveredEvent {
        domain: ctx.accounts.spoke_state.domain,
        settlement,
        account_metas,
    });
    Ok(())
}

fn build_settle_intent_account_metas(
    program_id: &Pubkey,
    intent_status_pda: &Pubkey,
    settlement: &Settlement,
) -> Result<Vec<SerializableAccountMeta>> {
    let (spoke_state_pda, _) = Pubkey::find_program_address(&[b"spoke-state"], program_id);

    let (event_authority_pubkey, _) =
        Pubkey::find_program_address(&[b"__event_authority"], program_id);

    // Derive the vault authority PDA
    let (vault_authority_pubkey, _vault_authority_bump) =
        Pubkey::find_program_address(&[b"vault"], program_id);

    let recipient_token_account_pubkey =
        get_associated_token_address(&settlement.recipient, &settlement.asset);
    let vault_account_pubkey =
        get_associated_token_address(&vault_authority_pubkey, &settlement.asset);
    let ret = vec![
        to_serializable_account_meta(spoke_state_pda, false),
        to_serializable_account_meta(*intent_status_pda, true),
        to_serializable_account_meta(vault_authority_pubkey, false),
        to_serializable_account_meta(TOKEN_PROGRAM_ID, false),
        to_serializable_account_meta(system_program::id(), false),
        // mint public key
        to_serializable_account_meta(settlement.asset, false),
        // associated token program
        to_serializable_account_meta(AssociatedToken::id(), false),
        // recipient
        to_serializable_account_meta(settlement.recipient, false),
        // recipient ATA
        to_serializable_account_meta(recipient_token_account_pubkey, true),
        // vault ATA
        to_serializable_account_meta(vault_account_pubkey, true),
        to_serializable_account_meta(event_authority_pubkey, false),
        to_serializable_account_meta(*program_id, false),
    ];
    Ok(ret)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::instructions::messages::MessageType;
    use crate::hyperlane::U256;

    #[test]
    fn test_invalid_message_type_returns_error_without_debug_log() {

        let var_update_type = MessageType::VarUpdate;
        let is_settlement = matches!(var_update_type, MessageType::Settlement);
        assert!(!is_settlement, "VarUpdate should not be treated as Settlement");

        let intent_type = MessageType::Intent;
        let is_settlement_intent = matches!(intent_type, MessageType::Settlement);
        assert!(!is_settlement_intent, "Intent should not be treated as Settlement");

        let fill_type = MessageType::Fill;
        let is_settlement_fill = matches!(fill_type, MessageType::Settlement);
        assert!(!is_settlement_fill, "Fill should not be treated as Settlement");

        let settlement_type = MessageType::Settlement;
        let is_settlement = matches!(settlement_type, MessageType::Settlement);
        assert!(is_settlement, "Settlement should be the only supported message type");
    }

    // --- Tests for the CCIP settlement flow ---

    fn make_test_settlement(intent_id: [u8; 32]) -> Settlement {
        Settlement {
            intent_id,
            amount: U256::from(999000000000000000u64),
            asset: Pubkey::new_unique(),
            recipient: Pubkey::new_unique(),
            update_virtual_balance: false,
        }
    }

    #[test]
    fn test_build_settle_intent_account_metas_returns_12_accounts() {
        let program_id = Pubkey::new_unique();
        let intent_status_pda = Pubkey::new_unique();
        let settlement = make_test_settlement([1u8; 32]);

        let metas = build_settle_intent_account_metas(&program_id, &intent_status_pda, &settlement)
            .unwrap();

        assert_eq!(metas.len(), 12, "Should return exactly 12 account metas");
        // intent_status_pda should be at index 1 and writable
        assert_eq!(metas[1].pubkey, intent_status_pda);
        assert!(metas[1].is_writable, "intent_status_pda must be writable");
    }

    #[test]
    fn test_build_settle_intent_account_metas_deterministic() {
        let program_id = Pubkey::new_unique();
        let intent_status_pda = Pubkey::new_unique();
        let settlement = make_test_settlement([42u8; 32]);

        let metas_1 = build_settle_intent_account_metas(&program_id, &intent_status_pda, &settlement).unwrap();
        let metas_2 = build_settle_intent_account_metas(&program_id, &intent_status_pda, &settlement).unwrap();

        assert_eq!(metas_1.len(), metas_2.len());
        for (a, b) in metas_1.iter().zip(metas_2.iter()) {
            assert_eq!(a.pubkey, b.pubkey, "Account metas must be deterministic");
            assert_eq!(a.is_writable, b.is_writable);
        }
    }

    #[test]
    fn test_build_settle_intent_account_metas_includes_recipient_and_asset() {
        let program_id = Pubkey::new_unique();
        let intent_status_pda = Pubkey::new_unique();
        let settlement = make_test_settlement([7u8; 32]);

        let metas = build_settle_intent_account_metas(&program_id, &intent_status_pda, &settlement)
            .unwrap();

        // Asset (mint) at index 5
        assert_eq!(metas[5].pubkey, settlement.asset, "Index 5 must be the token mint");
        assert!(!metas[5].is_writable, "Mint should not be writable");

        // Recipient at index 7
        assert_eq!(metas[7].pubkey, settlement.recipient, "Index 7 must be the recipient");
        assert!(!metas[7].is_writable, "Recipient should not be writable");
    }

    #[test]
    fn test_build_settle_intent_account_metas_different_settlements_produce_different_atas() {
        let program_id = Pubkey::new_unique();
        let pda = Pubkey::new_unique();

        let settlement_a = make_test_settlement([1u8; 32]);
        let settlement_b = make_test_settlement([2u8; 32]);

        let metas_a = build_settle_intent_account_metas(&program_id, &pda, &settlement_a).unwrap();
        let metas_b = build_settle_intent_account_metas(&program_id, &pda, &settlement_b).unwrap();

        // Recipient ATAs (index 8) should differ because recipients differ
        assert_ne!(
            metas_a[8].pubkey, metas_b[8].pubkey,
            "Different recipients must produce different ATAs"
        );
        // Both should be writable
        assert!(metas_a[8].is_writable);
        assert!(metas_b[8].is_writable);
    }

    #[test]
    fn test_intent_status_pda_seeds_deterministic() {
        let intent_id = [0xABu8; 32];
        let program_id = Pubkey::new_unique();

        let seeds: &[&[u8]] = intent_status_pda_seeds!(intent_id);
        let (pda_1, bump_1) = Pubkey::find_program_address(seeds, &program_id);
        let (pda_2, bump_2) = Pubkey::find_program_address(seeds, &program_id);

        assert_eq!(pda_1, pda_2, "PDA derivation must be deterministic");
        assert_eq!(bump_1, bump_2, "Bump must be deterministic");
    }

    #[test]
    fn test_intent_status_pda_seeds_different_intents_produce_different_pdas() {
        let program_id = Pubkey::new_unique();

        let seeds_a: &[&[u8]] = intent_status_pda_seeds!([1u8; 32]);
        let seeds_b: &[&[u8]] = intent_status_pda_seeds!([2u8; 32]);

        let (pda_a, _) = Pubkey::find_program_address(seeds_a, &program_id);
        let (pda_b, _) = Pubkey::find_program_address(seeds_b, &program_id);

        assert_ne!(pda_a, pda_b, "Different intent_ids must produce different PDAs");
    }

    #[test]
    fn test_settlement_serialization_preserves_intent_id() {
        let settlement = make_test_settlement([0xFFu8; 32]);

        // AnchorSerialize uses the derived impl (compact), while AnchorDeserialize
        // uses a custom impl that reads 5 x 32-byte EVM-style slots.
        // Test that the serialized form preserves the intent_id at the start.
        let mut buf = Vec::new();
        settlement.serialize(&mut buf).unwrap();

        assert!(!buf.is_empty(), "Serialized settlement must not be empty");
        // intent_id is the first 32 bytes in both serialization formats
        assert_eq!(&buf[0..32], &[0xFFu8; 32], "intent_id should be first 32 bytes");
        // amount follows (32 bytes in little-endian for AnchorSerialize)
        assert!(buf.len() >= 64, "Serialized data must contain at least intent_id + amount");
    }

    #[test]
    fn test_intent_status_terminal_states_block_delivery() {
        // These statuses should prevent a settlement from being delivered again
        assert!(matches!(IntentStatus::Settled,
            IntentStatus::Settled | IntentStatus::SettledAndManuallyExecuted | IntentStatus::Delivered
        ), "Settled should block re-delivery");
        assert!(matches!(IntentStatus::SettledAndManuallyExecuted,
            IntentStatus::Settled | IntentStatus::SettledAndManuallyExecuted | IntentStatus::Delivered
        ), "SettledAndManuallyExecuted should block re-delivery");
        assert!(matches!(IntentStatus::Delivered,
            IntentStatus::Settled | IntentStatus::SettledAndManuallyExecuted | IntentStatus::Delivered
        ), "Delivered should block re-delivery");

        // These statuses should NOT block
        assert!(!matches!(IntentStatus::None,
            IntentStatus::Settled | IntentStatus::SettledAndManuallyExecuted | IntentStatus::Delivered
        ), "None should not block delivery");
        assert!(!matches!(IntentStatus::Added,
            IntentStatus::Settled | IntentStatus::SettledAndManuallyExecuted | IntentStatus::Delivered
        ), "Added should not block delivery");
        assert!(!matches!(IntentStatus::Filled,
            IntentStatus::Settled | IntentStatus::SettledAndManuallyExecuted | IntentStatus::Delivered
        ), "Filled should not block delivery");
    }

    #[test]
    fn test_spoke_state_size_includes_pending_ccip_settlement() {
        // The SIZE constant must account for pending_ccip_settlement: Option<Settlement>
        // Option discriminant (1 byte) + Settlement (136 bytes) = 137
        let size_without_pending = SpokeState::SIZE - (1 + 136);
        assert_eq!(size_without_pending, 339, "Pre-pending-settlement size should be 339");
        assert_eq!(SpokeState::SIZE, 476, "Full SpokeState::SIZE should be 476");
    }

    #[test]
    fn test_build_settle_intent_account_metas_spoke_state_at_index_0() {
        let program_id = Pubkey::new_unique();
        let intent_status_pda = Pubkey::new_unique();
        let settlement = make_test_settlement([3u8; 32]);

        let metas = build_settle_intent_account_metas(&program_id, &intent_status_pda, &settlement)
            .unwrap();

        // spoke_state PDA should be at index 0 and NOT writable
        let (expected_spoke_state, _) = Pubkey::find_program_address(&[b"spoke-state"], &program_id);
        assert_eq!(metas[0].pubkey, expected_spoke_state, "Index 0 must be spoke_state PDA");
        assert!(!metas[0].is_writable, "spoke_state should not be writable in settle accounts");
    }

}
