use anchor_lang::prelude::*;
use anchor_lang::solana_program::clock::Clock;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer, TransferChecked, MintTo, Burn};
use std::collections::{VecDeque, HashMap};

// Constants
pub const HYPERLANE_MAILBOX_PROGRAM_ID: Pubkey = Pubkey::new_from_array([0; 32]);
pub const THIS_DOMAIN: u32 = 1234;       // This spoke's domain ID
pub const EVERCLEAR_DOMAIN: u32 = 9999;  // Hub's domain ID
pub const MAX_INTENT_QUEUE_SIZE: usize = 1000;
pub const MAX_FILL_QUEUE_SIZE: usize = 1000;
pub const MAX_STRATEGIES: usize = 100;
pub const MAX_MODULES: usize = 50;
pub const MAX_CALLDATA_SIZE: usize = 10240; // 10KB
pub const DBPS_DENOMINATOR: u32 = 10_000;

pub const FILL_INTENT_FOR_SOLVER_TYPEHASH: [u8; 32] = [0xAA; 32]; // placeholder
pub const PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH: [u8; 32] = [0xBB; 32];
pub const PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH: [u8; 32] = [0xCC; 32];

// Dummy Permit2 address
pub const PERMIT2: Pubkey = Pubkey::new_from_array([0u8; 32]);

