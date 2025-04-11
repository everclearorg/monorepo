use anchor_lang::{prelude::*, solana_program::system_program};
use anchor_spl::{associated_token::get_associated_token_address, token::ID as TOKEN_PROGRAM_ID};

use crate::{
    consts::{everclear_gateway, h256_to_pub, EVERCLEAR_DOMAIN},
    error::SpokeError,
    events::{MessageDeliveredEvent, MessageReceivedEvent},
    hyperlane::{
        mailbox::HandleInstruction, to_serializable_account_meta, SerializableAccountMeta,
        SimulationReturnData,
    },
    instructions::messages::{HyperlaneMessages, MessageType, Settlement, Settlements},
    intent_status_pda_seeds, mailbox_process_authority_pda_seeds,
    state::{IntentStatus, IntentStatusAccount, SpokeState},
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
            msg!("Processing settlement batch message");
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
                to_serializable_account_meta(event_authority_pubkey, false),
                to_serializable_account_meta(*ctx.program_id, false),
                to_serializable_account_meta(pda_payer, true),
            ];
            Ok(SimulationReturnData::new(ret))
        }
        _ => {
            // NOTE: we do not support var update now
            msg!("invalid message type: {:?}", message.message_type);
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
    #[account(
        init,
        payer = pda_payer,
        space = 8 + std::mem::size_of::<IntentStatusAccount>() + 10 * std::mem::size_of::<SerializableAccountMeta>(),
        seeds = ["everclear_spoke".as_bytes(), "-".as_bytes(), "intent_status".as_bytes(), &handle.message[160..192]],
        bump
    )]
    pub intent_status_pda: Account<'info, IntentStatusAccount>,
    pub system_program: Program<'info, System>,

    #[account(
        mut,
        seeds = [b"everclear_spoke", b"-", b"pda_payer"],
        bump
    )]
    pub pda_payer: Account<'info, PdaPayer>,
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
            msg!("Processing settlement batch message");
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
    // verify intent status pda matches intent id
    let intent_status_seed: &[&[u8]] = intent_status_pda_seeds!(settlement.intent_id);
    // return canonical pda for intent status
    let (intent_status_account, _) =
        Pubkey::find_program_address(intent_status_seed, ctx.program_id);
    require!(
        ctx.accounts.intent_status_pda.key() == intent_status_account,
        SpokeError::InvalidIntentPda
    );
    let account_metas = build_settle_intent_account_metas(
        ctx.program_id,
        &ctx.accounts.intent_status_pda.key(),
        &settlement,
    )?;
    // if its already settled, reject the marking
    if ctx.accounts.intent_status_pda.status == IntentStatus::Settled
        || ctx.accounts.intent_status_pda.status == IntentStatus::SettledAndManuallyExecuted
        || ctx.accounts.intent_status_pda.status == IntentStatus::Delivered
    {
        return err!(SpokeError::InvalidIntentStatus);
    }
    ctx.accounts.intent_status_pda.settlement = Some(settlement.clone());
    ctx.accounts.intent_status_pda.status = IntentStatus::Delivered;
    ctx.accounts.intent_status_pda.accounts = account_metas.clone();
    emit_cpi!(MessageDeliveredEvent {
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
        // recipient ATA
        to_serializable_account_meta(recipient_token_account_pubkey, true),
        // vault ATA
        to_serializable_account_meta(vault_account_pubkey, true),
        to_serializable_account_meta(event_authority_pubkey, false),
        to_serializable_account_meta(*program_id, false),
    ];
    Ok(ret)
}
