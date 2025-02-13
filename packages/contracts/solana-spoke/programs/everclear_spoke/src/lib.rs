use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Mint, Transfer};
// use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer, TransferChecked, MintTo, Burn};
use anchor_spl::associated_token::{get_associated_token_address};
use std::collections::{VecDeque, HashMap};

// Constants
pub const HYPERLANE_MAILBOX_PROGRAM_ID: Pubkey = Pubkey::new_from_array([0; 32]);
pub const THIS_DOMAIN: u32 = 1234;       // This spoke's domain ID
pub const EVERCLEAR_DOMAIN: u32 = 9999;  // Hub's domain ID
pub const MAX_INTENT_QUEUE_SIZE: usize = 1000;
pub const MAX_FILL_QUEUE_SIZE: usize = 1000;
pub const MAX_CALLDATA_SIZE: usize = 10240; // 10KB
pub const DBPS_DENOMINATOR: u32 = 10_000;
pub const DEFAULT_NORMALIZED_DECIMALS: u8 = 18;

// TODO: Need to define these hashes
pub const GATEWAY_HASH: [u8; 32] = [0x01; 32]; // placeholder
pub const MAILBOX_HASH: [u8; 32] = [0x02; 32]; // placeholder
pub const LIGHTHOUSE_HASH: [u8; 32] = [0x03; 32]; // placeholder
pub const WATCHTOWER_HASH: [u8; 32] = [0x04; 32]; // placeholder

pub const FILL_INTENT_FOR_SOLVER_TYPEHASH: [u8; 32] = [0xAA; 32]; // placeholder
pub const PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH: [u8; 32] = [0xBB; 32];
pub const PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH: [u8; 32] = [0xCC; 32];

declare_id!("uvXqfnsfugQTAbd8Wy7xUBQDhcREMGZZeCUb1Y3fXLC");

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct SpokeInitializationParams {
    pub domain: u32,
    pub hub_domain: u32,
    pub lighthouse: Pubkey,
    pub watchtower: Pubkey,
    pub call_executor: Pubkey,
    pub message_receiver: Pubkey,
    pub gateway: Pubkey,
    pub message_gas_limit: u64,
    pub owner: Pubkey,
}

#[program]
pub mod everclear_spoke {
    use super::*;
    
    // TODO: Do we need to add initializer modifier to this?
    /// Initialize the global state.
    /// This function creates the SpokeState (global config) PDA.
    #[access_control(&ctx.accounts.ensure_owner_is_valid(&init.owner))]
    pub fn initialize(
        ctx: Context<Initialize>,
        init: SpokeInitializationParams,
    ) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;

        require!(state.initialized_version == 0, SpokeError::AlreadyInitialized);
        state.initialized_version = 1;

        state.paused = false;
        state.domain = init.domain;
        state.gateway = init.gateway;
        state.message_receiver = init.message_receiver;
        state.lighthouse = init.lighthouse;
        state.watchtower = init.watchtower;
        state.call_executor = init.call_executor;
        state.everclear = init.hub_domain;
        state.message_gas_limit = init.message_gas_limit;
        state.nonce = 0;
        
        // Initialize our mappings and queues
        state.intent_queue = QueueState::new();
        state.balances = HashMap::new();
        state.status = HashMap::new();
        
        // Set owner to the payer (deployer)
        state.owner = init.owner;
        state.bump = ctx.bumps.spoke_state;
        
