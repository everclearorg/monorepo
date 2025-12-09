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

        let __anchor_rent = Rent::get()?;
        let lamports = __anchor_rent.minimum_balance(space);
        let inst = anchor_lang::solana_program::system_instruction::create_account(
            &ctx.accounts.pda_payer.key(),
            &intent_status_pda.key(),
            lamports,
            space as u64,
            ctx.program_id,
        );

        let payer_seed = &[
            "everclear_spoke".as_bytes(),
            "-".as_bytes(),
            "pda_payer".as_bytes(),
        ];
        let (_payer_pda, payer_pda_bump) = Pubkey::find_program_address(payer_seed, ctx.program_id);

        invoke_signed(
            &inst,
            &[
                ctx.accounts.pda_payer.to_account_info(),
                intent_status_pda.to_account_info(),
            ],
            &[
                &[b"everclear_spoke", b"-", b"pda_payer", &[payer_pda_bump]],
                intent_status_pda_seeds!(settlement.intent_id, intent_status_bump),
            ],
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
