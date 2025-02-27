use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::get_associated_token_address,
    token::{self, Mint, Token, TokenAccount},
};

use crate::{
    consts::{everclear_gateway, h256_to_pub, DEFAULT_NORMALIZED_DECIMALS, EVERCLEAR_DOMAIN}, error::SpokeError, events::{MessageReceivedEvent, SettledEvent}, mailbox_process_authority_pda_seeds, program::EverclearSpoke, state::{IntentStatus, SpokeState}, utils::{normalize_decimals, vault_authority_seeds}
};

use crate::hyperlane::mailbox::HandleInstruction;

use super::AuthState;

/// Receive a cross‑chain message via Hyperlane.
/// In production, this would be invoked via CPI from Hyperlane's Mailbox.
pub fn handle<'info>(
    ctx: Context<'_, '_, 'info, 'info, AuthState<'info>>,
    handle: HandleInstruction,
) -> Result<()> {
    let (expected_process_authority_key, _expected_process_authority_bump) =
        Pubkey::find_program_address(
            mailbox_process_authority_pda_seeds!(ctx.program_id),
            &ctx.accounts.spoke_state.mailbox,
        );
    require!(ctx.accounts.authority.key() == expected_process_authority_key, SpokeError::InvalidSender);
    require!(!ctx.accounts.spoke_state.paused, SpokeError::ContractPaused);
    require!(handle.origin == EVERCLEAR_DOMAIN, SpokeError::InvalidOrigin);
    require!(
        handle.sender == everclear_gateway(),
        SpokeError::InvalidSender
    );

    require!(!handle.message.is_empty(), SpokeError::InvalidMessage);
    // for emit_epi!
    let authority_info = ctx.accounts.event_authority.to_account_info();
    let authority_bump = ctx.bumps.event_authority;

    let msg_type = handle.message[0];
    match msg_type {
        1 => {
            msg!("Processing settlement batch message");
            let settlement_data = &&handle.message[1..];
            // TODO: fix the implementation of Deserialization here as same in EVMs
            let batch: Vec<Settlement> = AnchorDeserialize::deserialize(&mut &settlement_data[..])
                .map_err(|_| SpokeError::InvalidMessage)?;

            let (_, vault_bump) = Pubkey::find_program_address(&[b"vault"], ctx.program_id);

            handle_batch_settlement(ctx, batch, vault_bump)?;
        }
        2 => {
            // Var update
            msg!("Skipping variable update message");
        }
        _ => {
            return Err(SpokeError::InvalidMessage.into());
        }
    }
    // HACK: expand emit_cpi! macro for reference issue
    {
        let disc = anchor_lang::event::EVENT_IX_TAG_LE;
        // TODO: Test the address conversion works
        let inner_data = anchor_lang::Event::data(&MessageReceivedEvent {
            origin: handle.origin,
            sender: h256_to_pub(handle.sender),
        });
        let ix_data: Vec<u8> = disc.into_iter().chain(inner_data).collect();
        let ix = anchor_lang::solana_program::instruction::Instruction::new_with_bytes(
            crate::ID,
            &ix_data,
            vec![
                anchor_lang::solana_program::instruction::AccountMeta::new_readonly(
                    *authority_info.key,
                    true,
                ),
            ],
        );
        anchor_lang::solana_program::program::invoke_signed(
            &ix,
            &[authority_info],
            &[&[b"__event_authority", &[authority_bump]]],
        )
        .map_err(anchor_lang::error::Error::from)?;
    };
    Ok(())
}

pub fn interchain_security_module(_ctx: Context<InterchainSecurityModule>) -> Result<()> {
    // NOTE: return nothing to use the default ISM
    Ok(())
}

#[derive(Accounts)]
pub struct InterchainSecurityModule<'info> {
    /// CHECK: this is a undefined pda that is not in used now
    inbox_pda: UncheckedAccount<'info>,
    // self
    program: Program<'info, EverclearSpoke>,
    // extra account data required as in interchain_security_module_acconut_metas
    // we have none now
}

