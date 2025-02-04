use anchor_lang::prelude::*;
use anchor_lang::solana_program::clock::Clock;
use crate::spoke_storage::{SpokeStorageState, Intent, Fill, Strategy, Module};

// Replace with your actual program id
declare_id!("Ever111111111111111111111111111111111111111");

#[program]
pub mod everclear_spoke {
    use super::*;

    // Initialize the state with initial configuration.
    pub fn initialize(
        ctx: Context<Initialize>,
        domain: u32,
        gateway: Pubkey,
        message_receiver: Pubkey,
        lighthouse: Pubkey,
        watchtower: Pubkey,
        call_executor: Pubkey,
        everclear: u32,
        message_gas_limit: u64,
    ) -> Result<()> {
        let state = &mut ctx.accounts.state;
        state.owner = *ctx.accounts.owner.key;
        state.paused = false;
        state.nonce = 0;
        state.domain = domain;
        state.gateway = gateway;
        state.message_receiver = message_receiver;
        state.lighthouse = lighthouse;
        state.watchtower = watchtower;
        state.call_executor = call_executor;
        state.everclear = everclear;
        state.message_gas_limit = message_gas_limit;
        state.intent_queue = Vec::new();
        state.fill_queue = Vec::new();
        state.strategies = Vec::new();
        state.modules = Vec::new();
        state.balances = Vec::new();
        Ok(())
    }

    // Only the owner may pause the contract.
    pub fn pause(ctx: Context<OnlyOwner>) -> Result<()> {
        let state = &mut ctx.accounts.state;
        state.paused = true;
        Ok(())
    }

    // Only the owner may unpause the contract.
    pub fn unpause(ctx: Context<OnlyOwner>) -> Result<()> {
        let state = &mut ctx.accounts.state;
        state.paused = false;
        Ok(())
    }

    // Owner can set a strategy for an asset.
    pub fn set_strategy_for_asset(ctx: Context<OnlyOwner>, asset: Pubkey, strategy: u8) -> Result<()> {
        let state = &mut ctx.accounts.state;
        // if already existing update; otherwise, add new
        if let Some(entry) = state.strategies.iter_mut().find(|entry| entry.0 == asset) {
            entry.1 = strategy;
        } else {
            state.strategies.push((asset, strategy));
        }
        Ok(())
    }

    // Owner can set a module for a given strategy.
    pub fn set_module_for_strategy(ctx: Context<OnlyOwner>, strategy: u8, module: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.state;
        if let Some(entry) = state.modules.iter_mut().find(|entry| entry.0 == strategy) {
            entry.1 = module;
        } else {
            state.modules.push((strategy, module));
        }
        Ok(())
    }

    // Owner can update the gateway address.
    pub fn update_gateway(ctx: Context<OnlyOwner>, new_gateway: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.state;
        state.gateway = new_gateway;
        Ok(())
    }

    // Owner can update the message receiver.
    pub fn update_message_receiver(ctx: Context<OnlyOwner>, new_receiver: Pubkey) -> Result<()> {
        let state = &mut ctx.accounts.state;
        state.message_receiver = new_receiver;
        Ok(())
    }

    // Owner can update the gas limit used when quoting messages.
    pub fn update_message_gas_limit(ctx: Context<OnlyOwner>, new_gas_limit: u64) -> Result<()> {
        let state = &mut ctx.accounts.state;
        state.message_gas_limit = new_gas_limit;
        Ok(())
    }

    // Deposit instruction: records a deposit into the contract's balance mapping.
    pub fn deposit(ctx: Context<Deposit>, asset: Pubkey, amount: u64) -> Result<()> {
        let state = &mut ctx.accounts.state;
        let depositor = ctx.accounts.depositor.key();
        // In production you would also perform a CPI call to the Token Program for a token transfer.
        if let Some(entry) = state
            .balances
            .iter_mut()
            .find(|entry| entry.0 == asset && entry.1 == depositor)
        {
            entry.2 = entry.2.checked_add(amount).ok_or(ErrorCode::Overflow)?;
        } else {
            state.balances.push((asset, depositor, amount));
        }
        Ok(())
    }