declare_id!("FH6w3aVDLKtZn3AmK3bxM9RBvJ6WBKEhp6VFZb5Axcoy");

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
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct Permit2Data {
    pub token: Pubkey,
    pub amount: u64,
    pub expiration: u64,
    pub nonce: u64,
    pub signature: [u8; 64],
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct RelayerSignature {
    pub signer: Pubkey,
    pub signature: [u8; 64],
    pub deadline: u64,
}

impl RelayerSignature {
    pub fn verify(&self, typehash: [u8; 32], msg_hash: [u8; 32]) -> Result<()> {
        let clock = Clock::get()?;
        require!(clock.unix_timestamp as u64 <= self.deadline, SpokeError::SignatureExpired);
        
        // Construct the message to verify
        let mut hasher = tiny_keccak::Keccak::v256();
        hasher.update(&typehash);
        hasher.update(&msg_hash);
        hasher.update(&self.deadline.to_le_bytes());
        let mut hash = [0u8; 32];
        hasher.finalize(&mut hash);
        
        // Verify signature (placeholder - implement actual ed25519 verification)
        require!(verify_ed25519_signature(&self.signer, &hash, &self.signature), SpokeError::InvalidSignature);
        Ok(())
    }
}

// Helper function to verify ed25519 signatures
fn verify_ed25519_signature(signer: &Pubkey, message: &[u8], signature: &[u8; 64]) -> bool {
    // TODO: Implement actual ed25519 verification
    // This is a placeholder that always returns true
    true
}

#[program]
pub mod everclear_spoke {
    use super::*;

    /// Initialize the global state.
    /// This function creates the SpokeState (global config) PDA.
    pub fn initialize(
        ctx: Context<Initialize>,
        init: SpokeInitializationParams,
    ) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        state.paused = false;
        state.domain = init.domain;
        state.everclear = init.hub_domain;
        state.lighthouse = init.lighthouse;
        state.watchtower = init.watchtower;
        state.call_executor = init.call_executor;
        state.message_receiver = init.message_receiver;
        state.gateway = init.gateway;
        state.message_gas_limit = init.message_gas_limit;
        state.nonce = 0;
        
        // Initialize our mappings and queues
        state.intent_queue = QueueState::new();
        state.fill_queue = QueueState::new();
        state.balances = HashMap::new();
        state.status = HashMap::new();
        state.strategy_by_asset = HashMap::new();
        state.module_by_strategy = HashMap::new();
        
        // Set owner to the payer (deployer)
        state.owner = ctx.accounts.payer.key();
        state.bump = *ctx.bumps.get("spoke_state").unwrap();
        
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

    /// Deposit SPL tokens into the program.
    /// The user's tokens are transferred to a program-controlled vault.
    pub fn deposit(
        ctx: Context<Deposit>,
        amount: u64,
    ) -> Result<()> {
        let state = &ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        require!(amount > 0, SpokeError::InvalidAmount);

        // Transfer tokens from user to program vault.
        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.from_token_account.to_account_info(),
                to: ctx.accounts.to_token_account.to_account_info(),
                authority: ctx.accounts.user_authority.to_account_info(),
            },
        );
        token::transfer(cpi_ctx, amount)?;

        // Update user balance (stored on-chain in the global state's dynamic vector).
        increase_balance(&mut ctx.accounts.spoke_state.balances, ctx.accounts.mint.key(), ctx.accounts.user_authority.key(), amount);

        emit!(DepositedEvent {
            user: ctx.accounts.user_authority.key(),
            asset: ctx.accounts.mint.key(),
            amount,
        });
        Ok(())
    }

    /// Withdraw SPL tokens from the program's vault.
    /// This reduces the user's on‑chain balance and transfers tokens out.
    pub fn withdraw(
        ctx: Context<Withdraw>,
        amount: u64,
    ) -> Result<()> {
        let state = &ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        require!(amount > 0, SpokeError::InvalidAmount);

        // Check the user has sufficient balance.
        reduce_balance(&mut ctx.accounts.spoke_state.balances, ctx.accounts.mint.key(), ctx.accounts.user_authority.key(), amount)?;
        // Transfer tokens from the vault to the user's token account.
        // The vault is owned by a PDA (program_vault_authority).
        let vault_authority_seeds = &[
            b"vault",
            ctx.accounts.mint.key().as_ref(),
            &[ctx.accounts.vault_authority_bump],
        ];
        let signer = &[&vault_authority_seeds[..]];
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
        ctx: Context<AuthState>,
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
        // If a single destination and ttl != 0, require output_asset is non-zero.
        if destinations.len() == 1 {
            require!(output_asset != Pubkey::default(), SpokeError::InvalidIntent);
        } else {
            // For multi-destination, ttl must be 0 and output_asset must be default.
            require!(ttl == 0 && output_asset == Pubkey::default(), SpokeError::InvalidIntent);
        }
        // Check max_fee is within allowed range (for example, <= 10_000 for basis points)
        require!(max_fee <= 10_000, SpokeError::MaxFeeExceeded);

        // Update global nonce.
        state.nonce = state.nonce.checked_add(1).ok_or(SpokeError::InvalidOperation)?;
        // Create a simple intent_id as the SHA256 hash of (initiator, nonce, amount, current time).
        let clock = Clock::get()?;
        let mut hasher_input = Vec::new();
        hasher_input.extend_from_slice(ctx.accounts.authority.key.as_ref());
        hasher_input.extend_from_slice(&state.nonce.to_le_bytes());
        hasher_input.extend_from_slice(&amount.to_le_bytes());
        hasher_input.extend_from_slice(&clock.unix_timestamp.to_le_bytes());
        let intent_id = keccak_256(&hasher_input);

        // Optionally, reduce the user's deposit balance by the amount.
        reduce_balance(&mut state.balances, input_asset, ctx.accounts.authority.key(), amount)?;

        // Append the intent_id to the intent_queue.
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
            amount,
            max_fee,
            origin_domain: state.domain,
            ttl,
            timestamp: clock.unix_timestamp as u64,
            destinations,
            data,
        });
        Ok(())
    }

    /// Fill an intent.
    /// Called by a solver to fulfill an intent; transfers tokens or mints xAssets accordingly.
    pub fn fill_intent(
        ctx: Context<AuthState>,
        intent_id: [u8; 32],
        fee: u32,
    ) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        // Find the intent in our status mapping.
        let current_status = state.status.get(&intent_id).cloned().unwrap_or(IntentStatus::None);
        // Only allow fill if intent is in Added state.
        require!(current_status == IntentStatus::Added, SpokeError::InvalidIntentStatus);

        // Check TTL: if current time exceeds (intent.timestamp + ttl), then intent is expired.
        // (For demonstration, assume TTL is stored as part of the event; in production, you'd store it on‑chain.)
        let clock = Clock::get()?;
        // For this demo, we do not have the original timestamp/ttl on-chain; assume valid.
        // In production, you'd store them in an Intent account.
        
        // For demonstration, simulate token transfer (or mint if XERC20 strategy applies)
        // Here we assume that if output_asset is non-zero, then funds exist in the program's vault.
        // Otherwise, if output_asset is default, we assume XERC20 minting is required.
        if ctx.accounts.intent_output_asset.key() != Pubkey::default() {
            // Standard asset: Transfer tokens from solver's vault (or program's custody) to the intended receiver.
            // For demonstration, we assume the solver has already deposited the output asset in the program's vault.
            // So we perform a token transfer from the program's vault (owned by a PDA) to the receiver's account.
            let vault_authority_seeds = &[
                b"vault",
                ctx.accounts.intent_output_asset.key().as_ref(),
                &[ctx.accounts.vault_authority_bump],
            ];
            let signer = &[&vault_authority_seeds[..]];
            let cpi_accounts = Transfer {
                from: ctx.accounts.intent_from_token_account.to_account_info(),
                to: ctx.accounts.intent_to_token_account.to_account_info(),
                authority: ctx.accounts.vault_authority.to_account_info(),
            };
            let cpi_ctx = CpiContext::new_with_signer(ctx.accounts.token_program.to_account_info(), cpi_accounts, signer);
            token::transfer(cpi_ctx, ctx.accounts.intent_amount)?;
        } else {
            // XERC20 strategy: Mint the output asset (xAsset) to the receiver.
            let cpi_accounts = MintTo {
                mint: ctx.accounts.xasset_mint.to_account_info(),
                to: ctx.accounts.intent_to_token_account.to_account_info(),
                authority: ctx.accounts.mint_authority.to_account_info(),
            };
            // The mint_authority is a PDA.
            let mint_authority_seeds = &[
                b"xasset_mint_authority",
                ctx.accounts.xasset_mint.key().as_ref(),
                &[ctx.accounts.mint_authority_bump],
            ];
            let signer = &[&mint_authority_seeds[..]];
            let cpi_ctx = CpiContext::new_with_signer(ctx.accounts.token_program.to_account_info(), cpi_accounts, signer);
            token::mint_to(cpi_ctx, ctx.accounts.intent_amount)?;
        }
        // Mark the intent as filled.
        state.status.insert(intent_id, IntentStatus::Filled);

        // Record a fill message in the fill_queue.
        let fill_msg = FillMessage {
            intent_id,
            solver: ctx.accounts.authority.key(),
            execution_timestamp: clock.unix_timestamp as u64,
            fee,
        };
        state.fill_queue.push_back(fill_msg);

        emit!(IntentFilledEvent {
            intent_id,
            solver: ctx.accounts.authority.key(),
            fee,
        });
        Ok(())
    }

    /// Process a batch of intents in the queue and dispatch a cross-chain message via Hyperlane.
    pub fn process_intent_queue(ctx: Context<AuthState>, count: u32) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        require!(count > 0, SpokeError::InvalidAmount);
        require!(count as usize <= state.intent_queue.len(), SpokeError::InvalidQueueOperation);

        // Collect the first 'count' intent IDs.
        let intents: Vec<[u8;32]> = state.intent_queue.drain(0..(count as usize)).collect();
        // (In production, you would also include full intent data or verify with an off‑chain aggregator.)

        // Build a batch message (here we simply serialize the vector).
        let batch_message = intents.try_to_vec()?;

        // Call Hyperlane Mailbox via CPI.
        // For demonstration, we construct a dummy instruction.
        let ix_data = {
            let mut data = Vec::new();
            data.extend_from_slice(&EVERCLEAR_DOMAIN.to_le_bytes()); // destination domain
            data.extend_from_slice(&state.gateway.to_bytes());       // recipient (hub gateway)
            data.extend_from_slice(&(batch_message.len() as u64).to_le_bytes());
            data.extend_from_slice(&batch_message);
            data
        };
        let ix = anchor_lang::solana_program::instruction::Instruction {
            program_id: ctx.accounts.hyperlane_mailbox.key(),
            accounts: vec![],
            data: ix_data,
        };
        anchor_lang::solana_program::program::invoke(
            &ix,
            &[ctx.accounts.hyperlane_mailbox.to_account_info()],
        )?;
        emit!(IntentQueueProcessedEvent {
            message_id: keccak_256(&batch_message),
            first_index: 0, // for demonstration
            last_index: count as u64,
            fee_spent: 0, // placeholder
        });
        Ok(())
    }

    /// Process a batch of fill messages and dispatch a cross-chain message via Hyperlane.
    pub fn process_fill_queue(ctx: Context<AuthState>, count: u32) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        require!(count > 0, SpokeError::InvalidAmount);
        require!(count as usize <= state.fill_queue.len(), SpokeError::InvalidQueueOperation);

        // Collect the first 'count' fill messages.
        let fills: Vec<FillMessage> = state.fill_queue.drain(0..(count as usize)).collect();
        let batch_message = fills.try_to_vec()?;

        // Dispatch via Hyperlane Mailbox.
        let ix_data = {
            let mut data = Vec::new();
            data.extend_from_slice(&EVERCLEAR_DOMAIN.to_le_bytes());
            data.extend_from_slice(&state.gateway.to_bytes());
            data.extend_from_slice(&(batch_message.len() as u64).to_le_bytes());
            data.extend_from_slice(&batch_message);
            data
        };
        let ix = anchor_lang::solana_program::instruction::Instruction {
            program_id: ctx.accounts.hyperlane_mailbox.key(),
            accounts: vec![],
            data: ix_data,
        };
        anchor_lang::solana_program::program::invoke(
            &ix,
            &[ctx.accounts.hyperlane_mailbox.to_account_info()],
        )?;
        emit!(FillQueueProcessedEvent {
            message_id: keccak_256(&batch_message),
            first_index: 0,
            last_index: count as u64,
            fee_spent: 0,
        });
        Ok(())
    }

    /// Receive a cross‑chain message via Hyperlane.
    /// In production, this would be invoked via CPI from Hyperlane's Mailbox.
    pub fn receive_message(
        ctx: Context<AuthState>,
        origin: u32,
        sender: Pubkey,
        payload: Vec<u8>,
    ) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        // Verify the origin is from Everclear.
        require!(origin == EVERCLEAR_DOMAIN, SpokeError::InvalidOrigin);
        // Verify sender matches the stored message_receiver.
        require!(sender == state.message_receiver, SpokeError::InvalidSender);

        // For demonstration, assume payload's first byte indicates message type.
        // 1 = Settlement Batch, 2 = Variable Update, etc.
        require!(!payload.is_empty(), SpokeError::InvalidMessage);
        let msg_type = payload[0];
        match msg_type {
            1 => {
                // Settlement batch message: process each settlement.
                // For demonstration, assume payload contains a vector of (intent_id, asset, recipient, amount).
                // In production, you'd decode using a proper schema.
                msg!("Processing settlement batch message");
                // (Here you would iterate over each settlement record and perform token transfers/mint/burn.)
            },
            2 => {
                // Variable update: update gateway, watchtower, etc.
                msg!("Processing variable update message");
                // (Decode variable identifier and new value, then update state.)
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
        require!(state.owner == ctx.accounts.authority.key(), SpokeError::OnlyOwner);
        let old = state.gateway;
        state.gateway = new_gateway;
        emit!(GatewayUpdatedEvent { old_gateway: old, new_gateway });
        Ok(())
    }

    /// Set strategy for an asset (admin only).
    /// For example, 0 = standard, 1 = XERC20 mint/burn.
    pub fn set_strategy_for_asset(ctx: Context<AuthState>, asset: Pubkey, strategy: u8) -> Result<()> {
        let state = &mut ctx.accounts.spoke_state;
        require!(state.owner == ctx.accounts.authority.key(), SpokeError::OnlyOwner);
        update_strategy(&mut state.strategy_by_asset, asset, strategy)?;
        emit!(StrategySetEvent { asset, strategy });
        Ok(())
    }

    /// Execute an arbitrary external call (like CallExecutor in Solidity).
    /// Only callable by owner or call_executor.
    pub fn execute_call(
        ctx: Context<ExecuteCall>,
        target_program_id: Pubkey,
        ix_data: Vec<u8>,
    ) -> Result<()> {
        let state = &ctx.accounts.spoke_state;
        require!(!state.paused, SpokeError::ContractPaused);
        require!(
            ctx.accounts.authority.key() == state.owner || ctx.accounts.authority.key() == state.call_executor,
            SpokeError::Unauthorized
        );
        // Prevent calling our own program.
        require!(target_program_id != crate::id(), SpokeError::InvalidOperation);

        let accounts: Vec<AccountMeta> = ctx.remaining_accounts.iter().map(|acc| {
            AccountMeta {
                pubkey: acc.key(),
                is_signer: acc.is_signer,
                is_writable: acc.is_writable,
            }
        }).collect();

        let ix = anchor_lang::solana_program::instruction::Instruction {
            program_id: target_program_id,
            accounts,
            data: ix_data,
        };
        anchor_lang::solana_program::program::invoke(&ix, ctx.remaining_accounts)?;
        emit!(ExternalCallExecutedEvent { target_program_id });
        Ok(())
    }

    /// XERC20 module: Mint debt for an asset.
    /// Deducts debt from a stored "mintable" balance and mints tokens to the recipient.
    pub fn xerc20_mint_debt(
        ctx: Context<Xerc20MintDebt>,
        amount: u64,
    ) -> Result<()> {
        // Check minting limit; for demonstration, we assume sufficient limit.
        let cpi_accounts = MintTo {
            mint: ctx.accounts.asset_mint.to_account_info(),
            to: ctx.accounts.recipient_token_account.to_account_info(),
            authority: ctx.accounts.mint_authority.to_account_info(),
        };
        let seeds = &[
            b"xerc20_mint_authority",
            ctx.accounts.asset_mint.key().as_ref(),
            &[ctx.accounts.mint_authority_bump],
        ];
        let signer = &[&seeds[..]];
        let cpi_ctx = CpiContext::new_with_signer(ctx.accounts.token_program.to_account_info(), cpi_accounts, signer);
        token::mint_to(cpi_ctx, amount)?;
        emit!(DebtMintedEvent {
            asset: ctx.accounts.asset_mint.key(),
            recipient: ctx.accounts.recipient.key(),
            amount,
        });
        Ok(())
    }

    /// XERC20 module: Handle burn strategy.
    /// Burns tokens from the user's token account.
    pub fn xerc20_burn_strategy(
        ctx: Context<Xerc20BurnStrategy>,
        amount: u64,
    ) -> Result<()> {
        // Check burning limit; for demonstration, we assume sufficient limit.
        let cpi_accounts = Burn {
            mint: ctx.accounts.asset_mint.to_account_info(),
            to: ctx.accounts.user_token_account.to_account_info(),
            authority: ctx.accounts.user_authority.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
        token::burn(cpi_ctx, amount)?;
        emit!(BurnedEvent {
            asset: ctx.accounts.asset_mint.key(),
            user: ctx.accounts.user_authority.key(),
            amount,
        });
        Ok(())
    }

    /// Create a new intent with Permit2 validation
    pub fn new_intent_with_permit2(
        ctx: Context<AuthState>,
        receiver: Pubkey,
        input_asset: Pubkey,
        output_asset: Pubkey,
        amount: u64,
        max_fee: u32,
        ttl: u64,
        destinations: Vec<u32>,
        data: Vec<u8>,
        permit: Permit2Data,
    ) -> Result<()> {
        // Verify Permit2 data
        let clock = Clock::get()?;
        require!(clock.unix_timestamp as u64 <= permit.expiration, SpokeError::InvalidPermit2Data);
        require!(permit.token == input_asset && permit.amount >= amount, SpokeError::InvalidPermit2Data);
        
        // TODO: Verify Permit2 signature via CPI to Permit2 program
        
        // Create the intent
        new_intent(ctx, receiver, input_asset, output_asset, amount, max_fee, ttl, destinations, data)
    }

    /// Process intent queue via a relayer
    pub fn process_intent_queue_via_relayer(
        ctx: Context<AuthState>,
        count: u32,
        relayer_sig: RelayerSignature,
    ) -> Result<()> {
        // Verify relayer signature
        let msg_hash = keccak_256(&count.to_le_bytes());
        relayer_sig.verify(PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH, msg_hash)?;
        
        // Process the queue
        process_intent_queue(ctx, count)
    }

    /// Process fill queue via a relayer
    pub fn process_fill_queue_via_relayer(
        ctx: Context<AuthState>,
        count: u32,
        relayer_sig: RelayerSignature,
    ) -> Result<()> {
        // Verify relayer signature
        let msg_hash = keccak_256(&count.to_le_bytes());
        relayer_sig.verify(PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH, msg_hash)?;
        
        // Process the queue
        process_fill_queue(ctx, count)
    }

    /// Fill intent with solver signature verification
    pub fn fill_intent_for_solver(
        ctx: Context<AuthState>,
        intent_id: [u8; 32],
        fee: u32,
        solver_sig: RelayerSignature,
    ) -> Result<()> {
        // Verify solver signature
        let mut msg_data = Vec::new();
        msg_data.extend_from_slice(&intent_id);
        msg_data.extend_from_slice(&fee.to_le_bytes());
        let msg_hash = keccak_256(&msg_data);
        solver_sig.verify(FILL_INTENT_FOR_SOLVER_TYPEHASH, msg_hash)?;
        
        // Fill the intent
        fill_intent(ctx, intent_id, fee)
    }
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

#[derive(Accounts)]
pub struct AuthState<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    pub authority: Signer<'info>,
}

// Deposit: Transfer tokens from user to program vault.
#[derive(Accounts)]
pub struct Deposit<'info> {
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
    /// CHECK: This is a PDA that signs for the vault.
    pub vault_authority: UncheckedAccount<'info>,
    pub vault_authority_bump: u8,
    pub token_program: Program<'info, Token>,
}