pub fn interchain_security_module_account_metas(
    _ctx: Context<InterchainSecurityModuleAccountMetas>,
) -> Result<()> {
    // NOTE: we dont need to any account meta for the ISM call
    Ok(())
}

#[derive(Accounts)]
pub struct InterchainSecurityModuleAccountMetas<'info> {
    /// CHECK: this is now undefined pdas where we dont store anything
    account_metas_pda: UncheckedAccount<'info>,
}

pub fn handle_account_metas(
    ctx: Context<HandleAccountMetas>,
    handle: HandleInstruction,
) -> Result<AuthStateMetas> {
    let (spoke_state_pda , _)= Pubkey::find_program_address(&[b"spoke_state"], ctx.program_id);

    let (event_authority_pubkey, _) =
        Pubkey::find_program_address(&[b"__event_authority"], ctx.program_id);

    // TODO: the mailbox address have to be put inside the accounts_meta_pda
    // let (expected_process_authority_key, _expected_process_authority_bump) =
    //     Pubkey::find_program_address(
    //         mailbox_process_authority_pda_seeds!(ctx.program_id),
    //         &ctx.accounts.spoke_state.mailbox,
    //     );

    // TODO: This would need to provide an array of token_programs - as settlements can be for different tokens
    let msg_type = handle.message[0];
    match msg_type {
        1 => {
            msg!("Processing settlement batch message");
            let settlement_data = &handle.message[1..];
            let batch: Vec<Settlement> = AnchorDeserialize::deserialize(&mut &settlement_data[..])
                .map_err(|_| SpokeError::InvalidMessage)?;
            let asset_pubkeys: Vec<Pubkey> =
                batch.iter().map(|settlement| settlement.asset).collect();

            // Derive the vault authority PDA
            let (vault_authority_pubkey, vault_authority_bump) =
                Pubkey::find_program_address(&[b"vault"], ctx.program_id);
            let (vault_token_account_pubkey, _) =
                Pubkey::find_program_address(&[b"vault-token"], ctx.program_id);

            // TODO: What is the authority used here? need to confirm with hyperlane contract
            Ok(AuthStateMetas {
                spoke_state: spoke_state_pda,
                authority: todo!(),
                vault_token_account: vault_token_account_pubkey,
                vault_authority: vault_authority_pubkey,
                token_program: asset_pubkeys,
                event_authority: event_authority_pubkey,
                program: *ctx.program_id,
            })
        }
        2 => {
            // Var update
            msg!("variable update message metadata");
            // NOTE: we skip variable update message in nanospoke now
            let zero_address = Pubkey::from([0; 32]);
            Ok(AuthStateMetas {
                spoke_state: spoke_state_pda,
                authority: zero_address,
                vault_token_account: zero_address,
                vault_authority: zero_address,
                token_program: vec![zero_address],
                event_authority: event_authority_pubkey,
                program: *ctx.program_id,
            })
        }
        _ => {
            return Err(SpokeError::InvalidMessage.into());
        }
    }
}

#[derive(Accounts)]
pub struct HandleAccountMetas<'info> {
    /// CHECK: this is now undefined pdas where we dont store anything
    pub account_metas_pda: UncheckedAccount<'info>,
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct AuthStateMetas {
    pub spoke_state: Pubkey,
    pub authority: Pubkey,
    pub vault_token_account: Pubkey,
    pub vault_authority: Pubkey,
    pub token_program: Vec<Pubkey>,
    pub event_authority: Pubkey,
    pub program: Pubkey,
}