    // Withdraw instruction: subtracts from the balance and (after a proper token CPI) sends tokens to the user.
    pub fn withdraw(ctx: Context<Withdraw>, asset: Pubkey, amount: u64) -> Result<()> {
        let state = &mut ctx.accounts.state;
        let withdrawer = ctx.accounts.withdrawer.key();
        if let Some(entry) = state
            .balances
            .iter_mut()
            .find(|entry| entry.0 == asset && entry.1 == withdrawer)
        {
            if entry.2 < amount {
                return Err(ErrorCode::InsufficientFunds.into());
            }
            entry.2 -= amount;
        } else {
            return Err(ErrorCode::NoBalanceFound.into());
        }
        // A real implementation would now invoke a token transfer CPI.
        Ok(())
    }

    // new_intent creates a new intent. (We ignore the Permit2 variant for simplicity.)
    #[access_control(not_paused(&ctx.accounts.state))]
    pub fn new_intent(
        ctx: Context<NewIntent>,
        destinations: Vec<u32>,
        receiver: Pubkey,
        input_asset: Pubkey,
        output_asset: Option<Pubkey>,
        amount: u64,
        max_fee: u32,
        ttl: u64,
        data: Vec<u8>,
    ) -> Result<()> {
        let state = &mut ctx.accounts.state;

        // Check that the number of destination chains is at most 10
        if destinations.len() > 10 {
            return Err(ErrorCode::InvalidIntent.into());
        }
        // For a single destination (and nonzero ttl) output_asset must be provided.
        if destinations.len() == 1 {
            if ttl != 0 && output_asset.is_none() {
                return Err(ErrorCode::InvalidIntent.into());
            }
        } else {
            // For multiple destinations, ttl must be 0 and output_asset must be None.
            if ttl != 0 || output_asset.is_some() {
                return Err(ErrorCode::InvalidIntent.into());
            }
        }
        // In Solidity the max fee is compared against a denominator (typically 10_000 dbps)
        const DBPS_DENOMINATOR: u32 = 10_000;
        if max_fee > DBPS_DENOMINATOR {
            return Err(ErrorCode::MaxFeeExceeded.into());
        }
        // Enforce a maximum calldata size (for example, 1024 bytes)
        const MAX_CALLDATA_SIZE: usize = 1024;
        if data.len() > MAX_CALLDATA_SIZE {
            return Err(ErrorCode::CalldataExceedsLimit.into());
        }
        if amount == 0 {
            return Err(ErrorCode::ZeroAmount.into());
        }

        // (In a full implementation you might "pull" tokens here via a CPI if no strategy is set.)

        // Increase the nonce and create the intent.
        state.nonce = state.nonce.checked_add(1).ok_or(ErrorCode::Overflow)?;
        let clock = Clock::get()?;
        let intent = Intent {
            initiator: ctx.accounts.initiator.key(),
            receiver,
            input_asset,
            output_asset,
            max_fee,
            origin: state.domain,
            nonce: state.nonce,
            timestamp: clock.unix_timestamp,
            ttl,
            amount,
            destinations: destinations.clone(),
            data: data.clone(),
        };

        // Compute an intent identifier (here we use a simple SHA256 hash of the fields)
        let intent_id = hash_intent(&intent);
        state.intent_queue.push(intent_id);

        msg!("Intent Added: {:?}", intent_id);
        Ok(())
    }

    // fill_intent "fills" an intent – checking that it has not expired, that fees are acceptable,
    // subtracting the solver's balance and (if applicable) executing external calldata.
    #[access_control(not_paused(&ctx.accounts.state))]
    pub fn fill_intent(ctx: Context<FillIntent>, intent: Intent, fee: u32) -> Result<()> {
        let state = &mut ctx.accounts.state;
        let solver = ctx.accounts.solver.key();

        let clock = Clock::get()?;
        if clock.unix_timestamp >= (intent.timestamp + intent.ttl as i64) {
            return Err(ErrorCode::IntentExpired.into());
        }
        if fee > intent.max_fee {
            return Err(ErrorCode::MaxFeeExceeded.into());
        }

        // In a real implementation you would normalize decimals; here we use the amount directly.
        let fee_deduction = intent
            .amount
            .checked_mul(fee as u64)
            .ok_or(ErrorCode::Overflow)?
            .checked_div(10_000)
            .ok_or(ErrorCode::Overflow)?;
        let final_amount = intent.amount.checked_sub(fee_deduction).ok_or(ErrorCode::Overflow)?;

        // If this intent involves an output asset, deduct the amount from the solver's balance.
        if let Some(asset) = intent.output_asset {
            if let Some(entry) = state
                .balances
                .iter_mut()
                .find(|entry| entry.0 == asset && entry.1 == solver)
            {
                if entry.2 < final_amount {
                    return Err(ErrorCode::InsufficientFunds.into());
                }
                entry.2 -= final_amount;
            } else {
                return Err(ErrorCode::InsufficientFunds.into());
            }
        }

        // If any "call data" is provided, we would execute it using our call_executor (stubbed here)
        if !intent.data.is_empty() {
            msg!("Executing external calldata for intent...");
            // A real implementation would perform a CPI to the call executor program here.
        }

        // Create a fill message and enqueue it.
        let fill = Fill {
            intent_id: hash_intent(&intent),
            initiator: intent.initiator,
            solver,
            execution_timestamp: clock.unix_timestamp,
            fee,
        };
        state.fill_queue.push(fill);
        Ok(())
    }

