use anchor_lang::{prelude::*, solana_program::system_program};
use anchor_spl::{
    associated_token::get_associated_token_address,
    token::{self, Mint, Token, TokenAccount},
};

use crate::{
    consts::{everclear_gateway, h256_to_pub, DEFAULT_NORMALIZED_DECIMALS, EVERCLEAR_DOMAIN},
    error::SpokeError,
    events::{MessageReceivedEvent, SettledEvent},
    hyperlane::{to_serializable_account_meta, SerializableAccountMeta, U256},
    mailbox_process_authority_pda_seeds,
    program::EverclearSpoke,
    state::{IntentStatus, SpokeState},
    utils::{normalize_decimals, vault_authority_seeds},
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
    require!(
        ctx.accounts.authority.key() == expected_process_authority_key,
        SpokeError::InvalidSender
    );
    require!(!ctx.accounts.spoke_state.paused, SpokeError::ContractPaused);
    require!(handle.origin == EVERCLEAR_DOMAIN, SpokeError::InvalidOrigin);
    require!(
        handle.sender == everclear_gateway(),
        SpokeError::InvalidSender
    );

    handle_message(ctx, handle)
}

/// Receive a cross‑chain message via Hyperlane.
/// In production, this would be invoked via CPI from Hyperlane's Mailbox.
pub fn handle_as_admin<'info>(
    ctx: Context<'_, '_, 'info, 'info, AuthState<'info>>,
    handle: HandleInstruction,
) -> Result<()> {
    require!(
        ctx.accounts.authority.key() == ctx.accounts.spoke_state.owner,
        SpokeError::InvalidSender
    );
    require!(!ctx.accounts.spoke_state.paused, SpokeError::ContractPaused);
    require!(handle.origin == EVERCLEAR_DOMAIN, SpokeError::InvalidOrigin);
    require!(
        handle.sender == everclear_gateway(),
        SpokeError::InvalidSender
    );

    handle_message(ctx, handle)
}

fn handle_message<'info>(
    ctx: Context<'_, '_, 'info, 'info, AuthState<'info>>,
    handle: HandleInstruction,
) -> Result<()> {
    require!(!handle.message.is_empty(), SpokeError::InvalidMessage);
    // for emit_epi!
    let authority_info = ctx.accounts.event_authority.to_account_info();
    let authority_bump = ctx.bumps.event_authority;

    let msg: HyperlaneMessages = AnchorDeserialize::deserialize(&mut &handle.message[..])?;
    match msg.message_type {
        MessageType::Settlement => {
            msg!("Processing settlement batch message");
            let batch: Settlements = AnchorDeserialize::deserialize(&mut msg.rest.as_ref())
                .map_err(|_| error!(SpokeError::InvalidMessage))?;

            let (_, vault_bump) = Pubkey::find_program_address(&[b"vault"], ctx.program_id);

            handle_batch_settlement(ctx, batch, vault_bump)?;
        }
        MessageType::VarUpdate => {
            // Var update
            msg!("Skipping variable update message");
        }
        _ => {
            return err!(SpokeError::InvalidMessage);
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
    // ref: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/rust/sealevel/programs/mailbox/src/processor.rs#L475
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
) -> Result<Vec<SerializableAccountMeta>> {
    // NOTE: we dont need to any account meta for the ISM call
    Ok(vec![])
}

#[derive(Accounts)]
pub struct InterchainSecurityModuleAccountMetas<'info> {
    /// CHECK: this is now undefined pdas where we dont store anything
    account_metas_pda: UncheckedAccount<'info>,
}

/// Return accounts required for the handle call.
/// Note the authority parameter will be the first parameter filled by hyperlane and do not needed to be added here.
pub fn handle_account_metas(
    ctx: Context<HandleAccountMetas>,
    handle: HandleInstruction,
) -> Result<Vec<SerializableAccountMeta>> {
    let (spoke_state_pda, _) = Pubkey::find_program_address(&[b"spoke_state"], ctx.program_id);

    let (event_authority_pubkey, _) =
        Pubkey::find_program_address(&[b"__event_authority"], ctx.program_id);

    let msg_type = handle.message[0];
    match msg_type {
        1 => {
            msg!("Processing settlement batch message");
            let settlement_data = &handle.message[1..];
            let batch: Vec<Settlement> = AnchorDeserialize::deserialize(&mut &settlement_data[..])
                .map_err(|_| error!(SpokeError::InvalidMessage))?;
            let asset_pubkeys: Vec<Pubkey> =
                batch.iter().map(|settlement| settlement.asset).collect();

            // Derive the vault authority PDA
            let (vault_authority_pubkey, _vault_authority_bump) =
                Pubkey::find_program_address(&[b"vault"], ctx.program_id);
            let (vault_token_account_pubkey, _vault_token_account_bump) =
                Pubkey::find_program_address(&[b"vault-token"], ctx.program_id);

            let mut ret = vec![
                to_serializable_account_meta(spoke_state_pda, false),
                to_serializable_account_meta(vault_token_account_pubkey, true),
                to_serializable_account_meta(vault_authority_pubkey, false),
            ];
            ret.extend(
                asset_pubkeys
                    .iter()
                    .map(|asset_pubkey| to_serializable_account_meta(*asset_pubkey, false)),
            );
            ret.push(to_serializable_account_meta(system_program::id(), false));
            ret.push(to_serializable_account_meta(event_authority_pubkey, false));
            ret.push(to_serializable_account_meta(*ctx.program_id, false));
            Ok(ret)
        }
        2 => {
            // Var update
            msg!("variable update message metadata");
            // NOTE: we skip variable update message in nanospoke now
            let zero_address = Pubkey::from([0; 32]);
            Ok(vec![
                to_serializable_account_meta(spoke_state_pda, false),
                to_serializable_account_meta(zero_address, false),
                to_serializable_account_meta(zero_address, false),
                to_serializable_account_meta(system_program::id(), false),
                to_serializable_account_meta(event_authority_pubkey, false),
                to_serializable_account_meta(*ctx.program_id, false),
            ])
        }
        _ => {
            err!(SpokeError::InvalidMessage)
        }
    }
}

#[derive(Accounts)]
pub struct HandleAccountMetas<'info> {
    /// CHECK: this is now undefined pdas where we dont store anything
    pub account_metas_pda: UncheckedAccount<'info>,
}

