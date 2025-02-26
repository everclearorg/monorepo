use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::get_associated_token_address,
    token::{self, Mint, Token, TokenAccount},
};

use crate::{
    consts::{
        everclear_gateway, h256_to_pub, DEFAULT_NORMALIZED_DECIMALS, EVERCLEAR_DOMAIN,
        LIGHTHOUSE_HASH, MAILBOX_HASH, WATCHTOWER_HASH,
    }, error::SpokeError, events::{MessageReceivedEvent, SettledEvent}, instructions::AdminStateBumps, program::EverclearSpoke, state::{IntentStatus, SpokeState}, utils::{normalize_decimals, vault_authority_seeds}
};

use crate::hyperlane::mailbox::HandleInstruction;

use super::{AdminState, AuthState};

/// Receive a cross‑chain message via Hyperlane.
/// In production, this would be invoked via CPI from Hyperlane's Mailbox.
pub fn handle<'info>(
    ctx: Context<'_, '_, 'info, 'info, AuthState<'info>>,
    handle: HandleInstruction,
) -> Result<()> {
    // TODO: Checking the Hyperlane Mailbox
    // require!(msg.sender == MAILBOX, SpokeError::InvalidSender);
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
            let batch: Vec<Settlement> = AnchorDeserialize::deserialize(&mut &settlement_data[..])
                .map_err(|_| SpokeError::InvalidMessage)?;

            let (_, vault_bump) = Pubkey::find_program_address(&[b"vault"], ctx.program_id);

            handle_batch_settlement(ctx, batch, vault_bump)?;
        }
        2 => {
            // Var update
            msg!("Processing variable update message");
            let var_data = &handle.message[1..];
            let admin_state = &mut AdminState {
                spoke_state: ctx.accounts.spoke_state.clone(),
                admin: ctx.accounts.authority.clone(),
                event_authority: ctx.accounts.event_authority.clone(),
                program: ctx.accounts.program.clone(),
            };
            let admin_ctx = Context::new(
                ctx.program_id,
                admin_state,
                ctx.remaining_accounts,
                AdminStateBumps {
                    event_authority: ctx.bumps.event_authority,
                },
            );
            handle_var_update(admin_ctx, var_data)?;
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


pub fn interchain_security_module(
    _ctx: Context<InterchainSecurityModule>,
) -> Result<()> {
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
    account_metas_pda: UncheckedAccount<'info>
}

pub fn handle_account_metas(ctx: Context<HandleAccountMetas>, handle: HandleInstruction) -> Result<AuthStateMetas>{
    // TODO: how we store bump?
    let spoke_state_seed: &[&[u8]]= &[b"spoke-state"];
    let spoke_state =
        Pubkey::create_program_address(spoke_state_seed, ctx.program_id)
            .map_err(|_| SpokeError::InvalidArgument)?;

    let msg_type = handle.message[0];
    match msg_type {
        1 => {
            msg!("Processing settlement batch message");
            let settlement_data = &&handle.message[1..];
            let batch: Vec<Settlement> = AnchorDeserialize::deserialize(&mut &settlement_data[..])
                .map_err(|_| SpokeError::InvalidMessage)?;

            let (_, vault_bump) = Pubkey::find_program_address(&[b"vault"], ctx.program_id);

            // TODO: we seems need to have a vec of token_program to handle a vec of settlement
            Ok(AuthStateMetas{
                spoke_state,
                authority: todo!(),
                vault_token_account: todo!(),
                vault_authority: todo!(),
                token_program: todo!(),
                hyperlane_mailbox: todo!(),
                event_authority: todo!(),
                program: *ctx.program_id,
            })
        }
        2 => {
            // Var update
            msg!("variable update message metadata");
            let zero_address = Pubkey::from([0; 32]);
            Ok(AuthStateMetas{
                spoke_state,
                authority: todo!(),
                vault_token_account: zero_address,
                vault_authority: zero_address,
                token_program: zero_address,
                hyperlane_mailbox: todo!(),
                event_authority: todo!(),
                program: *ctx.program_id,
            })
        }
        _ => {
            return Err(SpokeError::InvalidMessage.into());
        }
    }

    // TODO: we may need to put all of those in the their pda, hyperlane_mailbox
}

#[derive(Accounts)]
pub struct HandleAccountMetas<'info> {
    /// CHECK: this is now undefined pdas where we dont store anything
    account_metas_pda: AccountInfo<'info>
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct AuthStateMetas {
    pub spoke_state: Pubkey,
    pub authority: Pubkey,
    pub vault_token_account: Pubkey,
    pub vault_authority: Pubkey,
    pub token_program: Pubkey,
    pub hyperlane_mailbox: Pubkey,
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

fn handle_var_update(ctx: Context<AdminState>, var_data: &[u8]) -> Result<()> {
    // e.g., parse the first 32 bytes as a "var hash"
    require!(var_data.len() >= 32, SpokeError::InvalidMessage);
    let mut var_hash = [0u8; 32];
    var_hash.copy_from_slice(&var_data[..32]);
    let rest = &var_data[32..];

    // Compare var_hash with your known constants
    if var_hash == MAILBOX_HASH {
        let new_mailbox: Pubkey = try_deserialize_a_pubkey(rest)?;
        super::update_mailbox(ctx, new_mailbox)?;
    } else if var_hash == LIGHTHOUSE_HASH {
        let new_lighthouse: Pubkey = try_deserialize_a_pubkey(rest)?;
        super::update_lighthouse(ctx, new_lighthouse)?;
    } else if var_hash == WATCHTOWER_HASH {
        let new_watchtower: Pubkey = try_deserialize_a_pubkey(rest)?;
        super::update_watchtower(ctx, new_watchtower)?;
    } else {
        return err!(SpokeError::InvalidVarUpdate);
    }

    Ok(())
}

fn try_deserialize_a_pubkey(data: &[u8]) -> Result<Pubkey> {
    // 1) Ensure we have at least 32 bytes
    if data.len() < 32 {
        return err!(SpokeError::InvalidMessage);
    }

    // 2) Copy the first 32 bytes into a Pubkey
    let key_array: [u8; 32] = data[..32]
        .try_into()
        .map_err(|_| SpokeError::InvalidMessage)?;
    Ok(Pubkey::new_from_array(key_array))
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