    // process_intent_queue takes a batch of intents (passed in by the caller)
    // and verifies/dequeues them from our stored queue.
    #[access_control(not_paused(&ctx.accounts.state))]
    pub fn process_intent_queue(ctx: Context<ProcessQueue>, intents: Vec<Intent>) -> Result<()> {
        let state = &mut ctx.accounts.state;
        // Here we simply check that each intent's computed hash matches the next one in the queue.
        for intent in intents.iter() {
            if state.intent_queue.is_empty() {
                return Err(ErrorCode::IntentQueueMismatch.into());
            }
            let expected_id = state.intent_queue.remove(0); // dequeue
            let hash_val = hash_intent(intent);
            if expected_id != hash_val {
                return Err(ErrorCode::IntentQueueMismatch.into());
            }
        }
        msg!("Processed a batch of {} intents.", intents.len());
        Ok(())
    }

    // process_fill_queue processes (dequeues) a given number of fill messages.
    #[access_control(not_paused(&ctx.accounts.state))]
    pub fn process_fill_queue(ctx: Context<ProcessQueue>, amount: u32) -> Result<()> {
        let state = &mut ctx.accounts.state;
        let mut batch: Vec<FillMessage> = Vec::new();
        for _ in 0..amount {
            if state.fill_queue.is_empty() {
                break;
            }
            batch.push(state.fill_queue.remove(0));
        }
        msg!("Processed {} fill messages from the fill queue.", batch.len());
        Ok(())
    }

    /// Creates a new intent
    pub fn create_intent(
        ctx: Context<CreateIntent>,
        strategy_id: u32,
        calldata: Vec<u8>,
    ) -> Result<()> {
        let state = &mut ctx.accounts.state;
        require!(!state.paused, CustomError::ContractPaused);
        require!(!calldata.is_empty(), CustomError::EmptyCalldata);
        require!(calldata.len() <= 10240, CustomError::CalldataTooLarge); // 10KB max
        
        // Validate strategy
        let strategy = state.strategies
            .iter()
            .find(|s| s.id == strategy_id && s.enabled)
            .ok_or(CustomError::InvalidStrategy)?;
            
        // Create intent
        let intent = Intent {
            owner: ctx.accounts.owner.key(),
            nonce: state.nonce,
            strategy_id,
            calldata,
            timestamp: Clock::get()?.unix_timestamp,
        };
        
        // Add to queue
        require!(
            state.intent_queue.len() < 1000,
            CustomError::IntentQueueFull
        );
        state.intent_queue.push_back(intent);
        state.nonce += 1;
        
        msg!("Created intent with nonce {}", state.nonce - 1);
        Ok(())
    }

    /// Fills an intent
    pub fn fill_intent(
        ctx: Context<FillIntent>,
        intent_index: u32,
        calldata: Vec<u8>,
    ) -> Result<()> {
        let state = &mut ctx.accounts.state;
        require!(!state.paused, CustomError::ContractPaused);
        require!(!calldata.is_empty(), CustomError::EmptyCalldata);
        require!(calldata.len() <= 10240, CustomError::CalldataTooLarge);
        
        // Get intent
        let intent = state.intent_queue
            .get(intent_index as usize)
            .ok_or(CustomError::InvalidIntentIndex)?
            .clone();
            
        // Create fill
        let fill = Fill {
            intent,
            filler: ctx.accounts.filler.key(),
            calldata,
            timestamp: Clock::get()?.unix_timestamp,
        };
        
        // Add to queue
        require!(
            state.fill_queue.len() < 1000,
            CustomError::FillQueueFull
        );
        state.fill_queue.push_back(fill);
        
        // Remove intent from queue
        state.intent_queue.remove(intent_index as usize);
        
        msg!("Filled intent at index {}", intent_index);
        Ok(())
    }