/// Context for execute_call – arbitrary CPI.
#[derive(Accounts)]
pub struct ExecuteCall<'info> {
    #[account(
        mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    pub authority: Signer<'info>,
    // Remaining accounts to be passed along to the CPI.
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

/// Context for XERC20 mint debt.
#[derive(Accounts)]
pub struct Xerc20MintDebt<'info> {
    #[account(mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    pub recipient: Signer<'info>,
    pub asset_mint: Account<'info, Mint>,
    #[account(mut)]
    pub recipient_token_account: Account<'info, TokenAccount>,
    /// CHECK: PDA that is the mint authority for the xAsset.
    pub mint_authority: UncheckedAccount<'info>,
    pub mint_authority_bump: u8,
    pub token_program: Program<'info, Token>,
}

/// Context for XERC20 burn strategy.
#[derive(Accounts)]
pub struct Xerc20BurnStrategy<'info> {
    #[account(mut,
        seeds = [b"spoke-state"],
        bump = spoke_state.bump
    )]
    pub spoke_state: Account<'info, SpokeState>,
    #[account(mut)]
    pub user_authority: Signer<'info>,
    pub asset_mint: Account<'info, Mint>,
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

/// Queue state with first/last indices for efficient management
#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct QueueState<T> {
    pub items: VecDeque<T>,
    pub first_index: u64,
    pub last_index: u64,
}

