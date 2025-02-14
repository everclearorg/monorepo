use anchor_lang::prelude::*;
use anchor_spl::{associated_token::get_associated_token_address, token::{self, Mint, Token, TokenAccount}};

use crate::{consts::{DEFAULT_NORMALIZED_DECIMALS, EVERCLEAR_DOMAIN, GATEWAY_HASH, LIGHTHOUSE_HASH, MAILBOX_HASH, WATCHTOWER_HASH}, error::SpokeError, events::{MessageReceivedEvent, SettledEvent}, state::{IntentStatus, SpokeState}, utils::{normalize_decimals, vault_authority_seeds}};

use super::AuthState;

/// Receive a cross‑chain message via Hyperlane.
/// In production, this would be invoked via CPI from Hyperlane's Mailbox.
pub fn receive_message<'a>(
    ctx: Context<'_, '_, 'a, 'a, AuthState<'a>>,
    origin: u32,
    sender: Pubkey,
    payload: Vec<u8>,
    self_program_id: &Pubkey,
) -> Result<()> {
    let state = &mut ctx.accounts.spoke_state;
    require!(!state.paused, SpokeError::ContractPaused);
    require!(origin == EVERCLEAR_DOMAIN, SpokeError::InvalidOrigin);
    require!(sender == state.message_receiver, SpokeError::InvalidSender);

    require!(!payload.is_empty(), SpokeError::InvalidMessage);
    let msg_type = payload[0];
    match msg_type {
        1 => {
            msg!("Processing settlement batch message");
            let settlement_data = &payload[1..];
            let batch: Vec<Settlement> = AnchorDeserialize::deserialize(&mut &settlement_data[..])
                .map_err(|_| SpokeError::InvalidMessage)?;
            
            let (_, vault_bump) = 
                Pubkey::find_program_address(&[b"vault"], self_program_id);
            
            // Create local references to avoid lifetime issues
            let vault_token_account = &ctx.accounts.vault_token_account;
            let vault_authority = &ctx.accounts.vault_authority;
            let token_program = &ctx.accounts.token_program;
            let remaining_accounts = ctx.remaining_accounts;
            
            handle_batch_settlement(
                state,
                batch,
                vault_token_account,
                vault_authority,
                vault_bump,
                token_program,
                remaining_accounts,
                self_program_id
            )?;
        },
        2 => {
            // Var update
            msg!("Processing variable update message");
            let var_data = &payload[1..];
            handle_var_update(state, var_data)?;
        },
        _ => {
            return Err(SpokeError::InvalidMessage.into());
        }
    }
    emit!(MessageReceivedEvent { origin, sender });
    Ok(())
}

fn handle_batch_settlement<'info>(
    state: &mut SpokeState,
    batch: Vec<Settlement>,
    vault_token_account: &Account<'info, TokenAccount>,
    vault_authority: &UncheckedAccount<'info>,
    vault_authority_bump: u8,
    token_program: &Program<'info, Token>,
    remaining_accounts: &'info [AccountInfo<'info>],
    self_program_id: &Pubkey
) -> Result<()> {
    for s in batch.iter() {
        handle_settlement(
            state,
            s,
            vault_token_account,
            vault_authority,
            vault_authority_bump,
            token_program,
            remaining_accounts,
            self_program_id,
        )?;
    }
    Ok(())
}

fn handle_settlement<'info>(
    state: &mut SpokeState,
    settlement: &Settlement,
    vault_token_account: &Account<'info, TokenAccount>,
    vault_authority: &UncheckedAccount<'info>,
    vault_authority_bump: u8,
    token_program: &Program<'info, Token>,
    remaining_accounts: &'info [AccountInfo<'info>],
    self_program_id: &Pubkey
) -> Result<()> {
    // 1) Check if already settled
    let current_status = state.status.iter_mut().filter(|s| s.key == settlement.intent_id).next();
    
    if let Some(current) = current_status {
        if current.status == IntentStatus::Settled 
        || current.status == IntentStatus::SettledAndManuallyExecuted {
            msg!("Intent already settled, ignoring");
            return Ok(());
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
    let amount = normalize_decimals(settlement.amount, minted_decimals, DEFAULT_NORMALIZED_DECIMALS)?;
    if amount == 0 {
        return Ok(());
    }

    // Attempt CPI transfer
    let seeds = vault_authority_seeds(self_program_id, &vault_token_account.mint.key(), vault_authority_bump);
    let signer_seeds = [
        &seeds[0][..],
        &seeds[1][..],
        &seeds[2][..],
        &seeds[3][..],
    ];
    let signer = &[&signer_seeds[..]];

    let cpi_accounts = anchor_spl::token::Transfer {
        from: vault_token_account.to_account_info(),
        to: make_recipient_token_account_info(remaining_accounts, settlement.recipient, settlement.asset)?,
        authority: vault_authority.to_account_info(),
    };
    let cpi_ctx = CpiContext::new_with_signer(token_program.to_account_info(), cpi_accounts, signer);
    
    // NOTE: Removed the virtual balance logic
    token::transfer(cpi_ctx, amount);

    emit!(SettledEvent {
       intent_id: settlement.intent_id,
       recipient: settlement.recipient,
       asset: settlement.asset,
       amount: amount,
    });

    Ok(())
}

fn handle_var_update(
    state: &mut SpokeState, 
    var_data: &[u8]
) -> Result<()> {
    // e.g., parse the first 32 bytes as a "var hash"
    require!(var_data.len() >= 32, SpokeError::InvalidMessage);
    let mut var_hash = [0u8; 32];
    var_hash.copy_from_slice(&var_data[..32]);
    let rest = &var_data[32..];
    
    // Compare var_hash with your known constants
    if var_hash == GATEWAY_HASH {
        let new_gateway: Pubkey = try_deserialize_a_pubkey(rest)?;
        super::update_gateway(state, new_gateway)?;
    } else if var_hash == MAILBOX_HASH {
        let new_mailbox: Pubkey = try_deserialize_a_pubkey(rest)?;
        super::update_mailbox(state, new_mailbox)?;
    } else if var_hash == LIGHTHOUSE_HASH {
        let new_lighthouse: Pubkey = try_deserialize_a_pubkey(rest)?;
        super::update_lighthouse(state, new_lighthouse)?;
    } else if var_hash == WATCHTOWER_HASH {
        let new_watchtower: Pubkey = try_deserialize_a_pubkey(rest)?;
        super::update_watchtower(state, new_watchtower)?;
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
    let key_array: [u8; 32] = data[..32].try_into().map_err(|_| SpokeError::InvalidMessage)?;
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