    /// Adds a new strategy
    pub fn add_strategy(
        ctx: Context<AdminAction>,
        id: u32,
        module: Pubkey,
        config: Vec<u8>,
    ) -> Result<()> {
        let state = &mut ctx.accounts.state;
        require!(!state.paused, CustomError::ContractPaused);
        
        // Validate module
        let module_exists = state.modules
            .iter()
            .any(|m| m.address == module && m.enabled);
        require!(module_exists, CustomError::InvalidModule);
        
        // Check strategy doesn't exist
        require!(
            !state.strategies.iter().any(|s| s.id == id),
            CustomError::StrategyExists
        );
        
        // Add strategy
        let strategy = Strategy {
            id,
            enabled: true,
            module,
            config,
        };
        state.strategies.push(strategy);
        
        msg!("Added strategy {}", id);
        Ok(())
    }

    /// Adds a new module
    pub fn add_module(
        ctx: Context<AdminAction>,
        module: Pubkey,
        strategies: Vec<u32>,
    ) -> Result<()> {
        let state = &mut ctx.accounts.state;
        require!(!state.paused, CustomError::ContractPaused);
        require!(module != Pubkey::default(), CustomError::InvalidModuleAddress);
        
        // Check module doesn't exist
        require!(
            !state.modules.iter().any(|m| m.address == module),
            CustomError::ModuleExists
        );
        
        // Add module
        let module_entry = Module {
            address: module,
            enabled: true,
            strategies,
        };
        state.modules.push(module_entry);
        
        msg!("Added module {}", module);
        Ok(())
    }
}

// Helper function to compute a SHA256 hash of an Intent (similar to Solidity's keccak256 over ABI-encoded intent)
pub fn hash_intent(intent: &Intent) -> [u8; 32] {
    let mut hasher = anchor_lang::solana_program::hash::Hasher::default();
    hasher.hash(&intent.initiator.to_bytes());
    hasher.hash(&intent.receiver.to_bytes());
    hasher.hash(&intent.input_asset.to_bytes());
    if let Some(asset) = intent.output_asset {
        hasher.hash(&asset.to_bytes());
    }
    hasher.hash(&intent.max_fee.to_le_bytes());
    hasher.hash(&intent.origin.to_le_bytes());
    hasher.hash(&intent.nonce.to_le_bytes());
    hasher.hash(&intent.timestamp.to_le_bytes());
    hasher.hash(&intent.ttl.to_le_bytes());
    hasher.hash(&intent.amount.to_le_bytes());
    for d in &intent.destinations {
        hasher.hash(&d.to_le_bytes());
    }
    hasher.hash(&intent.data);
    hasher.result().to_bytes()
}

// Contexts for instructions

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = owner, space = 8 + EverclearSpokeState::MAX_SIZE)]
    pub state: Account<'info, EverclearSpokeState>,
    #[account(mut)]
    pub owner: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct OnlyOwner<'info> {
    #[account(mut, has_one = owner)]
    pub state: Account<'info, EverclearSpokeState>,
    pub owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(mut)]
    pub state: Account<'info, EverclearSpokeState>,
    pub depositor: Signer<'info>,
    // In a complete implementation, additional token accounts and the Token Program would be required.
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub state: Account<'info, EverclearSpokeState>,
    pub withdrawer: Signer<'info>,
    // In a full implementation, token transfer accounts and the Token Program would be included.
}

#[derive(Accounts)]
pub struct NewIntent<'info> {
    #[account(mut)]
    pub state: Account<'info, EverclearSpokeState>,
    pub initiator: Signer<'info>,
}

#[derive(Accounts)]
pub struct FillIntent<'info> {
    #[account(mut)]
    pub state: Account<'info, EverclearSpokeState>,
    pub solver: Signer<'info>,
}

#[derive(Accounts)]
pub struct ProcessQueue<'info> {
    #[account(mut)]
    pub state: Account<'info, EverclearSpokeState>,
}

