
use anchor_lang::prelude::*;
use anchor_lang::AnchorDeserialize;

mod ccip;

use ccip::message::SVM2AnyMessage;
use ccip::{build_ccip_send_accounts, ccip_send};

declare_id!("CTYK59jTDbqL8HQ9A6eyg2vNDTb6Bd5muDeugPL5n1Dd");

pub const CCIP_ROUTER: Pubkey = pubkey!("Ccip842gzYHhvdDkSyi2YVCoAWPbYJoApMFzSxQroE9C");
pub const CCIP_FEE_QUOTER: Pubkey = pubkey!("FeeQPGkKDeRV1MgoYfMH6L8o3KeuYjwUZrgn4LRKfjHi");
pub const CCIP_RMN: Pubkey = pubkey!("RmnXLft1mSEwDgMKu2okYuHkiazxntFFcZFrrcXxYg7");
pub const CCIP_OFFRAMP_ETHEREUM: Pubkey = pubkey!("offqSMQWgQud6WJz694LRzkeN5kMYpCHTpXQr3Rkcjm");

#[program]
pub mod ccip_poc {
    use super::*;

    pub fn initialize(
        ctx: Context<Initialize>,
        ccip_router: Pubkey,
        ccip_offramp: Pubkey,
        source_chain_selector: u64,
        expected_sender: Vec<u8>,
    ) -> Result<()> {
        let state = &mut ctx.accounts.state;
        state.owner = ctx.accounts.owner.key();
        state.ccip_router = ccip_router;
        state.ccip_offramp = ccip_offramp;
        state.source_chain_selector = source_chain_selector;
        state.expected_sender = expected_sender;
        Ok(())
    }

    pub fn send_message(
        ctx: Context<SendMessage>,
        destination_chain: u64,
        receiver: [u8; 32],
        data: Vec<u8>,
    ) -> Result<()> {
        let state = &ctx.accounts.state;
        let authority = &ctx.accounts.sender;
        
        let message = SVM2AnyMessage::new_data_only(receiver.to_vec(), data);
        
        let account_metas = build_ccip_send_accounts(
            &state.ccip_router,
            &CCIP_FEE_QUOTER,
            &CCIP_RMN,
            authority.key,
            destination_chain,
        )?;
        
        require!(
            ctx.remaining_accounts.len() >= account_metas.len() + 1,
            POCError::InvalidMessage
        );
        
        // First account should be Router program for CPI
        require!(
            ctx.remaining_accounts[0].key() == state.ccip_router,
            POCError::InvalidMessage
        );
        
        let acc_metas: Vec<AccountMeta> = account_metas
            .iter()
            .enumerate()
            .map(|(i, expected_meta)| {
                let acc_info = &ctx.remaining_accounts[i + 1];
                AccountMeta {
                    pubkey: acc_info.key(),
                    is_signer: expected_meta.is_signer || acc_info.is_signer,
                    is_writable: expected_meta.is_writable,
                }
            })
            .collect();
        
        let acc_infos_slice = &ctx.remaining_accounts[0..=account_metas.len()];
        let message_id = ccip_send(
            &state.ccip_router,
            &ctx.remaining_accounts[4],
            &[],
            destination_chain,
            message,
            Vec::new(),
            acc_metas,
            acc_infos_slice,
        )?;
        
        msg!("CCIP message sent: {:?}", message_id);
        Ok(())
    }