        emit!(InitializedEvent {
            owner: state.owner,
            domain: state.domain,
            everclear: state.everclear,
        });
        Ok(())
    }

    /// Pause the program.
    /// Only the lighthouse or watchtower can call this.
    pub fn pause(ctx: Context<AuthState>) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.lighthouse == ctx.accounts.authority.key() || state.watchtower == ctx.accounts.authority.key(),
            SpokeError::NotAuthorizedToPause
        );
        state.paused = true;
        emit!(PausedEvent {});
        Ok(())
    }

    /// Unpause the program.
    pub fn unpause(ctx: Context<AuthState>) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(
            state.lighthouse == ctx.accounts.authority.key() || state.watchtower == ctx.accounts.authority.key(),
            SpokeError::NotAuthorizedToPause
        );
        state.paused = false;
        emit!(UnpausedEvent {});
        Ok(())
    }

    /// Withdraw SPL tokens from the program's vault.
    /// This reduces the user's on‑chain balance and transfers tokens out.
    pub fn withdraw(
        ctx: Context<Withdraw>,
        vault_authority_bump: u8,
        amount: u64,
    ) -> Result<()> {
        let state = &ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        require!(amount > 0, SpokeError::InvalidAmount);

        // Check the user has sufficient balance.
        reduce_balance(&mut ctx.accounts.spoke_state.balances, ctx.accounts.mint.key(), ctx.accounts.user_authority.key(), amount)?;
        
        // Transfer tokens from the vault to the user's token account.
        // The vault is owned by a PDA (program_vault_authority).
        let seeds = vault_authority_seeds(&ID, &ctx.accounts.mint.key(), vault_authority_bump);
        let signer_seeds = [
            &seeds[0][..],
            &seeds[1][..],
            &seeds[2][..],
            &seeds[3][..],
        ];
        let signer = &[&signer_seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.from_token_account.to_account_info(),
            to: ctx.accounts.to_token_account.to_account_info(),
            authority: ctx.accounts.vault_authority.to_account_info(),
        };
        let cpi_ctx = CpiContext::new_with_signer(ctx.accounts.token_program.to_account_info(), cpi_accounts, signer);
        token::transfer(cpi_ctx, amount)?;
        emit!(WithdrawnEvent {
            user: ctx.accounts.user_authority.key(),
            asset: ctx.accounts.mint.key(),
            amount,
        });
        Ok(())
    }

    /// Create a new intent.
    /// The user "locks" funds (previously deposited) and creates an intent.
    /// For simplicity, we assume full deposit has been made before.
    pub fn new_intent(
        ctx: Context<NewIntent>,
        receiver: Pubkey,
        input_asset: Pubkey,
        output_asset: Pubkey,
        amount: u64,
        max_fee: u32,
        ttl: u64,
        destinations: Vec<u32>,
        data: Vec<u8>,
    ) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        require!(destinations.len() > 0, SpokeError::InvalidOperation);
        require!(destinations.len() <= 10, SpokeError::InvalidIntent);

        // If a single destination and ttl != 0, require output_asset is non-zero.
        if destinations.len() == 1 {
            require!(output_asset != Pubkey::default(), SpokeError::InvalidIntent);
        } else {
            // For multi-destination, ttl must be 0 and output_asset must be default.
            require!(ttl == 0 && output_asset == Pubkey::default(), SpokeError::InvalidIntent);
        }
        // Check max_fee is within allowed range (for example, <= 10_000 for basis points)
        require!(max_fee <= 10_000, SpokeError::MaxFeeExceeded);
        require!(data.len() <= MAX_CALLDATA_SIZE, SpokeError::InvalidOperation);

        let minted_decimals = ctx.accounts.mint.decimals;
        let normalized_amount = normalize_decimals(
            amount,
            minted_decimals,
            DEFAULT_NORMALIZED_DECIMALS,
        )?;
        require!(normalized_amount > 0, SpokeError::ZeroAmount);  // Add zero amount check like Solidity

        // Transfer from user's token account -> program's vault
        let cpi_accounts = Transfer {
            from: ctx.accounts.user_token_account.to_account_info(),
            to: ctx.accounts.program_vault_account.to_account_info(),
            authority: ctx.accounts.authority.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
        token::transfer(cpi_ctx, amount)?;

        // Update global nonce and create intent_id
        let new_nonce = state.nonce.checked_add(1).ok_or(SpokeError::InvalidOperation)?;
        state.nonce = new_nonce;
        let clock = Clock::get()?;
        
        // Create intent_id with all parameters
        // TODO: May need to encode this properly
        // TODO: Would need to update processIntentQueue logic on update
        // TODO: Check the clock operation here
        let new_intent_struct = Intent {
            initiator: ctx.accounts.authority.key(),
            receiver,
            input_asset,
            output_asset,
            max_fee,
            origin_domain: state.domain,
            nonce: new_nonce,
            timestamp: clock.unix_timestamp as u64,
            ttl,
            normalized_amount,
            destinations: destinations.clone(),
            data: data.clone(),
        };
        
        let intent_id = compute_intent_hash(&new_intent_struct);

        // Update intent queue and status
        state.intent_queue.push_back(intent_id);

        // Also, record a minimal status mapping (we only record the intent_id and its status).
        state.status.insert(intent_id, IntentStatus::Added);

        // Emit an event with full intent details.
        emit!(IntentAddedEvent {
            intent_id,
            initiator: ctx.accounts.authority.key(),
            receiver,
            input_asset,
            output_asset,
            normalized_amount,
            max_fee,
            origin_domain: state.domain,
            ttl,
            timestamp: clock.unix_timestamp as u64,
            destinations,
            data,
        });
        
        // TODO: Do we need this for off-chain logic?
        // let queue_index = state.intent_queue.last_index();   
        // emit!(IntentAddedEvent { ..., queue_index, ... });

        Ok(())
    }

    /// Process a batch of intents in the queue and dispatch a cross-chain message via Hyperlane.
    pub fn process_intent_queue(
        ctx: Context<AuthState>, 
        intents: Vec<Intent>,  // Pass full intents, not just count
        message_gas_limit: u64
    ) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        require!(intents.len() > 0, SpokeError::InvalidAmount);
        require!(intents.len() <= state.intent_queue.len(), SpokeError::InvalidQueueOperation);

        // Verify each intent matches the queue
        // NOTE: Commenting as not emitting the event
        // let old_first = state.intent_queue.first_index();
        for intent in intents.iter() {
            let queue_intent_id = state.intent_queue.pop_front()
                .ok_or(SpokeError::InvalidQueueOperation)?;
        
            let computed = compute_intent_hash(intent);
            require!(queue_intent_id == computed, SpokeError::IntentNotFound);
        }

        // Format message using proper message lib
        let batch_message = super::format_intent_message_batch(&intents)?;

        // Call Hyperlane with proper gas handling
        let ix_data = {
            let mut data = Vec::new();
            data.extend_from_slice(&EVERCLEAR_DOMAIN.to_be_bytes());
            data.extend_from_slice(&state.gateway.to_bytes());
            data.extend_from_slice(&message_gas_limit.to_be_bytes());
            data.extend_from_slice(&batch_message);
            data
        };
        let ix = anchor_lang::solana_program::instruction::Instruction {
            program_id: ctx.accounts.hyperlane_mailbox.key(),
            accounts: vec![],
            data: ix_data,
        };
        // TODO: Not handling messageId or fee spent here
        anchor_lang::solana_program::program::invoke(
            &ix,
            &[ctx.accounts.hyperlane_mailbox.to_account_info()],
        )?;
        
        // TODO: Need the meesage_id and fee spent data from above
        // emit!(IntentQueueProcessedEvent {
        //     message_id,
        //     first_index: old_first,
        //     last_index: old_first + intents.len() as u64,
        //     fee_spent,
        // });
        Ok(())
    }

    /// Receive a cross‑chain message via Hyperlane.
    /// In production, this would be invoked via CPI from Hyperlane's Mailbox.
    pub fn receive_message<'a>(
        ctx: Context<'_, '_, 'a, 'a, AuthState<'a>>,
        origin: u32,
        sender: Pubkey,
        payload: Vec<u8>,
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
                    Pubkey::find_program_address(&[b"vault"], &ID);
                
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

    /// Update the gateway address (admin only).
    pub fn update_gateway(ctx: Context<AuthState>, new_gateway: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        let authority = ctx.accounts.authority.key();
        require!(state.owner == authority, SpokeError::OnlyOwner);

        _update_gateway(state, new_gateway)?;
        
        Ok(())
    }

    pub fn update_lighthouse(ctx: Context<AuthState>, new_lighthouse: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(state.owner == ctx.accounts.authority.key(), SpokeError::OnlyOwner);

        _update_lighthouse(state, new_lighthouse)?;
        Ok(())
    }

    pub fn update_watchtower(ctx: Context<AuthState>, new_watchtower: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(state.owner == ctx.accounts.authority.key(), SpokeError::OnlyOwner);

        _update_watchtower(state, new_watchtower)?;
        Ok(())
    }

    pub fn update_mailbox(ctx: Context<AuthState>, new_mailbox: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        // enforce only owner can do it
        require!(state.owner == ctx.accounts.authority.key(), SpokeError::OnlyOwner);

        _update_mailbox(state, new_mailbox)?;
        Ok(())
    }
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
        _update_gateway(state, new_gateway)?;
    } else if var_hash == MAILBOX_HASH {
        let new_mailbox: Pubkey = try_deserialize_a_pubkey(rest)?;
        _update_mailbox(state, new_mailbox)?;
    } else if var_hash == LIGHTHOUSE_HASH {
        let new_lighthouse: Pubkey = try_deserialize_a_pubkey(rest)?;
        _update_lighthouse(state, new_lighthouse)?;
    } else if var_hash == WATCHTOWER_HASH {
        let new_watchtower: Pubkey = try_deserialize_a_pubkey(rest)?;
        _update_watchtower(state, new_watchtower)?;
    } else {
        return err!(SpokeError::InvalidVarUpdate);
    }

    Ok(())
}