#[derive(Accounts)]
pub struct CreateIntent<'info> {
    /// The state account
    #[account(mut)]
    pub state: Account<'info, SpokeStorageState>,
    
    /// The intent owner
    pub owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct AdminAction<'info> {
    /// The state account
    #[account(mut, has_one = owner @ CustomError::Unauthorized)]
    pub state: Account<'info, SpokeStorageState>,
    
    /// The owner account
    pub owner: Signer<'info>,
}

// Global state account storing configuration, queues, mappings, and balances.
#[account]
pub struct EverclearSpokeState {
    pub owner: Pubkey,
    pub paused: bool,
    pub nonce: u64,
    pub domain: u32,
    pub message_gas_limit: u64,
    pub gateway: Pubkey,
    pub message_receiver: Pubkey,
    pub lighthouse: Pubkey,
    pub watchtower: Pubkey,
    pub call_executor: Pubkey,
    pub everclear: u32,
    // Vector of 32-byte intent identifiers.
    pub intent_queue: Vec<[u8; 32]>,
    // Vector of fill messages.
    pub fill_queue: Vec<FillMessage>,
    // Mapping of asset to strategy type.
    pub strategies: Vec<(Pubkey, u8)>,
    // Mapping of strategy type to module address.
    pub modules: Vec<(u8, Pubkey)>,
    // Mapping of (asset, user) balances.
    pub balances: Vec<(Pubkey, Pubkey, u64)>,
}

impl EverclearSpokeState {
    // For demonstration purposes the MAX_SIZE is arbitrarily chosen. In production, you must carefully calculate required space.
    pub const MAX_SIZE: usize = 10240;
}

// The Intent structure mirroring the Solidity struct.
#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct Intent {
    pub initiator: Pubkey,
    pub receiver: Pubkey,
    pub input_asset: Pubkey,
    pub output_asset: Option<Pubkey>,
    pub max_fee: u32,
    pub origin: u32,
    pub nonce: u64,
    pub timestamp: i64,
    pub ttl: u64,
    pub amount: u64,
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
}

// The FillMessage structure.
#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct FillMessage {
    pub intent_id: [u8; 32],
    pub initiator: Pubkey,
    pub solver: Pubkey,
    pub execution_timestamp: i64,
    pub fee: u32,
}

// Modifier to ensure functions run only when not paused.
pub fn not_paused(state: &EverclearSpokeState) -> Result<()> {
    if state.paused {
        return Err(ErrorCode::Paused.into());
    }
    Ok(())
}

// Error definitions.
#[error_code]
pub enum ErrorCode {
    #[msg("The contract is paused.")]
    Paused,
    #[msg("Invalid intent configuration.")]
    InvalidIntent,
    #[msg("Max fee exceeded.")]
    MaxFeeExceeded,
    #[msg("Calldata exceeds limit.")]
    CalldataExceedsLimit,
    #[msg("Zero amount not allowed.")]
    ZeroAmount,
    #[msg("Overflow occurred.")]
    Overflow,
    #[msg("Insufficient funds.")]
    InsufficientFunds,
    #[msg("No balance found for asset.")]
    NoBalanceFound,
    #[msg("Intent expired.")]
    IntentExpired,
    #[msg("Intent queue does not match the provided intents.")]
    IntentQueueMismatch,
}

#[error_code]
pub enum CustomError {
    #[msg("Contract is paused")]
    ContractPaused,
    #[msg("Contract is already paused")]
    AlreadyPaused,
    #[msg("Contract is not paused")]
    NotPaused,
    #[msg("Unauthorized")]
    Unauthorized,
    #[msg("Empty calldata")]
    EmptyCalldata,
    #[msg("Calldata too large")]
    CalldataTooLarge,
    #[msg("Invalid strategy")]
    InvalidStrategy,
    #[msg("Invalid intent index")]
    InvalidIntentIndex,
    #[msg("Intent queue is full")]
    IntentQueueFull,
    #[msg("Fill queue is full")]
    FillQueueFull,
    #[msg("Invalid module")]
    InvalidModule,
    #[msg("Invalid module address")]
    InvalidModuleAddress,
    #[msg("Strategy already exists")]
    StrategyExists,
    #[msg("Module already exists")]
    ModuleExists,
} 