impl<T> QueueState<T> {
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
    pub fill_queue: QueueState<FillMessage>,
    pub strategy_by_asset: HashMap<Pubkey, u8>,
    pub module_by_strategy: HashMap<u8, Pubkey>,
    // Bump for PDA.
    pub bump: u8,
}

impl SpokeState {
    pub const SIZE: usize = 1    // paused: bool
        + 4                      // domain: u32
        + 4                      // everclear: u32
        + 32 * 5                 // 5 Pubkeys
        + 8                      // message_gas_limit: u64
        + 8                      // nonce: u64
        + 32                     // owner: Pubkey
        + 4 + (MAX_STRATEGIES * (32 + 8))  // balances HashMap
        + 4 + (MAX_INTENT_QUEUE_SIZE * (32 + 1))  // status HashMap
        + QueueState::<[u8;32]>::SIZE      // intent_queue
        + QueueState::<FillMessage>::SIZE  // fill_queue
        + 4 + (MAX_STRATEGIES * (32 + 1))  // strategy_by_asset HashMap
        + 4 + (MAX_MODULES * (1 + 32))     // module_by_strategy HashMap
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

/// A fill message structure.
#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct FillMessage {
    pub intent_id: [u8;32],
    pub solver: Pubkey,
    pub execution_timestamp: u64,
    pub fee: u32,
}

