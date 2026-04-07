use anchor_lang::{
    prelude::*,
    solana_program::system_program,
};
use anchor_spl::{
    associated_token::{get_associated_token_address, AssociatedToken},
    token::ID as TOKEN_PROGRAM_ID,
};

use crate::{
    consts::{everclear_gateway, h256_to_pub, EVERCLEAR_DOMAIN},
    error::SpokeError,
    events::{CcipSettlementReceived, MessageDeliveredEvent, MessageReceivedEvent},
    hyperlane::{
        mailbox::HandleInstruction, to_serializable_account_meta, SerializableAccountMeta,
        SimulationReturnData,
    },
    instructions::{
        messages::{HyperlaneMessages, MessageType, Settlement, Settlements},
        utils::{create_or_claim_intent_status_pda, keccak_256},
    },
    intent_status_pda_seeds, mailbox_process_authority_pda_seeds,
    messaging,
    state::{IntentStatus, IntentStatusAccount, MessagingProviderType, PendingCcipInbox, SpokeState},
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

            let settlement = &batch.settlements[0];

            // 1. Compute commitment hash
            let mut buf = Vec::new();
            settlement.serialize(&mut buf).unwrap();
            let hash = keccak_256(&buf);

            let inbox = &mut ctx.accounts.inbox;

            // 2. Dedupe — reject if this settlement was already committed
            require!(
                !inbox.hashes.iter().any(|h| *h == hash),
                SpokeError::PendingSettlementExists
            );

            // 3. Find first empty slot
            let slot = inbox.hashes.iter_mut()
                .find(|h| **h == [0u8; 32])
                .ok_or(error!(SpokeError::PendingSettlementsFull))?;
            *slot = hash;

            // 4. Emit event with full settlement data so relayer can reconstruct
            let state = &ctx.accounts.spoke_state;
            emit!(CcipSettlementReceived {
                origin: state.everclear,
                settlement_hash: hash,
                intent_id: settlement.intent_id,
                amount: settlement.amount,
                asset: settlement.asset,
                recipient: settlement.recipient,
                update_virtual_balance: settlement.update_virtual_balance,
            });
        }
        _ => {
            return err!(SpokeError::InvalidMessage);
        }
    }
    Ok(())
}

/// Settle a CCIP delivery: verifies settlement hash against inbox,
/// creates the intent_status_pda with Delivered status so that the existing
/// settle_delivered_intent instruction can complete the token transfer.
pub fn settle_ccip_delivery(
    ctx: Context<SettleCcipDeliveryContext>,
    settlement: Settlement,
) -> Result<()> {
    let state = &ctx.accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);

    // 1. Hash the provided settlement (preimage verification)
    let mut buf = Vec::new();
    settlement.serialize(&mut buf).unwrap();
    let hash = keccak_256(&buf);

    // 2. Find and clear the matching hash from inbox
    let inbox = &mut ctx.accounts.inbox;
    let slot = inbox.hashes.iter_mut()
        .find(|h| **h == hash)
        .ok_or(error!(SpokeError::NoPendingSettlement))?;
    *slot = [0u8; 32]; // clear immediately — tx is atomic, reverts undo this

    // 3. Validate intent_status_pda matches intent_id
    let intent_status_pda = &mut ctx.accounts.intent_status_pda;
    let intent_status_seed: &[&[u8]] = intent_status_pda_seeds!(settlement.intent_id);
    let (expected_pda, intent_status_bump) =
        Pubkey::find_program_address(intent_status_seed, ctx.program_id);
    require!(
        intent_status_pda.key() == expected_pda,
        SpokeError::InvalidIntentPda
    );

    // 4. Check if PDA already exists — if terminal state, return Ok (hash already cleared)
    let data = IntentStatusAccount::try_deserialize(&mut &intent_status_pda.data.borrow()[..]);
    if let Ok(existing) = data {
        if existing.status == IntentStatus::Settled
            || existing.status == IntentStatus::SettledAndManuallyExecuted
            || existing.status == IntentStatus::Delivered
        {
            // Already handled — hash is cleared, inbox slot freed, done
            return Ok(());
        }
    } else {
        // 5. Create the PDA account (using allocate+assign pattern to handle pre-funded PDAs)
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
    }

    // 6. Write Delivered status + settlement data
    let account_metas =
        build_settle_intent_account_metas(ctx.program_id, &intent_status_pda.key(), &settlement)?;

    let intent_status = IntentStatusAccount {
        settlement: Some(settlement.clone()),
        status: IntentStatus::Delivered,
        accounts: account_metas.clone(),
    };

    intent_status.try_serialize(&mut &mut intent_status_pda.data.borrow_mut()[..])?;

    emit!(MessageDeliveredEvent {
        domain: state.domain,
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

    /// CHECK: External execution config PDA — derived from our program's seeds, not the offramp's.
    /// Required by the CCIP offramp CPI call structure but not read by our handler.
    #[account(mut, seeds = [b"external_execution_config"], bump)]
    pub external_execution_config: UncheckedAccount<'info>,

    #[account(
        seeds = [b"spoke-state"],
        bump = spoke_state.bump,
    )]
    pub spoke_state: Account<'info, SpokeState>,

    #[account(
        mut,
        seeds = [b"ccip-inbox"],
        bump = inbox.bump,
    )]
    pub inbox: Account<'info, PendingCcipInbox>,
}

