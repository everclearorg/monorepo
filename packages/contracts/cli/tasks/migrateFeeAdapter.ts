import * as anchor from '@coral-xyz/anchor';
import * as c from '../common';
import { EverclearSpoke } from '@chimera-monorepo/utils';

/**
 * Migrates fee_adapter_state account on Solana to new layout with fill_signer
 * 
 * This script:
 * 1. Checks current account state
 * 2. Closes the old account (if it exists and can be closed)
 * 3. Re-initializes with correct layout including fill_signer
 */
export async function migrateFeeAdapter(): Promise<void> {
  const environment = await c.chooseEnvironment();
  
  console.log('\n=== Solana Fee Adapter Migration ===');
  console.log('Environment:', environment);
  
  // Load IDL based on environment
  let idl: anchor.Idl;
  const isStaging = environment.includes('Staging');
  const idlPath = isStaging
    ? '../../agents/lighthouse/src/idl/everclear_spoke.staging.json'
    : '../../agents/lighthouse/src/idl/everclear_spoke.json';
  
  try {
    idl = require(idlPath);
  } catch (error) {
    console.error('❌ Failed to load IDL from:', idlPath);
    console.error('Error:', error);
    return;
  }
  
  // Get program ID from IDL
  const programId = new anchor.web3.PublicKey(idl.address);
  console.log('Program ID:', programId.toBase58());
  
  // Get RPC URL - use mainnet for staging/production, devnet for testnet
  const rpcUrl = isStaging || environment.includes('Production')
    ? 'https://api.mainnet-beta.solana.com'
    : 'https://api.devnet.solana.com';
  
  console.log('RPC URL:', rpcUrl);
  
  // Set up connection
  const connection = new anchor.web3.Connection(rpcUrl, 'confirmed');
  const wallet = anchor.Wallet.local();
  const provider = new anchor.AnchorProvider(connection, wallet, {
    commitment: 'confirmed',
  });
  
  const program = new anchor.Program(idl, programId, provider) as anchor.Program<EverclearSpoke>;
  
  // Derive PDAs
  const [spokeStateAddress] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('spoke-state')],
    programId,
  );
  
  const [feeAdapterStateAddress, feeAdapterStateBump] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('fee-adapter-state')],
    programId,
  );
  
  console.log('\n=== Account Addresses ===');
  console.log('Spoke State:', spokeStateAddress.toBase58());
  console.log('Fee Adapter State:', feeAdapterStateAddress.toBase58());
  console.log('Derived Bump:', feeAdapterStateBump);
  
  // Check spoke state to get owner
  let spokeStateOwner: anchor.web3.PublicKey | null = null;
  try {
    const spokeState = await program.account.spokeState.fetch(spokeStateAddress);
    spokeStateOwner = spokeState.owner;
    console.log('\n=== Owner Check ===');
    console.log('Spoke State Owner:', spokeStateOwner.toBase58());
    console.log('Your Wallet:', wallet.publicKey.toBase58());
    
    if (!spokeStateOwner.equals(wallet.publicKey)) {
      console.log('\n⚠️  WARNING: Your wallet is not the owner!');
      console.log('  You need to use the owner account to perform migration.');
      console.log('  Owner account:', spokeStateOwner.toBase58());
      const proceed = await c.input('Continue anyway? (yes/no): ');
      if (proceed.toLowerCase() !== 'yes') {
        console.log('Migration cancelled. Please use the owner account.');
        return;
      }
    } else {
      console.log('✓ You are the owner - migration can proceed');
    }
  } catch (error) {
    console.log('⚠️  Could not fetch spoke state owner');
    console.log('  Migration may fail if you are not the owner');
  }
  
  // Check current account state
  console.log('\n=== Checking Current Account State ===');
  let accountInfo;
  try {
    accountInfo = await connection.getAccountInfo(feeAdapterStateAddress);
    if (accountInfo) {
      console.log('Account exists');
      console.log('Account size:', accountInfo.data.length, 'bytes');
      console.log('Expected size: 107 bytes (new layout) or 75 bytes (old layout)');
      
      // Try to deserialize
      try {
        const state = await program.account.feeAdapterState.fetch(feeAdapterStateAddress);
        console.log('✓ Account can be deserialized');
        console.log('Current state:');
        console.log('  Initialized:', state.initialized);
        console.log('  Paused:', state.paused);
        console.log('  Fee Recipient:', state.feeRecipient.toBase58());
        console.log('  Fee Signer:', state.feeSigner.toBase58());
        console.log('  Fill Signer:', state.fillSigner?.toBase58() || 'MISSING');
        console.log('  Stored Bump:', state.bump);
        
        if (state.fillSigner) {
          console.log('\n⚠️  Account already has fill_signer. Migration may not be needed.');
          const proceed = await c.input('Proceed with migration anyway? (yes/no): ');
          if (proceed.toLowerCase() !== 'yes') {
            console.log('Migration cancelled.');
            return;
          }
        }
      } catch (error) {
        console.log('✗ Account cannot be deserialized (old layout or corrupted)');
        console.log('  This is expected if account has old layout (75 bytes)');
      }
    } else {
      console.log('Account does not exist - will create new one');
    }
  } catch (error) {
    console.error('Error checking account:', error);
    return;
  }
  
  // Get migration parameters
  console.log('\n=== Migration Parameters ===');
  
  const feeRecipientInput = await c.input('Fee Recipient Pubkey (or press Enter to use current): ');
  let feeRecipient: anchor.web3.PublicKey;
  if (feeRecipientInput) {
    feeRecipient = new anchor.web3.PublicKey(feeRecipientInput);
  } else {
    // Try to get from current state
    try {
      const state = await program.account.feeAdapterState.fetch(feeAdapterStateAddress);
      feeRecipient = state.feeRecipient;
      console.log('Using current fee recipient:', feeRecipient.toBase58());
    } catch {
      feeRecipient = new anchor.web3.PublicKey('9WUUr2WNUiKMzwxJgbb4oxS81oYAyhrBFkv3NSg2mjbj');
      console.log('Using default fee recipient:', feeRecipient.toBase58());
    }
  }
  
  const feeSignerInput = await c.input('Fee Signer Pubkey (or press Enter to use current): ');
  let feeSigner: anchor.web3.PublicKey;
  if (feeSignerInput) {
    feeSigner = new anchor.web3.PublicKey(feeSignerInput);
  } else {
    try {
      const state = await program.account.feeAdapterState.fetch(feeAdapterStateAddress);
      feeSigner = state.feeSigner;
      console.log('Using current fee signer:', feeSigner.toBase58());
    } catch {
      feeSigner = new anchor.web3.PublicKey('3i2FX2dGxjMcExdbNyohtrSVTSwTS7BbfEYpbehKXUMT');
      console.log('Using default fee signer:', feeSigner.toBase58());
    }
  }
  
  // For fill_signer, try to use fee_signer as default (common case)
  const fillSignerInput = await c.input(`Fill Signer Pubkey (or press Enter to use fee_signer: ${feeSigner.toBase58()}): `);
  let fillSigner: anchor.web3.PublicKey;
  if (fillSignerInput) {
    fillSigner = new anchor.web3.PublicKey(fillSignerInput);
  } else {
    // Default to fee_signer (most common case)
    fillSigner = feeSigner;
    console.log('Using fee_signer as fill_signer:', fillSigner.toBase58());
  }
  
  console.log('\n=== Migration Summary ===');
  console.log('Fee Recipient:', feeRecipient.toBase58());
  console.log('Fee Signer:', feeSigner.toBase58());
  console.log('Fill Signer:', fillSigner.toBase58());
  
  const confirm = await c.input('\nProceed with migration? (yes/no): ');
  if (confirm.toLowerCase() !== 'yes') {
    console.log('Migration cancelled.');
    return;
  }
  
  // Step 1: Try to close the account if it exists
  if (accountInfo) {
    console.log('\n=== Step 1: Closing Old Account ===');
    try {
      // Try to close if account can be deserialized
      const state = await program.account.feeAdapterState.fetch(feeAdapterStateAddress);
      console.log('Attempting to close account...');
      
      const closeTx = await program.methods
        .closeFeeAdapter()
        .accounts({
          spokeState: spokeStateAddress,
          feeAdapterState: feeAdapterStateAddress,
          payer: wallet.publicKey,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .rpc();
      
      console.log('✓ Account closed successfully');
      console.log('Transaction:', closeTx);
      
      // Wait a bit for confirmation
      await new Promise(resolve => setTimeout(resolve, 2000));
    } catch (error: any) {
      if (error.message?.includes('AccountDidNotDeserialize') || error.message?.includes('deserialize')) {
        console.log('⚠️  Cannot close account (cannot deserialize)');
        console.log('  This is expected for old layout accounts.');
        console.log('  You may need to manually close the account or the migration will attempt to overwrite it.');
        
        const proceed = await c.input('Continue with migration? (yes/no): ');
        if (proceed.toLowerCase() !== 'yes') {
          console.log('Migration cancelled.');
          return;
        }
      } else {
        console.error('❌ Error closing account:', error);
        console.log('Attempting to proceed with migration anyway...');
      }
    }
  }
  
  // Step 2: Migrate/Re-initialize
  console.log('\n=== Step 2: Migrating Account ===');
  try {
    const migrateTx = await program.methods
      .migrateFeeAdapter(
        feeRecipient,
        feeSigner,
        fillSigner,
      )
      .accounts({
        spokeState: spokeStateAddress,
        feeAdapterState: feeAdapterStateAddress,
        payer: wallet.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();
    
    console.log('✓ Migration successful!');
    console.log('Transaction:', migrateTx);
    
    // Verify the migration
    console.log('\n=== Verifying Migration ===');
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const newState = await program.account.feeAdapterState.fetch(feeAdapterStateAddress);
    console.log('✓ Account verified:');
    console.log('  Initialized:', newState.initialized);
    console.log('  Paused:', newState.paused);
    console.log('  Fee Recipient:', newState.feeRecipient.toBase58());
    console.log('  Fee Signer:', newState.feeSigner.toBase58());
    console.log('  Fill Signer:', newState.fillSigner.toBase58());
    console.log('  Bump:', newState.bump);
    
    const accountInfoAfter = await connection.getAccountInfo(feeAdapterStateAddress);
    console.log('  Account size:', accountInfoAfter?.data.length, 'bytes (expected: 107)');
    
    if (newState.fillSigner && accountInfoAfter?.data.length === 107) {
      console.log('\n✅ Migration completed successfully!');
    } else {
      console.log('\n⚠️  Migration completed but verification shows issues');
    }
  } catch (error: any) {
    if (error.message?.includes('already in use') || error.message?.includes('AccountDiscriminatorAlreadySet')) {
      console.error('❌ Account already exists and cannot be overwritten');
      console.error('  You need to close the account first.');
      console.error('  If the account cannot be deserialized, you may need to:');
      console.error('  1. Manually close it using Solana CLI');
      console.error('  2. Or use a different approach');
    } else {
      console.error('❌ Migration failed:', error);
      throw error;
    }
  }
}