// =====================================================================
// ACCOUNTS, STATE, EVENTS, ERRORS, & HELPER FUNCTIONS
// =====================================================================

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = payer,
        space = 8 + SpokeState::SIZE,
        seeds = [b"spoke-state"],
        bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    #[account(mut)]
    pub payer: Signer<'info>,
    pub system_program: Program<'info, System>,
}

impl<'info> Initialize<'info> {
    pub fn ensure_owner_is_valid(&self, new_owner: &Pubkey) -> Result<()> {
        require!(
            *new_owner != Pubkey::default(),
            SpokeError::InvalidOwner
        );
        Ok(())
    }
}

#[derive(Accounts)]
pub struct AuthState<'info> {
    #[account(mut)]
    pub spoke_state: Account<'info, SpokeState>,
    pub authority: Signer<'info>,
    #[account(mut)]
    pub vault_token_account: Account<'info, TokenAccount>,
    /// CHECK: This is a PDA that signs for the vault
    pub vault_authority: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
    /// CHECK: This is the Hyperlane mailbox program
    pub hyperlane_mailbox: UncheckedAccount<'info>,
}

#[derive(Accounts)]
pub struct NewIntent<'info> {
    // The main state
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,

    // The user calling new_intent
    pub authority: Signer<'info>,

    // The mint of the token the user is depositing
    pub mint: Account<'info, Mint>,

    // The user's associated token account for that mint
    #[account(mut, constraint = user_token_account.mint == mint.key())]
    pub user_token_account: Account<'info, TokenAccount>,

    // The program's vault token account for that mint
    #[account(mut, constraint = program_vault_account.mint == mint.key())]
    pub program_vault_account: Account<'info, TokenAccount>,

    // The SPL token program
    pub token_program: Program<'info, Token>,
}