fn handle_batch_settlement<'info>(
    ctx: Context<'_, '_, 'info, 'info, AuthState<'info>>,
    batch: Vec<Settlement>,
    vault_authority_bump: u8,
) -> Result<()> {
    // Create local references to avoid lifetime issues
    for s in batch.iter() {
        let vault_token_account = &ctx.accounts.vault_token_account;
        let vault_authority = &ctx.accounts.vault_authority;
        let token_program = &ctx.accounts.token_program;
        let remaining_accounts = ctx.remaining_accounts;
        let spoke_state = &mut ctx.accounts.spoke_state;
        let res = handle_settlement(
            vault_token_account,
            vault_authority,
            token_program,
            remaining_accounts,
            spoke_state,
            s,
            vault_authority_bump,
            ctx.program_id,
        )?;
        if let Some(event) = res {
            emit_cpi!(event)
        }
    }
    Ok(())
}

fn handle_settlement<'info>(
    vault_token_account: &Account<'info, TokenAccount>,
    vault_authority: &UncheckedAccount<'info>,
    token_program: &Program<'info, Token>,
    remaining_accounts: &'info [AccountInfo<'info>],
    spoke_state: &mut Account<SpokeState>,
    settlement: &Settlement,
    vault_authority_bump: u8,
    self_program_id: &Pubkey,
) -> Result<Option<SettledEvent>> {
    // 1) Check if already settled
    let current_status = spoke_state
        .status
        .iter_mut()
        .find(|s| s.key == settlement.intent_id);

    if let Some(current) = current_status {
        if current.status == IntentStatus::Settled
            || current.status == IntentStatus::SettledAndManuallyExecuted
        {
            msg!("Intent already settled, ignoring");
            return Ok(None);
        }
        // 2) Mark as settled in storage
        current.status = IntentStatus::Settled;
    }

    // 3) Normalise the settlement amount
    let mint_info = remaining_accounts
        .iter()
        .find(|acc| acc.key() == vault_token_account.mint)
        .ok_or(SpokeError::InvalidOperation)?;

    let mint_account = Account::<Mint>::try_from(mint_info)?;
    let minted_decimals = mint_account.decimals;
    let amount = normalize_decimals(
        settlement.amount,
        minted_decimals,
        DEFAULT_NORMALIZED_DECIMALS,
    )?;
    if amount == 0 {
        return Ok(None);
    }

    // Attempt CPI transfer
    let seeds = vault_authority_seeds(
        self_program_id,
        &vault_token_account.mint.key(),
        vault_authority_bump,
    );
    let signer_seeds = [&seeds[0][..], &seeds[1][..], &seeds[2][..], &seeds[3][..]];
    let signer = &[&signer_seeds[..]];

    let cpi_accounts = anchor_spl::token::Transfer {
        from: vault_token_account.to_account_info(),
        to: make_recipient_token_account_info(
            remaining_accounts,
            settlement.recipient,
            settlement.asset,
        )?,
        authority: vault_authority.to_account_info(),
    };
    let cpi_ctx =
        CpiContext::new_with_signer(token_program.to_account_info(), cpi_accounts, signer);

    // NOTE: Removed the virtual balance logic
    token::transfer(cpi_ctx, amount)?;

    Ok(Some(SettledEvent {
        intent_id: settlement.intent_id,
        recipient: settlement.recipient,
        asset: settlement.asset,
        amount,
    }))
}

fn make_recipient_token_account_info<'info>(
    remaining_accounts: &'info [AccountInfo<'info>],
    recipient: Pubkey,
    asset_mint: Pubkey,
) -> Result<AccountInfo<'info>> {
    // 1) Derive the associated token account (ATA)
    let expected_ata_key = get_associated_token_address(&recipient, &asset_mint);

    // 2) Find that account in the remaining accounts
    for acc_info in remaining_accounts.iter() {
        if acc_info.key() == expected_ata_key {
            return Ok(acc_info.clone());
        }
    }

    // If we get here, we did not find the ATA in the remaining accounts
    err!(SpokeError::InvalidOperation)
}

// Context for the settlements
#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct Settlement {
    pub intent_id: [u8; 32],
    pub asset: Pubkey,
    pub recipient: Pubkey,
    pub amount: u64,
}