    #[instruction(discriminator = [0x0b, 0xf4, 0x09, 0xf9, 0x2c, 0x53, 0x2f, 0xf5])]
    pub fn ccip_receive(
        ctx: Context<ReceiveMessage>,
        message: Any2SVMMessage,
    ) -> Result<()> {
        let state = &ctx.accounts.state;

        // Validate offramp program matches expected
        require!(
            ctx.accounts.offramp_program.key() == state.ccip_offramp,
            POCError::InvalidCaller
        );
        
        require!(
            ctx.accounts.allowed_offramp.owner == &state.ccip_router,
            POCError::InvalidCaller
        );
        
        let (expected_allowed_offramp, _) = Pubkey::find_program_address(
            &[
                b"allowed_offramp",
                &message.source_chain_selector.to_le_bytes(),
                ctx.accounts.offramp_program.key().as_ref(),
            ],
            &state.ccip_router,
        );
        require_keys_eq!(
            ctx.accounts.allowed_offramp.key(),
            expected_allowed_offramp,
            POCError::InvalidCaller
        );
        
        require!(
            message.source_chain_selector == state.source_chain_selector,
            POCError::InvalidOrigin
        );
        
        let start_idx = if let Some(pos) = state.expected_sender.iter().position(|&b| b != 0) {
            pos
        } else {
            state.expected_sender.len().saturating_sub(20)
        };
        
        let end_idx = (start_idx + 20).min(state.expected_sender.len());
        let expected_addr = &state.expected_sender[start_idx..end_idx];
        
        require!(
            message.sender == expected_addr,
            POCError::InvalidSender
        );
        
        Ok(())
    }

    pub fn close(ctx: Context<Close>) -> Result<()> {
        let state = &ctx.accounts.state;
        require!(
            ctx.accounts.owner.key() == state.owner,
            POCError::InvalidCaller
        );
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = owner,
        space = 8 + 32 + 32 + 32 + 8 + 4 + 32,
        seeds = [b"poc-state"],
        bump
    )]
    pub state: Account<'info, POCState>,
    
    #[account(
        seeds = [b"external_execution_config"],
        bump,
    )]
    pub external_execution_config: Account<'info, ExternalExecutionConfig>,
    
    #[account(mut)]
    pub owner: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct SendMessage<'info> {
    #[account(
        seeds = [b"poc-state"],
        bump
    )]
    pub state: Account<'info, POCState>,
    
    #[account(mut)]
    pub sender: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(message: Any2SVMMessage)]
pub struct ReceiveMessage<'info> {
    #[account(
        seeds = [b"external_execution_config", crate::ID.as_ref()],
        bump,
        seeds::program = offramp_program.key(),
    )]
    pub authority: Signer<'info>,
    
    /// CHECK: Offramp program - exists only to derive the allowed offramp PDA and authority PDA
    pub offramp_program: UncheckedAccount<'info>,
    
    /// CHECK: PDA of the router program verifying the signer is an allowed offramp
    #[account(
        owner = state.ccip_router @ POCError::InvalidCaller,
        seeds = [
            b"allowed_offramp",
            message.source_chain_selector.to_le_bytes().as_ref(),
            offramp_program.key().as_ref()
        ],
        bump,
        seeds::program = state.ccip_router,
    )]
    pub allowed_offramp: UncheckedAccount<'info>,
    
    #[account(mut, seeds = [b"external_execution_config"], bump)]
    pub external_execution_config: Account<'info, ExternalExecutionConfig>,
    
    #[account(
        mut,
        seeds = [b"poc-state"],
        bump,
    )]
    pub state: Account<'info, POCState>,
}

#[derive(Accounts)]
pub struct Close<'info> {
    #[account(
        mut,
        seeds = [b"poc-state"],
        bump,
        close = owner,
        has_one = owner @ POCError::InvalidCaller
    )]
    pub state: Account<'info, POCState>,
    
    #[account(mut)]
    pub owner: Signer<'info>,
}

#[account]
pub struct POCState {
    pub owner: Pubkey,
    pub ccip_router: Pubkey,
    pub ccip_offramp: Pubkey,
    pub source_chain_selector: u64,
    pub expected_sender: Vec<u8>,
}

#[account]
pub struct ExternalExecutionConfig {}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct Any2SVMMessage {
    pub message_id: [u8; 32],
    pub source_chain_selector: u64,
    pub sender: Vec<u8>,
    pub data: Vec<u8>,
    pub token_amounts: Vec<TokenAmount>,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct TokenAmount {
    pub token: Pubkey,
    pub amount: u64,
}

#[error_code]
pub enum POCError {
    #[msg("Invalid caller - must be CCIP OffRamp program")]
    InvalidCaller,
    #[msg("Invalid origin - source chain selector mismatch")]
    InvalidOrigin,
    #[msg("Invalid sender - sender address mismatch")]
    InvalidSender,
    #[msg("Invalid message format or return data")]
    InvalidMessage,
}


