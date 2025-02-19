use crate::error::SpokeError;
use crate::mailbox_message_dispatch_authority_pda_seeds;
use anchor_lang::prelude::{
    borsh::{BorshDeserialize, BorshSerialize},
    *,
};
use mailbox::MailboxInstruction;
use anchor_lang::prelude::{AccountInfo, Pubkey, AccountMeta};
use solana_program::{
    instruction::Instruction,
    msg,
    program::{get_return_data, invoke, invoke_signed},
    program_error::ProgramError,
};
use std::collections::HashMap;
use std::cmp::Ordering;
use token_message::{Encode, TokenMessage};
use igp::{IgpInstruction, IgpPayForGas};

// Importing the MailboxInstruction and MailboxOutboxDispatch structs from the mailbox.rs file.
mod instructions;
pub mod primitive_type;
mod pda_seeds;
mod token_message;
mod igp;
mod mailbox;

pub use primitive_type::*;

use spl_noop; // Import the spl_noop module

/// Seeds relating to the PDA account with information about this warp route.
/// For convenience in getting the account metas required for handling messages,
/// this is the same as the `HANDLE_ACCOUNT_METAS_PDA_SEEDS` in the message
/// recipient interface.
#[macro_export]
macro_rules! hyperlane_token_pda_seeds {
    () => {{
        &[
            b"hyperlane_message_recipient",
            b"-",
            b"handle",
            b"-",
            b"account_metas",
        ]
    }};

    ($bump_seed:expr) => {{
        &[
            b"hyperlane_message_recipient",
            b"-",
            b"handle",
            b"-",
            b"account_metas",
            &[$bump_seed],
        ]
    }};
}

/// A plugin that handles token transfers for a Hyperlane Sealevel Token program.
pub trait HyperlaneSealevelTokenPlugin
where
    Self: BorshSerialize
        + BorshDeserialize
        + std::cmp::PartialEq
        + std::fmt::Debug
        + Default
        + Sized,
        // + SizedData,
{
        /// Initializes the plugin.
        fn initialize<'a, 'b>(
            program_id: &Pubkey,
            system_program: &'a AccountInfo<'b>,
            token_account: &'a AccountInfo<'b>,
            payer_account: &'a AccountInfo<'b>,
            accounts_iter: &mut std::slice::Iter<'a, AccountInfo<'b>>,
        ) -> Result<Self>;
    
        /// Transfers tokens into the program.
        fn transfer_in<'a, 'b>(
            program_id: &Pubkey,
            token: &HyperlaneToken<Self>,
            sender_wallet: &'a AccountInfo<'b>,
            accounts_iter: &mut std::slice::Iter<'a, AccountInfo<'b>>,
            amount: u64,
        ) -> Result<()>;
    }

/// Instruction data for the OutboxDispatch instruction.
#[derive(BorshDeserialize, BorshSerialize, Debug, PartialEq)]
pub struct OutboxDispatch {
    /// The sender of the message.
    /// This is required and not implied because a program uses a dispatch authority PDA
    /// to sign the CPI on its behalf. Instruction processing logic prevents a program from
    /// specifying any message sender it wants by requiring the relevant dispatch authority
    /// to sign the CPI.
    pub sender: Pubkey,
    /// The destination domain of the message.
    pub destination_domain: u32,
    /// The remote recipient of the message.
    pub recipient: H256,
    /// The message body.
    pub message_body: Vec<u8>,
}

pub struct TransferRemote {
    /// The destination domain.
    pub destination_domain: u32,
    /// The remote recipient.
    pub recipient: H256,
    /// The amount or ID of the token to transfer.
    pub amount_or_id: U256,
    // Gas amount
    pub gas_amount: u64,
}

pub struct AccountData<T> {
    data: Box<T>,
}

impl<T: BorshDeserialize> AccountData<T> {
    pub fn fetch(data: &mut &[u8]) -> std::result::Result<Self, ProgramError> {
        let data = Box::new(T::deserialize(data)?);
        Ok(Self { data })
    }

    pub fn into_inner(self) -> Box<T> {
        self.data
    }
}

pub type HyperlaneTokenAccount<T> = AccountData<HyperlaneToken<T>>;