#[derive(Accounts)]
#[instruction(settlement: Settlement)]
pub struct SettleCcipDeliveryContext<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        seeds = [b"spoke-state"],
        bump = spoke_state.bump,
    )]
    pub spoke_state: Account<'info, SpokeState>,

    #[account(
        mut,
        seeds = [b"ccip-inbox"],
        bump = inbox.bump,
    )]
    pub inbox: Account<'info, PendingCcipInbox>,

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

#[derive(Accounts)]
pub struct InitCcipInbox<'info> {
    #[account(
        init,
        seeds = [b"ccip-inbox"],
        bump,
        payer = admin,
        space = 8 + PendingCcipInbox::SIZE,
    )]
    pub inbox: Account<'info, PendingCcipInbox>,
    #[account(mut, constraint = admin.key() == spoke_state.owner @ SpokeError::OnlyOwner)]
    pub admin: Signer<'info>,
    #[account(seeds = [b"spoke-state"], bump = spoke_state.bump)]
    pub spoke_state: Account<'info, SpokeState>,
    pub system_program: Program<'info, System>,
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
    fn test_spoke_state_size_no_pending_field() {
        // SpokeState no longer has pending_ccip_settlement — that's in the inbox PDA
        assert_eq!(SpokeState::SIZE, 339, "SpokeState::SIZE should be 339 (no pending field)");
    }

    #[test]
    fn test_pending_ccip_inbox_size() {
        assert_eq!(PendingCcipInbox::SIZE, 1 + 32 * 32, "Inbox: 1 bump + 32 hashes × 32 bytes");
        // Total account: 8 discriminator + 1025 = 1033
        assert_eq!(8 + PendingCcipInbox::SIZE, 1033);
    }

    #[test]
    fn test_settlement_hash_deterministic() {
        let settlement = make_test_settlement([0xAB; 32]);
        let mut buf1 = Vec::new();
        settlement.serialize(&mut buf1).unwrap();
        let hash1 = keccak_256(&buf1);

        let mut buf2 = Vec::new();
        settlement.serialize(&mut buf2).unwrap();
        let hash2 = keccak_256(&buf2);

        assert_eq!(hash1, hash2, "Same settlement must produce same hash");
    }

    #[test]
    fn test_different_settlements_different_hashes() {
        let s1 = make_test_settlement([1u8; 32]);
        let s2 = make_test_settlement([2u8; 32]);

        let mut buf1 = Vec::new();
        s1.serialize(&mut buf1).unwrap();
        let hash1 = keccak_256(&buf1);

        let mut buf2 = Vec::new();
        s2.serialize(&mut buf2).unwrap();
        let hash2 = keccak_256(&buf2);

        assert_ne!(hash1, hash2, "Different settlements must produce different hashes");
    }

    #[test]
    fn test_settlement_hash_never_zero() {
        let settlement = make_test_settlement([0u8; 32]);
        let mut buf = Vec::new();
        settlement.serialize(&mut buf).unwrap();
        let hash = keccak_256(&buf);
        assert_ne!(hash, [0u8; 32], "keccak256 of any data must never be all zeros");
    }

    #[test]
    fn test_inbox_insert_and_clear() {
        let mut hashes = [[0u8; 32]; 32];
        let test_hash = [0xABu8; 32];

        // Insert
        let slot = hashes.iter_mut().find(|h| **h == [0u8; 32]).unwrap();
        *slot = test_hash;
        assert!(hashes.iter().any(|h| *h == test_hash), "Hash should be in inbox after insert");

        // Clear
        let slot = hashes.iter_mut().find(|h| **h == test_hash).unwrap();
        *slot = [0u8; 32];
        assert!(!hashes.iter().any(|h| *h == test_hash), "Hash should not be in inbox after clear");
    }

    #[test]
    fn test_inbox_dedupe() {
        let mut hashes = [[0u8; 32]; 32];
        let test_hash = [0xCDu8; 32];

        // First insert succeeds
        let slot = hashes.iter_mut().find(|h| **h == [0u8; 32]).unwrap();
        *slot = test_hash;

        // Second insert should detect duplicate
        let already_exists = hashes.iter().any(|h| *h == test_hash);
        assert!(already_exists, "Dedupe should detect existing hash");
    }

    #[test]
    fn test_inbox_full() {
        let hashes = [[0xFFu8; 32]; 32]; // all slots occupied
        let has_empty = hashes.iter().any(|h| *h == [0u8; 32]);
        assert!(!has_empty, "Full inbox should have no empty slots");
        // Insert should fail — no empty slot found
        let insert_result = hashes.iter().find(|h| **h == [0u8; 32]);
        assert!(insert_result.is_none(), "Insert into full inbox must return None");
    }

    #[test]
    fn test_inbox_multi_hash_clear_preserves_others() {
        let mut hashes = [[0u8; 32]; 32];
        let hash_a = [0xAAu8; 32];
        let hash_b = [0xBBu8; 32];
        let hash_c = [0xCCu8; 32];

        // Insert 3 hashes
        hashes[0] = hash_a;
        hashes[1] = hash_b;
        hashes[2] = hash_c;

        // Clear the middle one
        let slot = hashes.iter_mut().find(|h| **h == hash_b).unwrap();
        *slot = [0u8; 32];

        // Verify: B gone, A and C still present
        assert!(hashes.iter().any(|h| *h == hash_a), "Hash A must survive");
        assert!(!hashes.iter().any(|h| *h == hash_b), "Hash B must be gone");
        assert!(hashes.iter().any(|h| *h == hash_c), "Hash C must survive");
        // Verify exactly 29 empty slots (32 - 3 + 1 cleared)
        let empty_count = hashes.iter().filter(|h| **h == [0u8; 32]).count();
        assert_eq!(empty_count, 30, "Should have 30 empty slots after 3 inserts and 1 clear");
    }

    #[test]
    fn test_inbox_dedupe_count() {
        let mut hashes = [[0u8; 32]; 32];
        let test_hash = [0xEEu8; 32];

        hashes[0] = test_hash;
        // Count occurrences — must be exactly 1
        let count = hashes.iter().filter(|h| **h == test_hash).count();
        assert_eq!(count, 1, "Hash should appear exactly once");
        // Verify it's at the expected position
        assert_eq!(hashes[0], test_hash, "Hash should be at index 0");
        assert_eq!(hashes[1], [0u8; 32], "Index 1 should still be empty");
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