// Withdraw: Transfer tokens from program vault to user.
#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    #[account(mut)]
    pub user_authority: Signer<'info>,
    pub mint: Account<'info, Mint>,
    #[account(mut, constraint = from_token_account.mint == mint.key())]
    pub from_token_account: Account<'info, TokenAccount>,
    #[account(mut, constraint = to_token_account.mint == mint.key())]
    pub to_token_account: Account<'info, TokenAccount>,
    #[account(
        seeds = [b"vault"],
        bump,  // This will use the bump passed in through the instruction
    )]
    /// CHECK: This is a PDA that signs for the vault.
    pub vault_authority: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
}

// Context for the settlements
#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct Settlement {
    pub intent_id: [u8; 32],
    pub asset: Pubkey,
    pub recipient: Pubkey,
    pub amount: u64,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct Intent {
    pub initiator: Pubkey,
    pub receiver: Pubkey,
    pub input_asset: Pubkey,
    pub output_asset: Pubkey,
    pub max_fee: u32,
    pub origin_domain: u32,
    pub nonce: u64,
    pub timestamp: u64,
    pub ttl: u64,
    pub normalized_amount: u64,
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
}

/// Context for Hyperlane dispatch: We require a Hyperlane mailbox account.
#[derive(Accounts)]
pub struct HyperlaneDispatch<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    /// CHECK: This account must be the Hyperlane Mailbox program.
    pub hyperlane_mailbox: UncheckedAccount<'info>,
}