#[derive(BorshDeserialize, BorshSerialize)]
pub struct HyperlaneToken<T> {
    /// The bump seed for this PDA.
    pub bump: u8,
    /// The address of the mailbox contract.
    pub mailbox: Pubkey,
    /// The Mailbox process authority specific to this program as the recipient.
    pub mailbox_process_authority: Pubkey,
    /// The dispatch authority PDA's bump seed.
    pub dispatch_authority_bump: u8,
    /// The decimals of the local token.
    pub decimals: u8,
    /// The decimals of the remote token.
    pub remote_decimals: u8,
    /// Access control owner.
    pub owner: Option<Pubkey>,
    /// The interchain security module.
    pub interchain_security_module: Option<Pubkey>,
    /// (IGP Program, IGP account).
    pub interchain_gas_paymaster: Option<(Pubkey, InterchainGasPaymasterType)>,
    /// Destination gas amounts.
    pub destination_gas: HashMap<u32, u64>,
    /// Remote routers.
    pub remote_routers: HashMap<u32, H256>,
    /// Plugin-specific data.
    pub plugin_data: T,
}

impl<T> HyperlaneToken<T> {
    pub fn local_amount_to_remote_amount(&self, amount: u64) -> Result<U256> {
        convert_decimals(amount.into(), self.decimals, self.remote_decimals)
            .ok_or(SpokeError::InvalidArgument.into())
    }
}

/// Converts an amount from one decimal representation to another.
pub fn convert_decimals(amount: U256, from_decimals: u8, to_decimals: u8) -> Option<U256> {
match from_decimals.cmp(&to_decimals) {
    Ordering::Greater => {
        let divisor = U256::from(10u64).checked_pow(U256::from(from_decimals - to_decimals));
        divisor.and_then(|d| amount.checked_div(d))
    }
    Ordering::Less => {
        let multiplier = U256::from(10u64).checked_pow(U256::from(to_decimals - from_decimals));
        multiplier.and_then(|m| amount.checked_mul(m))
    }
    Ordering::Equal => Some(amount),
}
}

#[derive(AnchorDeserialize, AnchorSerialize)]
pub enum InterchainGasPaymasterType {
    /// An IGP with gas oracles and that receives lamports as payment.
    Igp(Pubkey),
    /// An overhead IGP that points to an inner IGP and imposes a gas overhead for each destination domain.
    OverheadIgp(Pubkey),
}

impl InterchainGasPaymasterType {
    /// Returns the key for the IGP.
    pub fn key(&self) -> &Pubkey {
        match self {
            InterchainGasPaymasterType::Igp(key) => key,
            InterchainGasPaymasterType::OverheadIgp(key) => key,
        }
    }
}

fn dispatch(
    program_id: &Pubkey,
    dispatch_authority_seeds: &[&[u8]],
    destination_domain: u32,
    message_body: Vec<u8>,
    recipient: &H256,
    account_metas: Vec<AccountMeta>,
    account_infos: &[AccountInfo],
    mailbox_id: &Pubkey,
) -> Result<H256> {
    // The recipient is the remote router, which must be enrolled.
    let dispatch_instruction = MailboxInstruction::OutboxDispatch(OutboxDispatch {
        sender: *program_id,
        destination_domain,
        recipient: *recipient,
        message_body,
    });
    let mailbox_ixn = Instruction {
        program_id: *mailbox_id,
        data: dispatch_instruction.into_instruction_data()?,
        accounts: account_metas,
    };
    // Call the Mailbox program to dispatch the message.
    invoke_signed(&mailbox_ixn, account_infos, &[dispatch_authority_seeds])?;

    // Parse the message ID from the return data from the prior dispatch.
    let (returning_program_id, returned_data) =
        get_return_data().ok_or(SpokeError::InvalidArgument)?;
    // The mailbox itself doesn't make any CPIs, but as a sanity check we confirm
    // that the return data is from the mailbox.
    require!(
        *mailbox_id == returning_program_id,
        SpokeError::InvalidArgument,
    );
    // if returning_program_id != *mailbox {
    //     return Err(SpokeError::InvalidArgument);
    // }
    let message_id: H256 =
        H256::try_from_slice(&returned_data).map_err(|_| SpokeError::InvalidMessage)?;

    Ok(message_id)
}

