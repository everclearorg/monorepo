use anchor_lang::prelude::*;
use anchor_lang::solana_program::{
    instruction::Instruction,
    program::{get_return_data, invoke, invoke_signed},
    system_program,
};
use anchor_spl::associated_token::get_associated_token_address;
use anchor_spl::token::{spl_token, spl_token::native_mint};

use crate::messaging::ccip::message::SVM2AnyMessage;

pub const CCIP_FEE_QUOTER: Pubkey = pubkey!("FeeQPGkKDeRV1MgoYfMH6L8o3KeuYjwUZrgn4LRKfjHi");
pub const CCIP_RMN: Pubkey = pubkey!("RmnXLft1mSEwDgMKu2okYuHkiazxntFFcZFrrcXxYg7");
pub const NATIVE_MINT: Pubkey = native_mint::ID;
const LINK_MINT: Pubkey = pubkey!("LinkhB3afbBKb2EQQu7s7umdZceV3wcvAUJhQAfQ23L");

pub fn build_ccip_send_accounts(
    router_program: &Pubkey,
    fee_quoter_program: &Pubkey,
    rmn_program: &Pubkey,
    authority: &Pubkey,
    dest_chain_selector: u64,
) -> Result<Vec<AccountMeta>> {
    let (config_pda, _) = Pubkey::find_program_address(&[b"config"], router_program);
    let (dest_chain_state_pda, _) = Pubkey::find_program_address(
        &[b"dest_chain_state", &dest_chain_selector.to_le_bytes()],
        router_program,
    );
    let (nonce_pda, _) = Pubkey::find_program_address(
        &[b"nonce", &dest_chain_selector.to_le_bytes(), authority.as_ref()],
        router_program,
    );
    let (fee_billing_signer_pda, _) =
        Pubkey::find_program_address(&[b"fee_billing_signer"], router_program);
    let (fee_quoter_config_pda, _) =
        Pubkey::find_program_address(&[b"config"], fee_quoter_program);
    let (fee_quoter_dest_chain_pda, _) = Pubkey::find_program_address(
        &[b"dest_chain", &dest_chain_selector.to_le_bytes()],
        fee_quoter_program,
    );
    let (fee_quoter_billing_token_config_pda, _) = Pubkey::find_program_address(
        &[b"fee_billing_token_config", NATIVE_MINT.as_ref()],
        fee_quoter_program,
    );
    let (fee_quoter_link_token_config_pda, _) = Pubkey::find_program_address(
        &[b"fee_billing_token_config", LINK_MINT.as_ref()],
        fee_quoter_program,
    );
    let (rmn_curses_pda, _) = Pubkey::find_program_address(&[b"curses"], rmn_program);
    let (rmn_config_pda, _) = Pubkey::find_program_address(&[b"config"], rmn_program);

    let fee_token_receiver = get_associated_token_address(&fee_billing_signer_pda, &NATIVE_MINT);
    let accounts = vec![
        AccountMeta::new_readonly(config_pda, false),
        AccountMeta::new(dest_chain_state_pda, false),
        AccountMeta::new(nonce_pda, false),
        AccountMeta::new(*authority, true),
        AccountMeta::new_readonly(system_program::id(), false),
        AccountMeta::new_readonly(spl_token::ID, false),
        AccountMeta::new_readonly(NATIVE_MINT, false),
        AccountMeta::new_readonly(Pubkey::default(), false),
        AccountMeta::new(fee_token_receiver, false),
        AccountMeta::new_readonly(fee_billing_signer_pda, false),
        AccountMeta::new_readonly(*fee_quoter_program, false),
        AccountMeta::new_readonly(fee_quoter_config_pda, false),
        AccountMeta::new_readonly(fee_quoter_dest_chain_pda, false),
        AccountMeta::new_readonly(fee_quoter_billing_token_config_pda, false),
        AccountMeta::new_readonly(fee_quoter_link_token_config_pda, false),
        AccountMeta::new_readonly(*rmn_program, false),
        AccountMeta::new_readonly(rmn_curses_pda, false),
        AccountMeta::new_readonly(rmn_config_pda, false),
    ];

    Ok(accounts)
}

pub fn ccip_send<'info>(
    router_program: &Pubkey,
    authority_seeds: &[&[&[u8]]],
    dest_chain_selector: u64,
    message: SVM2AnyMessage,
    token_indexes: Vec<u8>,
    account_metas: Vec<AccountMeta>,
    account_infos: &[AccountInfo<'info>],
) -> Result<[u8; 32]> {
    let mut instruction_data = Vec::new();
    instruction_data.extend_from_slice(&[0x6c, 0xd8, 0x86, 0xbf, 0xf9, 0xea, 0x21, 0x54]);
    instruction_data.extend_from_slice(&dest_chain_selector.to_le_bytes());
    message.serialize(&mut instruction_data)?;
    token_indexes.serialize(&mut instruction_data)?;

    let instruction = Instruction {
        program_id: *router_program,
        accounts: account_metas,
        data: instruction_data,
    };

    invoke_signed(&instruction, account_infos, authority_seeds)?;
    let (returning_program_id, returned_data) =
        get_return_data().ok_or(error!(crate::error::SpokeError::InvalidMessage))?;
    require!(
        *router_program == returning_program_id,
        crate::error::SpokeError::InvalidMessage
    );
    require!(
        returned_data.len() == 32,
        crate::error::SpokeError::InvalidMessage
    );
    
    let mut message_id = [0u8; 32];
    message_id.copy_from_slice(&returned_data);
    Ok(message_id)
}
