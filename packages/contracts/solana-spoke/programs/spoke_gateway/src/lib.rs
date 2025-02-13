use anchor_lang::prelude::*;
pub mod spoke_storage;

declare_id!("4GszpA8CayGibDsiaB91a4wsdNRS6ZkT4eErUvEW45Yf");

#[program]
pub mod spoke_gateway {
    use super::*;

    /// Initializes the gateway with required parameters
    pub fn initialize_gateway(
        ctx: Context<InitializeGateway>,
        owner: Pubkey,
        mailbox: Pubkey,
        receiver: Pubkey,
        interchain_security_module: Pubkey,
        everclear_id: u32,
        everclear_gateway: [u8; 32],
    ) -> Result<()> {
        let state = &mut ctx.accounts.state;
        
        require!(owner != Pubkey::default(), CustomError::InvalidOwner);
        require!(mailbox != Pubkey::default(), CustomError::InvalidMailbox);
        require!(receiver != Pubkey::default(), CustomError::InvalidReceiver);
        require!(interchain_security_module != Pubkey::default(), CustomError::InvalidSecurityModule);
        require!(everclear_id > 0, CustomError::InvalidEverclearId);
        
        state.owner = owner;
        state.mailbox = mailbox;
        state.receiver = receiver;
        state.interchain_security_module = interchain_security_module;
        state.everclear_id = everclear_id;
        state.everclear_gateway = everclear_gateway;
        state.paused = false;
        
        msg!("Gateway initialized with owner {}", owner);
        Ok(())
    }

    /// Pauses the gateway
    pub fn pause(ctx: Context<AdminAction>) -> Result<()> {
        let state = &mut ctx.accounts.state;
        require!(!state.paused, CustomError::AlreadyPaused);
        
        state.paused = true;
        msg!("Gateway paused by {}", ctx.accounts.owner.key());
        Ok(())
    }

    /// Unpauses the gateway
    pub fn unpause(ctx: Context<AdminAction>) -> Result<()> {
        let state = &mut ctx.accounts.state;
        require!(state.paused, CustomError::NotPaused);
        
        state.paused = false;
        msg!("Gateway unpaused by {}", ctx.accounts.owner.key());
        Ok(())
    }

    /// Sends a message through the gateway
    pub fn send_message(
        ctx: Context<SendMessage>,
        destination_domain: u32,
        recipient: [u8; 32],
        message_body: Vec<u8>
    ) -> Result<()> {
        let state = &ctx.accounts.state;
        require!(!state.paused, CustomError::GatewayPaused);
        require!(!message_body.is_empty(), CustomError::EmptyMessage);
        require!(message_body.len() <= 10240, CustomError::MessageTooLarge); // 10KB max
        
        msg!(
            "Sending message to domain {} recipient {:?}",
            destination_domain,
            recipient
        );
        
        // In production:
        // 1. Calculate fees
        // 2. Verify sender has enough balance
        // 3. Make CPI call to mailbox
        // 4. Update state if necessary
        
        Ok(())
    }
}

#[derive(Accounts)]
pub struct InitializeGateway<'info> {
    /// The gateway state account
    #[account(mut)]
    pub state: Account<'info, SpokeGatewayState>,
    
    /// The account paying for the transaction
    #[account(mut)]
    pub payer: Signer<'info>,
    
    /// The system program
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct AdminAction<'info> {
    /// The gateway state account
    #[account(mut, has_one = owner @ CustomError::Unauthorized)]
    pub state: Account<'info, SpokeGatewayState>,
    
    /// The owner of the gateway
    pub owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct SendMessage<'info> {
    /// The gateway state account
    #[account(mut)]
    pub state: Account<'info, SpokeGatewayState>,
    
    /// The account paying for the message
    #[account(mut)]
    pub payer: Signer<'info>,
}

#[account]
pub struct SpokeGatewayState {
    /// The owner of the gateway
    pub owner: Pubkey,
    /// The mailbox contract address
    pub mailbox: Pubkey,
    /// The message receiver contract address
    pub receiver: Pubkey,
    /// The interchain security module address
    pub interchain_security_module: Pubkey,
    /// The Everclear identifier
    pub everclear_id: u32,
    /// The Everclear gateway address (as bytes)
    pub everclear_gateway: [u8; 32],
    /// Whether the gateway is paused
    pub paused: bool,
}

impl SpokeGatewayState {
    pub const LEN: usize = 8 + // discriminator
        32 + // owner
        32 + // mailbox
        32 + // receiver
        32 + // interchain_security_module
        4 + // everclear_id
        32 + // everclear_gateway
        1; // paused
}

#[error_code]
pub enum CustomError {
    #[msg("Invalid owner address")]
    InvalidOwner,
    #[msg("Invalid mailbox address")]
    InvalidMailbox,
    #[msg("Invalid receiver address")]
    InvalidReceiver,
    #[msg("Invalid security module address")]
    InvalidSecurityModule,
    #[msg("Invalid Everclear ID")]
    InvalidEverclearId,
    #[msg("Gateway is paused")]
    GatewayPaused,
    #[msg("Gateway is already paused")]
    AlreadyPaused,
    #[msg("Gateway is not paused")]
    NotPaused,
    #[msg("Unauthorized")]
    Unauthorized,
    #[msg("Empty message")]
    EmptyMessage,
    #[msg("Message too large")]
    MessageTooLarge,
    #[msg("Insufficient funds for message fee")]
    InsufficientFunds,
} 