/// Queue state with first/last indices for efficient management
#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct QueueState<T> {
    pub items: VecDeque<T>,
    pub first_index: u64,
    pub last_index: u64,
}

impl<T> QueueState<T> {
    pub const SIZE: usize = 8  // discriminator
    + 4    // vec length prefix
    + 8    // first
    + 8;   // last
    // Add any other fixed size fields
    
    pub fn new() -> Self {
        Self {
            items: VecDeque::new(),
            first_index: 0,
            last_index: 0,
        }
    }

    pub fn push_back(&mut self, item: T) {
        self.items.push_back(item);
        self.last_index = self.last_index.saturating_add(1);
    }

    pub fn pop_front(&mut self) -> Option<T> {
        let item = self.items.pop_front();
        if item.is_some() {
            self.first_index = self.first_index.saturating_add(1);
        }
        item
    }

    pub fn len(&self) -> usize {
        self.items.len()
    }
}

/// SpokeState – global configuration.
#[account]
pub struct SpokeState {
    // Initializer version
    pub initialized_version: u8,
    // Paused flag.
    pub paused: bool,
    // Domain IDs.
    pub domain: u32,
    pub everclear: u32,
    // Addresses for key roles.
    pub lighthouse: Pubkey,
    pub watchtower: Pubkey,
    pub call_executor: Pubkey,
    pub message_receiver: Pubkey,
    pub gateway: Pubkey,
    // Message gas limit (stored, though not used on Solana).
    pub message_gas_limit: u64,
    // Global nonce for intents.
    pub nonce: u64,
    // Owner of the program (admin).
    pub owner: Pubkey,
    // Dynamic mappings/queues.
    pub balances: HashMap<Pubkey, HashMap<Pubkey, u64>>, // asset -> (user -> amount)
    pub status: HashMap<[u8; 32], IntentStatus>, // intent_id -> status
    pub intent_queue: QueueState<[u8;32]>,
    // Bump for PDA.
    pub bump: u8,
    // Mailbox address
    pub mailbox: Pubkey
}

impl SpokeState {
    pub const SIZE: usize = 1    // paused: bool
        + 4                      // domain: u32
        + 4                      // everclear: u32
        + 32 * 5                 // 5 Pubkeys
        + 8                      // message_gas_limit: u64
        + 8                      // nonce: u64
        + 32                     // owner: Pubkey
        + 4 + (MAX_INTENT_QUEUE_SIZE * (32 + 1))  // status HashMap
        + QueueState::<[u8;32]>::SIZE      // intent_queue
        + 1;                     // bump: u8
}

/// A simple record tracking a user's balance for a given asset.
#[derive(Clone, AnchorSerialize, AnchorDeserialize)]
pub struct BalanceRecord {
    pub asset: Pubkey,
    pub user: Pubkey,
    pub amount: u64,
}

impl BalanceRecord {
    pub const SIZE: usize = 32 + 32 + 8;
}

/// Intent status.
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum IntentStatus {
    None,
    Added,
    Filled,
    Settled,
    SettledAndManuallyExecuted,
}

