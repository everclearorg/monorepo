use anchor_lang::prelude::{borsh::{BorshDeserialize, BorshSerialize}, *};
use fixed_hash::construct_fixed_hash;

use crate::error::SpokeError;

construct_fixed_hash! {
    /// 256-bit hash type.
    #[derive(BorshSerialize, BorshDeserialize)]
    pub struct H256(32);
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

fn dispatch(
    program_id: &Pubkey,
    dispatch_authority_seeds: &[&[u8]],
    destination_domain: u32,
    receipent: &Pubkey,
    message_body: Vec<u8>,
    account_metas: Vec<AccountMeta>,
    account_infos: &[AccountInfo],
) -> Result<H256> {
    // The recipient is the remote router, which must be enrolled.
    let dispatch_instruction = MailboxInstruction::OutboxDispatch(MailboxOutboxDispatch {
        sender: *program_id,
        destination_domain,
        recipient,
        message_body,
    });
    let mailbox = self.mailbox();
    let mailbox_ixn = Instruction {
        program_id: *mailbox,
        data: dispatch_instruction.into_instruction_data()?,
        accounts: account_metas,
    };
    // Call the Mailbox program to dispatch the message.
    invoke_signed(&mailbox_ixn, account_infos, &[dispatch_authority_seeds])?;

    // Parse the message ID from the return data from the prior dispatch.
    let (returning_program_id, returned_data) =
        get_return_data().ok_or(ProgramError::InvalidArgument)?;
    // The mailbox itself doesn't make any CPIs, but as a sanity check we confirm
    // that the return data is from the mailbox.
    if returning_program_id != *mailbox {
        return Err(ProgramError::InvalidArgument);
    }
    let message_id: H256 =
        H256::try_from_slice(&returned_data).map_err(|_| ProgramError::InvalidArgument)?;

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
    igp_program_id: &Pubkey,
) -> Result<H256, ProgramError> {
    let message_id = self.dispatch(
        program_id,
        dispatch_authority_seeds,
        destination_domain,
        message_body,
        dispatch_account_metas,
        dispatch_account_infos,
    )?;

    // Call the IGP to pay for gas.
    let (igp_program_id, _) = self
        .interchain_gas_paymaster()
        .ok_or(ProgramError::InvalidArgument)?;

    let igp_ixn = Instruction::new_with_borsh(
        *igp_program_id,
        &IgpInstruction::PayForGas(IgpPayForGas {
            message_id,
            destination_domain,
            gas_amount,
        }),
        payment_account_metas,
    );

    invoke(&igp_ixn, payment_account_infos)?;

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
pub fn transfer_remote(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    xfer: TransferRemote,
) -> Result<()> {
    let accounts_iter = &mut accounts.iter();

    // Account 0: System program.
    let system_program_account = next_account_info(accounts_iter)?;
    if system_program_account.key != &solana_program::system_program::id() {
        return err!(SpokeError::InvalidAccount);
    }

    // Account 1: SPL Noop.
    let spl_noop = next_account_info(accounts_iter)?;
    if spl_noop.key != &spl_noop::id() {
        return err!(SpokeError::InvalidAccount);
    }

    // Account 2: Token storage account
    let token_account = next_account_info(accounts_iter)?;
    let token =
        HyperlaneTokenAccount::fetch(&mut &token_account.data.borrow()[..])?.into_inner();
    let token_seeds: &[&[u8]] = hyperlane_token_pda_seeds!(token.bump);
    let expected_token_key = Pubkey::create_program_address(token_seeds, program_id)?;
    if token_account.key != &expected_token_key {
        return Err(ProgramError::InvalidArgument);
    }
    if token_account.owner != program_id {
        return Err(ProgramError::IncorrectProgramId);
    }

    // Account 3: Mailbox program
    let mailbox_info = next_account_info(accounts_iter)?;
    if mailbox_info.key != &token.mailbox {
        return Err(ProgramError::IncorrectProgramId);
    }

    // Account 4: Mailbox Outbox data account.
    // No verification is performed here, the Mailbox will do that.
    let mailbox_outbox_account = next_account_info(accounts_iter)?;

    // Account 5: Message dispatch authority
    let dispatch_authority_account = next_account_info(accounts_iter)?;
    let dispatch_authority_seeds: &[&[u8]] =
        mailbox_message_dispatch_authority_pda_seeds!(token.dispatch_authority_bump);
    let dispatch_authority_key =
        Pubkey::create_program_address(dispatch_authority_seeds, program_id)?;
    if *dispatch_authority_account.key != dispatch_authority_key {
        return Err(ProgramError::InvalidArgument);
    }

    // Account 6: Sender account / mailbox payer
    let sender_wallet = next_account_info(accounts_iter)?;
    if !sender_wallet.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // Account 7: Unique message / gas payment account
    // Defer to the checks in the Mailbox / IGP, no need to verify anything here.
    let unique_message_account = next_account_info(accounts_iter)?;

    // Account 8: Message storage PDA.
    // Similarly defer to the checks in the Mailbox to ensure account validity.
    let dispatched_message_pda = next_account_info(accounts_iter)?;

    let igp_payment_accounts =
        if let Some((igp_program_id, igp_account_type)) = token.interchain_gas_paymaster() {
            // Account 9: The IGP program
            let igp_program_account = next_account_info(accounts_iter)?;
            if igp_program_account.key != igp_program_id {
                return Err(ProgramError::InvalidArgument);
            }

            // Account 10: The IGP program data.
            // No verification is performed here, the IGP will do that.
            let igp_program_data_account = next_account_info(accounts_iter)?;

            // Account 11: The gas payment PDA.
            // No verification is performed here, the IGP will do that.
            let igp_payment_pda_account = next_account_info(accounts_iter)?;

            // Account 12: The configured IGP account.
            let configured_igp_account = next_account_info(accounts_iter)?;
            if configured_igp_account.key != igp_account_type.key() {
                return Err(ProgramError::InvalidArgument);
            }

            // Accounts expected by the IGP's `PayForGas` instruction:
            //
            // 0. `[executable]` The system program.
            // 1. `[signer]` The payer.
            // 2. `[writeable]` The IGP program data.
            // 3. `[signer]` Unique gas payment account.
            // 4. `[writeable]` Gas payment PDA.
            // 5. `[writeable]` The IGP account.
            // 6. `[]` Overhead IGP account (optional).

            let mut igp_payment_account_metas = vec![
                AccountMeta::new_readonly(solana_program::system_program::id(), false),
                AccountMeta::new(*sender_wallet.key, true),
                AccountMeta::new(*igp_program_data_account.key, false),
                AccountMeta::new_readonly(*unique_message_account.key, true),
                AccountMeta::new(*igp_payment_pda_account.key, false),
            ];
            let mut igp_payment_account_infos = vec![
                system_program_account.clone(),
                sender_wallet.clone(),
                igp_program_data_account.clone(),
                unique_message_account.clone(),
                igp_payment_pda_account.clone(),
            ];

            match igp_account_type {
                InterchainGasPaymasterType::Igp(_) => {
                    igp_payment_account_metas
                        .push(AccountMeta::new(*configured_igp_account.key, false));
                    igp_payment_account_infos.push(configured_igp_account.clone());
                }
                InterchainGasPaymasterType::OverheadIgp(_) => {
                    // Account 13: The inner IGP account.
                    let inner_igp_account = next_account_info(accounts_iter)?;

                    // The inner IGP is expected first, then the overhead IGP.
                    igp_payment_account_metas.extend([
                        AccountMeta::new(*inner_igp_account.key, false),
                        AccountMeta::new_readonly(*configured_igp_account.key, false),
                    ]);
                    igp_payment_account_infos
                        .extend([inner_igp_account.clone(), configured_igp_account.clone()]);
                }
            };

            Some((igp_payment_account_metas, igp_payment_account_infos))
        } else {
            None
        };

    // The amount denominated in the local decimals.
    let local_amount: u64 = xfer
        .amount_or_id
        .try_into()
        .map_err(|_| Error::IntegerOverflow)?;
    // Convert to the remote number of decimals, which is universally understood
    // by the remote routers as the number of decimals used by the message amount.
    let remote_amount = token.local_amount_to_remote_amount(local_amount)?;

    // Transfer `local_amount` of tokens in...
    T::transfer_in(
        program_id,
        &*token,
        sender_wallet,
        accounts_iter,
        local_amount,
    )?;

    if accounts_iter.next().is_some() {
        return Err(ProgramError::from(Error::ExtraneousAccount));
    }

    let dispatch_account_metas = vec![
        AccountMeta::new(*mailbox_outbox_account.key, false),
        AccountMeta::new_readonly(*dispatch_authority_account.key, true),
        AccountMeta::new_readonly(solana_program::system_program::id(), false),
        AccountMeta::new_readonly(spl_noop::id(), false),
        AccountMeta::new(*sender_wallet.key, true),
        AccountMeta::new_readonly(*unique_message_account.key, true),
        AccountMeta::new(*dispatched_message_pda.key, false),
    ];
    let dispatch_account_infos = &[
        mailbox_outbox_account.clone(),
        dispatch_authority_account.clone(),
        system_program_account.clone(),
        spl_noop.clone(),
        sender_wallet.clone(),
        unique_message_account.clone(),
        dispatched_message_pda.clone(),
    ];

    // The token message body, which specifies the remote_amount.
    let token_transfer_message =
        TokenMessage::new(xfer.recipient, remote_amount, vec![]).to_vec();

    if let Some((igp_payment_account_metas, igp_payment_account_infos)) = igp_payment_accounts {
        // Dispatch the message and pay for gas.
        dispatch_with_gas(
            &*token,
            program_id,
            dispatch_authority_seeds,
            xfer.destination_domain,
            token_transfer_message,
            dispatch_account_metas,
            dispatch_account_infos,
            igp_payment_account_metas,
            &igp_payment_account_infos,
            igp_program_id,
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
