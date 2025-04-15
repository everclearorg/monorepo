/*
   Integration tests for the Everclear Solana programs.
   These tests use solana_program_test and Anchor's testing framework.
*/

use anchor_lang::prelude::*;
use anchor_lang::InstructionData;
use solana_program::instruction::Instruction;
use solana_program_test::*;
use solana_sdk::{
    signature::Keypair,
    signer::Signer,
    transaction::Transaction,
    commitment_config::CommitmentLevel,
};

use spoke_gateway::SpokeGatewayState;
use spoke_storage::SpokeStorageState;
use call_executor::ID as CALL_EXE_ID;

// Test constants
const TEST_LAMPORTS: u64 = 1_000_000_000;
const MAX_ACCOUNT_SIZE: usize = 10240;

/// Helper function to create and execute a transaction
async fn execute_transaction(
    banks_client: &mut BanksClient,
    payer: &Keypair,
    recent_blockhash: Hash,
    instructions: Vec<Instruction>,
) -> Result<(), BanksClientError> {
    let mut transaction = Transaction::new_with_payer(&instructions, Some(&payer.pubkey()));
    transaction.sign(&[payer], recent_blockhash);
    banks_client.process_transaction_with_commitment(
        transaction,
        CommitmentLevel::Processed
    ).await
}

/// Helper to setup a test environment
async fn setup_test_env(program_id: Pubkey) -> (BanksClient, Keypair, Hash) {
    let mut program_test = ProgramTest::new(
        "test_program",
        program_id,
        processor!(spoke_gateway::entry),
    );
    program_test.set_compute_max_units(100_000);
    program_test.start().await
}

#[tokio::test]
async fn test_spoke_gateway_initialize_and_get() {
    let program_id = spoke_gateway::ID;
    let (mut banks_client, payer, recent_blockhash) = setup_test_env(program_id).await;

    // Create gateway account
    let gateway_key = Keypair::new();
    let rent = banks_client.get_rent().await.unwrap();
    let account_rent = rent.minimum_balance(8 + SpokeGatewayState::LEN);
    
    let create_account_ix = solana_sdk::system_instruction::create_account(
        &payer.pubkey(),
        &gateway_key.pubkey(),
        account_rent,
        (8 + SpokeGatewayState::LEN) as u64,
        &program_id,
    );

    // Initialize gateway
    let owner = Keypair::new().pubkey();
    let mailbox = Keypair::new().pubkey();
    let receiver = Keypair::new().pubkey();
    let interchain_security_module = Keypair::new().pubkey();
    let everclear_id: u32 = 1234;
    let everclear_gateway = [5u8; 32];

    let init_ix = Instruction {
        program_id,
        accounts: vec![
            AccountMeta::new(gateway_key.pubkey(), false),
            AccountMeta::new(payer.pubkey(), true),
            AccountMeta::new_readonly(solana_program::system_program::ID, false),
        ],
        data: spoke_gateway::instruction::InitializeGateway {
            owner,
            mailbox,
            receiver,
            interchain_security_module,
            everclear_id,
            everclear_gateway,
        }
        .data(),
    };

    // Execute transaction
    execute_transaction(
        &mut banks_client,
        &payer,
        recent_blockhash,
        vec![create_account_ix, init_ix]
    ).await.unwrap();

    // Verify the state
    let account = banks_client
        .get_account(gateway_key.pubkey())
        .await
        .unwrap()
        .expect("Gateway account not found");
    
    assert_eq!(account.owner, program_id);
    
    // TODO: Add deserialization and state verification
}

#[tokio::test]
async fn test_call_executor_excessively_safe_call() {
    let program_id = call_executor::ID;
    let (mut banks_client, payer, recent_blockhash) = setup_test_env(program_id).await;

    let target = Keypair::new().pubkey();
    let max_copy: u16 = 256;
    let calldata = vec![1, 2, 3, 4, 5];

    let ix = Instruction {
        program_id,
        accounts: vec![
            AccountMeta::new(payer.pubkey(), true),
            AccountMeta::new_readonly(solana_program::system_program::ID, false),
        ],
        data: call_executor::instruction::ExcessivelySafeCall {
            target,
            gas: 0,
            value: 0,
            max_copy,
            calldata: calldata.clone(),
        }
        .data(),
    };

    let result = execute_transaction(
        &mut banks_client,
        &payer,
        recent_blockhash,
        vec![ix]
    ).await;
    
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_spoke_message_receiver_var_update() {
    let program_id = spoke_message_receiver::ID;
    let (mut banks_client, payer, recent_blockhash) = setup_test_env(program_id).await;

    // Create state account
    let state_key = Keypair::new();
    let initial_gateway = Keypair::new().pubkey();
    let state_data = SpokeStorageState {
        owner: Keypair::new().pubkey(),
        paused: false,
        nonce: 0,
        domain: 1,
        message_gas_limit: 20_000_000,
        gateway: initial_gateway,
        message_receiver: Keypair::new().pubkey(),
        lighthouse: Keypair::new().pubkey(),
        watchtower: Keypair::new().pubkey(),
        call_executor: Keypair::new().pubkey(),
        everclear: 9999,
        intent_queue: vec![],
        fill_queue: vec![],
        strategies: vec![],
        modules: vec![],
        balances: vec![],
    };

    let serialized_data = bincode::serialize(&state_data).unwrap();
    let rent = banks_client.get_rent().await.unwrap();
    let account_rent = rent.minimum_balance(serialized_data.len());

    let create_account_ix = solana_sdk::system_instruction::create_account(
        &payer.pubkey(),
        &state_key.pubkey(),
        account_rent,
        serialized_data.len() as u64,
        &program_id,
    );

    // Create var update message
    let new_gateway = Keypair::new().pubkey();
    let mut message = vec![1u8]; // VAR_UPDATE type
    message.extend_from_slice(&[1u8; 32]);
    message.extend_from_slice(new_gateway.as_ref());

    let update_ix = Instruction {
        program_id,
        accounts: vec![AccountMeta::new(state_key.pubkey(), false)],
        data: spoke_message_receiver::instruction::ReceiveMessage { message }.data(),
    };

    // Execute transaction
    execute_transaction(
        &mut banks_client,
        &payer,
        recent_blockhash,
        vec![create_account_ix, update_ix]
    ).await.unwrap();

    // Verify the state update
    let account = banks_client
        .get_account(state_key.pubkey())
        .await
        .unwrap()
        .expect("State account not found");
    
    // TODO: Add deserialization and state verification
}

#[tokio::test]
#[should_panic(expected = "Custom program error: 0x1")]
async fn test_call_executor_invalid_inputs() {
    let program_id = call_executor::ID;
    let (mut banks_client, payer, recent_blockhash) = setup_test_env(program_id).await;

    // Try to call with invalid inputs
    let ix = Instruction {
        program_id,
        accounts: vec![
            AccountMeta::new(payer.pubkey(), true),
            AccountMeta::new_readonly(solana_program::system_program::ID, false),
        ],
        data: call_executor::instruction::ExcessivelySafeCall {
            target: Pubkey::default(), // Invalid target
            gas: 0,
            value: 0,
            max_copy: 0, // Invalid max_copy
            calldata: vec![], // Empty calldata
        }
        .data(),
    };

    execute_transaction(
        &mut banks_client,
        &payer,
        recent_blockhash,
        vec![ix]
    ).await.unwrap();
} 