/// Dispatches a message to the remote router for the provided destination domain,
/// paying for gas with the IGP.
/// Errors if there is no IGP configured.
fn dispatch_with_gas(
    program_id: &Pubkey,
    dispatch_authority_seeds: &[&[u8]],
    destination_domain: u32,
    message_body: Vec<u8>,
    gas_amount: u64,
    dispatch_account_metas: Vec<AccountMeta>,
    dispatch_account_infos: &[AccountInfo],
    payment_account_metas: Vec<AccountMeta>,
    payment_account_infos: &[AccountInfo],
    mailbox_id: &Pubkey,
    igp_program_id: &Pubkey,
    recipient: &H256,
) -> Result<H256> {
    let message_id = dispatch(
        program_id,
        dispatch_authority_seeds,
        destination_domain,
        message_body,
        recipient,
        dispatch_account_metas,
        dispatch_account_infos,
        mailbox_id,
    )?;

    // Call the IGP to pay for gas.
    let igp_ixn = Instruction::new_with_borsh(
        *igp_program_id,
        &IgpInstruction::IgpPayForGas(IgpPayForGas {
            message_id,
            destination_domain,
            gas_amount,
        }),
        payment_account_metas,
    );

    invoke(&igp_ixn, payment_account_infos).map_err(|e| e.into())?;

    Ok(message_id)
}

/// Usage example from hyperlane: would have to call into this in new_intent
/// Transfers tokens to a remote.
/// Burns the tokens from the sender's associated token account and
/// then dispatches a message to the remote recipient.
///
/// Accounts:
/// 0.  `[executable]` The system program.
/// 1.  `[executable]` The spl_noop program.
/// 2.  `[]` The token PDA account.
/// 3.  `[executable]` The mailbox program.
/// 4.  `[writeable]` The mailbox outbox account.
/// 5.  `[]` Message dispatch authority.
/// 6.  `[signer]` The token sender and mailbox payer.
/// 7.  `[signer]` Unique message / gas payment account.
/// 8.  `[writeable]` Message storage PDA.
///     ---- If using an IGP ----
/// 9.  `[executable]` The IGP program.
/// 10. `[writeable]` The IGP program data.
/// 11. `[writeable]` Gas payment PDA.
/// 12. `[]` OPTIONAL - The Overhead IGP program, if the configured IGP is an Overhead IGP.
/// 13. `[writeable]` The IGP account.
///      ---- End if ----
/// 14. `[executable]` The spl_token_2022 program.
/// 15. `[writeable]` The mint / mint authority PDA account.
/// 16. `[writeable]` The token sender's associated token account, from which tokens will be burned.

#[derive(Accounts)]
pub struct TransferRemoteContext<'info, T> {
    /// The system program
    pub system_program: Program<'info, System>,

    /// The SPL-Noop program
    pub spl_noop_program: Program<'info, SplNoop>,

    /// CHECK: Our hyperlane token storage account (example)
    #[account(mut)]
    pub token_account: AccountInfo<'info>,

    /// The mailbox program
    pub mailbox_program: Program<'info, Mailbox>,

    /// CHECK: Outbox data account – we rely on the Mailbox program to check
    #[account(mut)]
    pub mailbox_outbox: AccountInfo<'info>,

    /// CHECK: Dispatch authority (PDA)
    pub dispatch_authority: AccountInfo<'info>,

    /// The user's wallet (signer)
    #[account(signer)]
    pub sender_wallet: AccountInfo<'info>,

    /// A unique message / gas payment account
    /// CHECK: Typically validated by IGP / mailbox, so we skip direct Anchor checks
    #[account(signer)]
    pub unique_message_account: AccountInfo<'info>,

    /// CHECK: The message storage PDA
    #[account(mut)]
    pub dispatched_message_pda: AccountInfo<'info>,

    // -- If using an IGP, add those below as well:

    #[account(executable)]
    // TODO: Where am I getting IGP from?
    pub igp_program: Program<'info, Igp>,
    #[account(mut)]
    pub igp_program_data: AccountInfo<'info>,
    #[account(mut)]
    pub igp_payment_pda: AccountInfo<'info>,
    #[account(mut)]
    pub configured_igp_account: AccountInfo<'info>,

    //
    // Or adapt based on exactly how you want Anchor to verify each account.
        // If you need an additional “inner IGP” account for OverheadIgp:
    /// CHECK: Used only if we are in OverheadIgp mode
    #[account(mut)]
    pub inner_igp_account: Option<AccountInfo<'info>>,  // or handle how you want to handle this
}