impl FillMessage {
    pub const SIZE: usize = 32 + 32 + 8 + 4;
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
pub struct DepositedEvent {
    pub user: Pubkey,
    pub asset: Pubkey,
    pub amount: u64,
}

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
    pub amount: u64,
    pub max_fee: u32,
    pub origin_domain: u32,
    pub ttl: u64,
    pub timestamp: u64,
    pub destinations: Vec<u32>,
    pub data: Vec<u8>,
}

#[event]
pub struct IntentFilledEvent {
    pub intent_id: [u8;32],
    pub solver: Pubkey,
    pub fee: u32,
}

#[event]
pub struct IntentQueueProcessedEvent {
    pub message_id: [u8;32],
    pub first_index: u64,
    pub last_index: u64,
    pub fee_spent: u64,
}

#[event]
pub struct FillQueueProcessedEvent {
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
pub struct StrategySetEvent {
    pub asset: Pubkey,
    pub strategy: u8,
}

#[event]
pub struct ExternalCallExecutedEvent {
    pub target_program_id: Pubkey,
}

#[event]
pub struct DebtMintedEvent {
    pub asset: Pubkey,
    pub recipient: Pubkey,
    pub amount: u64,
}

#[event]
pub struct BurnedEvent {
    pub asset: Pubkey,
    pub user: Pubkey,
    pub amount: u64,
}

#[event]
pub struct MessageReceivedEvent {
    pub origin: u32,
    pub sender: Pubkey,
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
    #[msg("Invalid Permit2 data")]
    InvalidPermit2Data,
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

fn update_strategy(
    strategies: &mut HashMap<Pubkey, u8>,
    asset: Pubkey,
    new_strategy: u8,
) -> Result<()> {
    strategies.insert(asset, new_strategy);
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
