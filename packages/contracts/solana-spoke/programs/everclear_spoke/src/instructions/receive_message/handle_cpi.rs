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
                SpokeError::InvalidIntentStatus
            );

            emit!(MessageReceivedEvent {
                origin: ctx.accounts.spoke_state.domain,
                sender: h256_to_pub(crate::hyperlane::H256::from(ctx.accounts.spoke_state.everclear_gateway)),
            });

            mark_settlement_as_delivered_ccip(ctx, batch.settlements[0].clone())?;
        }
        _ => {
            return err!(SpokeError::InvalidMessage);
        }
    }
    Ok(())
}

fn mark_settlement_as_delivered_ccip(ctx: Context<CcipReceiveContext>, settlement: Settlement) -> Result<()> {
    let intent_status_pda = &mut ctx.accounts.intent_status_pda;
    let intent_status_seed: &[&[u8]] = intent_status_pda_seeds!(settlement.intent_id);
    let (intent_status_account, intent_status_bump) =
        Pubkey::find_program_address(intent_status_seed, ctx.program_id);
    require!(
        intent_status_pda.key() == intent_status_account,
        SpokeError::InvalidIntentPda
    );

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
        let pda_data = data.unwrap();
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

    // CCIP receive context has no event_authority; emit directly
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

    /// CHECK: Intent status PDA - will be validated in mark_settlement_as_delivered_ccip
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

}