fn handle_batch_settlement<'info>(
    ctx: Context<'_, '_, 'info, 'info, AuthState<'info>>,
    batch: Settlements,
    vault_authority_bump: u8,
) -> Result<()> {
    // Create local references to avoid lifetime issues
    for s in batch.settlements {
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
            &s,
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
        .ok_or(error!(SpokeError::InvalidOperation))?;

    let mint_account = Account::<Mint>::try_from(mint_info)?;
    let minted_decimals = mint_account.decimals;
    let amount = normalize_decimals(
        // TODO: type check this amount properly for edge cases
        settlement.amount.low_u64(),
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
#[derive(AnchorSerialize, Clone)]
pub struct Settlement {
    pub intent_id: [u8; 32],
    pub amount: U256,
    pub asset: Pubkey,
    pub recipient: Pubkey,
    pub update_virtual_balance: bool,
}

impl AnchorDeserialize for Settlement {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        let mut intent_id: [u8; 32] = [0; 32];
        let mut amount: [u8; 32] = [0; 32];
        let mut asset: [u8; 32] = [0; 32];
        let mut recipient: [u8; 32] = [0; 32];
        reader.read_exact(&mut intent_id)?;
        reader.read_exact(&mut amount)?;
        reader.read_exact(&mut asset)?;
        reader.read_exact(&mut recipient)?;
        let mut buf: [u8; 32] = [0; 32];
        reader.read_exact(&mut buf)?;
        // SAFE: buf len always > 1 and can be unwarpped
        let settlement = Settlement {
            intent_id,
            amount: U256::from_big_endian(&amount),
            asset: Pubkey::new_from_array(asset),
            recipient: Pubkey::new_from_array(recipient),
            update_virtual_balance: buf[31] == 1,
        };
        Ok(settlement)
    }
}

/// Settlements object from EVM layer
pub struct Settlements {
    pub settlements: Vec<Settlement>,
}

impl AnchorDeserialize for Settlements {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        // Structure of the data in slots:
        // offset
        // length of data
        // ?
        // len of settlements
        // settlement 1
        // ...
        // settlement 2
        // ...
        let mut buf = [0u8; 32];
        // read offset and ignore
        reader.read_exact(&mut buf)?;
        // read len and ignore
        reader.read_exact(&mut buf)?;
        // read one more block and ignore
        reader.read_exact(&mut buf)?;
        // read len and store into buf
        reader.read_exact(&mut buf)?;
        // SAFE: buf size > 4 and can always be unwrapped
        let (_, size) = buf.split_last_chunk().unwrap();
        let size = u32::from_be_bytes(*size);
        let mut settlements = vec![];
        for _ in 0..size {
            let settlement = Settlement::deserialize_reader(reader)?;
            settlements.push(settlement);
        }
        Ok(Settlements { settlements })
    }
}

pub enum MessageType {
    Intent,
    Fill,
    Settlement,
    VarUpdate,
}

impl TryFrom<u8> for MessageType {
    type Error = u8;

    fn try_from(value: u8) -> std::result::Result<Self, Self::Error> {
        let res = match value {
            0 => MessageType::Intent,
            1 => MessageType::Fill,
            2 => MessageType::Settlement,
            3 => MessageType::VarUpdate,
            _ => return Err(value),
        };
        Ok(res)
    }
}
pub struct HyperlaneMessages {
    pub message_type: MessageType,
    pub rest: Vec<u8>,
}

impl AnchorDeserialize for HyperlaneMessages {
    fn deserialize_reader<R: std::io::Read>(reader: &mut R) -> std::io::Result<Self> {
        // Structure of the data:
        // MessageType (32 byte)
        // remaining message contents
        let mut buf = [0u8; 32];
        reader.read_exact(&mut buf)?;
        let message_type: MessageType = MessageType::try_from(buf[31])
            .map_err(|_| std::io::Error::new(std::io::ErrorKind::InvalidInput, "invalid type"))?;

        let mut rest = vec![];
        reader.read_to_end(&mut rest)?;
        Ok(HyperlaneMessages { message_type, rest })
    }
}