// =====================================================================
// EVENTS
// =====================================================================

#[event]
pub struct InitializedEvent {
    pub owner: Pubkey,
    pub domain: u32,
    pub everclear: u32,
}

#[event]
pub struct PausedEvent {}

#[event]
pub struct UnpausedEvent {}

#[event]
pub struct WithdrawnEvent {
    pub user: Pubkey,
    pub asset: Pubkey,
    pub amount: u64,
}

#[event]
pub struct IntentAddedEvent {
    pub intent_id: [u8;32],
    pub initiator: Pubkey,
    pub receiver: Pubkey,
    pub input_asset: Pubkey,
    pub output_asset: Pubkey,
    pub normalized_amount: u64,
    pub max_fee: u32,
    pub origin_domain: u32,
    pub ttl: u64,
    pub timestamp: u64,
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
}

#[event]
pub struct IntentQueueProcessedEvent {
    pub message_id: [u8;32],
    pub first_index: u64,
    pub last_index: u64,
    pub fee_spent: u64,
}

#[event]
pub struct GatewayUpdatedEvent {
    pub old_gateway: Pubkey,
    pub new_gateway: Pubkey,
}

#[event]
pub struct MailboxUpdatedEvent {
    pub old_mailbox: Pubkey,
    pub new_mailbox: Pubkey,
}

#[event]
pub struct LighthouseUpdatedEvent {
    pub old_lighthouse: Pubkey,
    pub new_lighthouse: Pubkey,
}

#[event]
pub struct WatchtowerUpdatedEvent {
    pub old_watchtower: Pubkey,
    pub new_watchtower: Pubkey,
}


#[event]
pub struct MessageReceivedEvent {
    pub origin: u32,
    pub sender: Pubkey,
}

#[event]
pub struct AssetTransferFailed {
    pub asset: Pubkey,
    pub recipient: Pubkey,
    pub amount: u64,
}

#[event]
pub struct SettledEvent {
    pub intent_id: [u8; 32],
    pub recipient: Pubkey,
    pub asset: Pubkey,
    pub amount: u64,
}

// =====================================================================
// ERRORS
// =====================================================================

#[error_code]
pub enum SpokeError {
    #[msg("Only the contract owner can call this method.")]
    OnlyOwner,
    #[msg("Not authorized to pause.")]
    NotAuthorizedToPause,
    #[msg("Contract is paused.")]
    ContractPaused,
    #[msg("Invalid amount provided.")]
    InvalidAmount,
    #[msg("Invalid operation or overflow.")]
    InvalidOperation,
    #[msg("Intent not found.")]
    IntentNotFound,
    #[msg("Intent is in an invalid status for this operation.")]
    InvalidIntentStatus,
    #[msg("Max fee exceeded.")]
    MaxFeeExceeded,
    #[msg("Queue operation invalid (zero or too many items).")]
    InvalidQueueOperation,
    #[msg("Invalid origin for inbound message.")]
    InvalidOrigin,
    #[msg("Invalid sender for inbound message.")]
    InvalidSender,
    #[msg("Invalid or unknown message.")]
    InvalidMessage,
    #[msg("Unauthorized operation.")]
    Unauthorized,
    #[msg("Signature has expired")]
    SignatureExpired,
    #[msg("Invalid signature")]
    InvalidSignature,
    #[msg("Zero amount provided")]
    ZeroAmount,
    #[msg("Decimal conversion overflow")]
    DecimalConversionOverflow,
    #[msg("Already initialized")]
    AlreadyInitialized,
    #[msg("Invalid Owner")]
    InvalidOwner,
    #[msg("Invalid var update")]
    InvalidVarUpdate,
    #[msg("Invalid intent")]
    InvalidIntent,
}

// =====================================================================
// HELPER FUNCTIONS
// =====================================================================

fn increase_balance(
    balances: &mut HashMap<Pubkey, HashMap<Pubkey, u64>>,
    asset: Pubkey,
    user: Pubkey,
    amount: u64,
) {
    let user_balance = balances.entry(asset).or_insert_with(HashMap::new);
    *user_balance.entry(user).or_insert(0) += amount;
}