pub fn transfer_remote<T: HyperlaneSealevelTokenPlugin>(
    // program_id: &Pubkey,
    ctx: Context<TransferRemoteContext<T>>,
    xfer: TransferRemote
) -> Result<()> {
    // let accounts_iter = &mut accounts.iter();

    let program_id = ctx.program_id;
    
    // Account 0: System program.
    let system_program_account = &ctx.accounts.system_program;

    // Account 1: SPL Noop.
    let spl_noop = &ctx.accounts.spl_noop_program;
    
    // Account 2: Token storage account
    let token_account = &ctx.accounts.token_account;
    // let token_account = next_account_info(accounts_iter)?;
    let token = HyperlaneTokenAccount::fetch(&mut &token_account.data.borrow()[..]).map_err(|e| e.into())?.into_inner();
    let token_seeds: &[&[u8]] = hyperlane_token_pda_seeds!(token.bump);
    let expected_token_key = Pubkey::create_program_address(token_seeds, program_id)
        .map_err(|_| SpokeError::InvalidArgument)?;
    require!(
        token_account.key == &expected_token_key,
        SpokeError::InvalidArgument
    );
    require!(
        token_account.owner == program_id,
        SpokeError::IncorrectProgramId
    );

    // Account 3: Mailbox program
    let mailbox_info = &ctx.accounts.mailbox_program;

    // Account 4: Mailbox Outbox data account.
    // No verification is performed here, the Mailbox will do that.
    let mailbox_outbox_account = &ctx.accounts.mailbox_outbox;

    // Account 5: Message dispatch authority
    let dispatch_authority_account = &ctx.accounts.dispatch_authority;
    let dispatch_authority_seeds: &[&[u8]] =
        mailbox_message_dispatch_authority_pda_seeds!(token.dispatch_authority_bump);
        let dispatch_authority_key = Pubkey::create_program_address(dispatch_authority_seeds, program_id)
            .map_err(|_| SpokeError::InvalidArgument)?;
    require!(
        dispatch_authority_account.key == &dispatch_authority_key,
        SpokeError::InvalidArgument
    );

    // Account 6: Sender account / mailbox payer
    // let sender_wallet = next_account_info(accounts_iter)?;
    let sender_wallet = &ctx.accounts.sender_wallet;
    require!(sender_wallet.is_signer, SpokeError::InvalidArgument);
    
    // Account 7: Unique message / gas payment account
    // Defer to the checks in the Mailbox / IGP, no need to verify anything here.
    let unique_message_account = &ctx.accounts.unique_message_account;


    // Account 8: Message storage PDA.
    // Similarly defer to the checks in the Mailbox to ensure account validity.
    let dispatched_message_pda = &ctx.accounts.dispatched_message_pda;


    let igp_payment_accounts =
        if let Some((igp_program_id, igp_account_type)) = token.interchain_gas_paymaster {
            // Account 9: The IGP program
            let igp_program_account = &ctx.accounts.igp_program;
            require!(
                igp_program_account.key == igp_program_id,
                SpokeError::InvalidAccount
            );

            // Account 10: The IGP program data.
            // No verification is performed here, the IGP will do that.
            let igp_program_data_account = &ctx.accounts.igp_program_data;

            // Account 11: The gas payment PDA.
            let igp_payment_pda_account = &ctx.accounts.igp_payment_pda;

            // Account 12: The configured IGP account.
            let configured_igp_account = &ctx.accounts.configured_igp_account;
            if configured_igp_account.key != igp_account_type.key() {
                return err!(SpokeError::InvalidAccount);
            }

            let mut igp_payment_account_metas = vec![
                AccountMeta::new_readonly(solana_program::system_program::ID.to_bytes().into(), false),
                AccountMeta::new(*sender_wallet.key, true),
                AccountMeta::new(*igp_program_data_account.key, false),
                AccountMeta::new_readonly(*unique_message_account.key, true),
                AccountMeta::new(*igp_payment_pda_account.key, false),
            ];
            let mut igp_payment_account_infos = vec![
                system_program_account.to_account_info(), // convert Program to AccountInfo
                sender_wallet.clone(),
                igp_program_data_account.clone(),
                unique_message_account.clone(),
                igp_payment_pda_account.clone(),
            ];
            
            match igp_account_type {
                InterchainGasPaymasterType::Igp(_) => {
                    // No inner IGP needed in this variant
                    igp_payment_account_metas
                        .push(AccountMeta::new(*configured_igp_account.key, false));
                    igp_payment_account_infos.push(configured_igp_account.clone());
                }

                InterchainGasPaymasterType::OverheadIgp(_) => {
                    // 1) Unwrap the optional inner_igp_account from your context:
                    let inner_igp_account = ctx
                        .accounts
                        .inner_igp_account
                        .as_ref()  // get &AccountInfo<'info>
                        .ok_or_else(|| error!(SpokeError::InvalidArgument))?;

                    
                    igp_payment_account_metas.extend([
                        AccountMeta::new(*inner_igp_account.key, false),
                        AccountMeta::new_readonly(*configured_igp_account.key, false),
                    ]);
                    igp_payment_account_infos
                        .extend([inner_igp_account.clone(), configured_igp_account.clone()]);
                }
            };

            Some((
                &igp_program_id,
                igp_payment_account_metas,
                igp_payment_account_infos,
            ))
        } else {
            None
        };

    // The amount denominated in the local decimals.
    let local_amount: u64 = xfer
        .amount_or_id
        .try_into()
        .map_err(|_| SpokeError::IntegerOverflow)?;
    // Convert to the remote number of decimals, which is universally understood
    // by the remote routers as the number of decimals used by the message amount.
    let remote_amount = token.local_amount_to_remote_amount(local_amount)?;

    // Transfer `local_amount` of tokens in...
    T::transfer_in(
        program_id,
        &*token,
        sender_wallet,
        // TODO: Unclear if this solves the problem here
        &mut [].iter(),
        local_amount,
    )?;

    let dispatch_account_metas = vec![
        AccountMeta::new(*mailbox_outbox_account.key, false),
        AccountMeta::new_readonly(*dispatch_authority_account.key, true),
        AccountMeta::new_readonly(solana_program::system_program::ID.to_bytes().into(), false),
        AccountMeta::new_readonly(spl_noop::id(), false),
        AccountMeta::new(*sender_wallet.key, true),
        AccountMeta::new_readonly(*unique_message_account.key, true),
        AccountMeta::new(*dispatched_message_pda.key, false),
    ];
    let dispatch_account_infos = &[
        mailbox_outbox_account.clone(),
        dispatch_authority_account.clone(),
        system_program_account.to_account_info(),
        spl_noop.clone(),
        sender_wallet.clone(),
        unique_message_account.clone(),
        dispatched_message_pda.clone(),
    ];

    // The token message body, which specifies the remote_amount.
    let token_transfer_message = TokenMessage::new(xfer.recipient, remote_amount, vec![]).to_vec();

    // NOTE/TODO: Re-executing this as couldn't find the igp_program_id value due to not being defined in the scope
    let (igp_program_id, igp_account_type) = match token.interchain_gas_paymaster {
        Some(value) => value,
        None => return Err(SpokeError::InvalidArgument.into()),
    };
    if let Some((igp_program_id, igp_payment_account_metas, igp_payment_account_infos)) =
        igp_payment_accounts
    {
        // Dispatch the message and pay for gas.
        dispatch_with_gas(
            program_id, 
            dispatch_authority_seeds,
            xfer.destination_domain,
            token_transfer_message,
            xfer.gas_amount,
            dispatch_account_metas,
            dispatch_account_infos,
            igp_payment_account_metas,
            mailbox_info.key,
            mailbox_info.key,
            igp_program_id,
            &xfer.recipient
        )?;
    }

    msg!(
        "Warp route transfer completed to destination: {}, recipient: {}, remote_amount: {}",
        xfer.destination_domain,
        xfer.recipient,
        remote_amount
    );

    Ok(())
}



#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord)]
enum TokenType {
    Native,
    Synthetic,
    Collateral,
}

struct TokenTransferRemote {
    program_id: Pubkey,
    // Note this is the keypair for normal account not the derived associated token account or delegate.
    sender: String,
    amount: u64,
    // #[arg(long, short, default_value_t = ECLIPSE_DOMAIN)]
    destination_domain: u32,
    recipient: String,
    token_type: TokenType,
}