fn reduce_balance(
    balances: &mut HashMap<Pubkey, HashMap<Pubkey, u64>>,
    asset: Pubkey,
    user: Pubkey,
    amount: u64,
) -> Result<()> {
    let user_balance = balances.entry(asset).or_insert_with(HashMap::new);
    let current_balance = user_balance.get(&user).cloned().unwrap_or(0);
    require!(current_balance >= amount, SpokeError::InvalidAmount);
    *user_balance.entry(user).or_insert(current_balance - amount) = current_balance - amount;
    Ok(())
}

/// Minimal keccak256 using the tiny_keccak crate.
fn keccak_256(data: &[u8]) -> [u8; 32] {
    use tiny_keccak::{Hasher, Keccak};
    let mut hasher = Keccak::v256();
    hasher.update(data);
    let mut output = [0u8; 32];
    hasher.finalize(&mut output);
    output
}

fn handle_batch_settlement<'info>(
    state: &mut SpokeState,
    batch: Vec<Settlement>,
    vault_token_account: &Account<'info, TokenAccount>,
    vault_authority: &UncheckedAccount<'info>,
    vault_authority_bump: u8,
    token_program: &Program<'info, Token>,
    remaining_accounts: &'info [AccountInfo<'info>],
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
) -> Result<()> {
    // 1) Check if already settled
    let current_status = state.status.get(&settlement.intent_id).copied().unwrap_or(IntentStatus::None);
    if current_status == IntentStatus::Settled 
        || current_status == IntentStatus::SettledAndManuallyExecuted 
    {
        msg!("Intent already settled, ignoring");
        return Ok(());
    }

    // 2) Mark as settled in storage
    state.status.insert(settlement.intent_id, IntentStatus::Settled);

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
    let seeds = vault_authority_seeds(&ID, &vault_token_account.mint.key(), vault_authority_bump);
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

    let transfer_result = token::transfer(cpi_ctx, amount);

    if transfer_result.is_err() {
        // The transfer failed. Fallback to storing in user's local balance
        // e.g. store "settlement.amount" in the local ledger
        increase_balance(&mut state.balances, settlement.asset, settlement.recipient, amount);
        emit!(AssetTransferFailed {
            asset: settlement.asset,
            recipient: settlement.recipient,
            amount: amount,
        });
    }

    emit!(SettledEvent {
       intent_id: settlement.intent_id,
       recipient: settlement.recipient,
       asset: settlement.asset,
       amount: amount,
    });

    Ok(())
}

fn vault_authority_seeds<'a>(
    program_id: &Pubkey,
    mint_pubkey: &Pubkey,
    bump: u8,
) -> [Vec<u8>; 4] {
    [
        b"vault".to_vec(),
        mint_pubkey.to_bytes().to_vec(),
        program_id.to_bytes().to_vec(),
        vec![bump],
    ]
}

fn normalize_decimals(
    amount: u64,
    minted_decimals: u8,
    target_decimals: u8,
) -> Result<u64> {
    if minted_decimals == target_decimals {
        // No scaling needed
        return Ok(amount);
    } else if minted_decimals > target_decimals {
        // e.g. minted_decimals=9, target_decimals=6 => downscale
        let shift = minted_decimals - target_decimals;
        // prevent potential divide-by-zero or overshoot
        if shift > 12 {
            // you might fail or just saturate for large differences
            return err!(SpokeError::DecimalConversionOverflow);
        }
        Ok(amount / 10u64.pow(shift as u32))
    } else {
        // minted_decimals < target_decimals => upscale
        let shift = target_decimals - minted_decimals;
        // watch for overflow if we do big multiplications
        let factor = 10u64.checked_pow(shift as u32).ok_or(SpokeError::DecimalConversionOverflow)?;
        let scaled = amount.checked_mul(factor).ok_or(SpokeError::DecimalConversionOverflow)?;
        Ok(scaled)
    }
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

fn try_deserialize_a_pubkey(data: &[u8]) -> Result<Pubkey> {
    // 1) Ensure we have at least 32 bytes
    if data.len() < 32 {
        return err!(SpokeError::InvalidMessage);
    }

    // 2) Copy the first 32 bytes into a Pubkey
    let key_array: [u8; 32] = data[..32].try_into().map_err(|_| SpokeError::InvalidMessage)?;
    Ok(Pubkey::new_from_array(key_array))
}

fn format_intent_message_batch(intents: &[Intent]) -> Result<Vec<u8>> {
    // Example:
    let mut buffer = Vec::new();
    // e.g. prefix a message type byte
    buffer.push(1); 
    // then Borsh‐encode the `Vec<Intent>`
    let encoded = intents.try_to_vec()?;
    buffer.extend_from_slice(&encoded);
    Ok(buffer)
}

fn compute_intent_hash(intent: &Intent) -> [u8; 32] {
    let mut hasher_input = Vec::new();

    // 1) Initiator
    hasher_input.extend_from_slice(intent.initiator.as_ref());

    // 2) Receiver
    hasher_input.extend_from_slice(intent.receiver.as_ref());

    // 3) InputAsset
    hasher_input.extend_from_slice(intent.input_asset.as_ref());

    // 4) OutputAsset
    hasher_input.extend_from_slice(intent.output_asset.as_ref());

    // 5) maxFee
    hasher_input.extend_from_slice(&intent.max_fee.to_be_bytes());

    // 6) originDomain
    hasher_input.extend_from_slice(&intent.origin_domain.to_be_bytes());

    // 7) nonce
    hasher_input.extend_from_slice(&intent.nonce.to_be_bytes());

    // 8) timestamp
    hasher_input.extend_from_slice(&intent.timestamp.to_be_bytes());

    // 9) ttl
    hasher_input.extend_from_slice(&intent.ttl.to_be_bytes());

    // 10) normalizedAmount
    hasher_input.extend_from_slice(&intent.normalized_amount.to_be_bytes());

    // 11) destinations (Borsh or plain "Vec<u8>" for them).
    //    If you want raw 4-byte concatenation for each, do it manually:
    //    for d in intent.destinations.iter() { hasher_input.extend_from_slice(&d.to_be_bytes()); }
    //
    //    Or, if your original code used `.try_to_vec()`, replicate that:
    //    let encoded_dest = intent.destinations.try_to_vec().unwrap();
    let encoded_dest = intent.destinations.try_to_vec().unwrap();
    hasher_input.extend_from_slice(&encoded_dest);

    // 12) data
    hasher_input.extend_from_slice(&intent.data);

    // 13) Return keccak256
    keccak_256(&hasher_input)
}

fn _update_gateway(state: &mut SpokeState, new_gateway: Pubkey) -> Result<()> {
    let old = state.gateway;
    state.gateway = new_gateway;
    emit!(GatewayUpdatedEvent { old_gateway: old, new_gateway });
    Ok(())
}

fn _update_lighthouse(state: &mut SpokeState, new_lighthouse: Pubkey) -> Result<()> {
    let old = state.lighthouse;
    state.lighthouse = new_lighthouse;
    emit!(LighthouseUpdatedEvent {
        old_lighthouse: old,
        new_lighthouse,
    });
    Ok(())
}

fn _update_watchtower(state: &mut SpokeState, new_watchtower: Pubkey) -> Result<()> {
    let old = state.watchtower;
    state.watchtower = new_watchtower;
    emit!(WatchtowerUpdatedEvent {
        old_watchtower: old,
        new_watchtower,
    });
    Ok(())
}

fn _update_mailbox(state: &mut SpokeState, new_mailbox: Pubkey) -> Result<()> {
    let old = state.mailbox;
    state.mailbox = new_mailbox;
    emit!(MailboxUpdatedEvent {
        old_mailbox: old,
        new_mailbox,
    });
    Ok(())
}
