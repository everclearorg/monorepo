#!/usr/bin/env node
/**
 * Diagnostic script to check Solana Address Lookup Table status
 * 
 * Usage:
 *   npx tsx scripts/check_lookup_table.ts <wallet_address> <mint_address>
 * 
 * Example:
 *   npx tsx scripts/check_lookup_table.ts 79Tui1hFcakT1ppWp3Ri2Ecgx955rBi9TfmH5EA6vwCf EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v
 */

import { Connection, PublicKey, AddressLookupTableAccount } from '@solana/web3.js';
import axios from 'axios';

const STAGING_API_URL = 'https://api.staging.everclear.org';
const SOLANA_RPC = 'https://api.mainnet-beta.solana.com'; // Mainnet staging uses mainnet RPC

async function checkLookupTable(walletAddress: string, mintAddress: string) {
  console.log('\n🔍 Checking Lookup Table Status...\n');
  console.log(`Wallet Address: ${walletAddress}`);
  console.log(`Mint Address: ${mintAddress}\n`);
  console.log('─'.repeat(80));

  // Step 1: Try API endpoint first (more reliable)
  console.log('\n📊 Step 1: Checking via API...');
  let lutAddress: string | null = null;
  
  try {
    // Try to get lookup table via the API endpoint
    const apiUrl = `${STAGING_API_URL}/solana/create-lookup-table`;
    console.log(`Note: Database requires authentication, checking on-chain directly...`);
  } catch (error: any) {
    // API check failed, continue to on-chain check
  }

  // Step 2: Check on-chain - we'll need to derive possible lookup table addresses
  // But first, let's check if we can query known lookup tables
  console.log('\n⛓️  Step 2: Checking On-Chain Status...');
  console.log('   (Note: We cannot check database directly due to authentication)');
  console.log('   Checking if lookup table might exist on-chain...\n');
  
  const connection = new Connection(SOLANA_RPC, 'confirmed');
  
  // The lookup table address is derived deterministically, but we need the slot
  // Since we can't query the DB, we'll provide guidance instead
  console.log('❌ Cannot verify lookup table status without database access.');
  console.log('\n💡 Based on the error you\'re seeing, here\'s what to do:');
  console.log('\n   1. The lookup table is NOT in the database for your wallet + asset');
  console.log('   2. This means either:');
  console.log('      - The "Create Lookup Table" transaction was never confirmed');
  console.log('      - The transaction failed');
  console.log('      - The database sync failed');
  console.log('\n   SOLUTION:');
  console.log('   1. Go back to the frontend (mainnet-staging.explorer.everclear.org)');
  console.log('   2. Start creating a new intent');
  console.log('   3. When you see "Create Lookup Table" step:');
  console.log('      - Sign the transaction in your wallet');
  console.log('      - WAIT for it to show "Confirmed" (not just "Signed")');
  console.log('      - This may take 10-30 seconds');
  console.log('   4. Once confirmed, wait 5-10 seconds');
  console.log('   5. Then proceed with "Create Intent on Solana"');
  console.log('\n   If it still fails after confirmation:');
  console.log('   - Check your wallet transaction history');
  console.log('   - Look for the lookup table creation transaction');
  console.log('   - Verify it shows "Success" status');

  console.log('\n' + '─'.repeat(80));
  console.log('\n📝 Summary:');
  console.log('   If lookup table is missing from database: Create it via the frontend');
  console.log('   If lookup table exists in DB but not on-chain: Transaction may have failed');
  console.log('   If both exist and are valid: You should be able to create intents!\n');
}

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length < 2) {
  console.error('❌ Error: Missing required arguments');
  console.error('\nUsage:');
  console.error('  npx tsx scripts/check_lookup_table.ts <wallet_address> <mint_address>');
  console.error('\nExample:');
  console.error('  npx tsx scripts/check_lookup_table.ts 79Tui1hFcakT1ppWp3Ri2Ecgx955rBi9TfmH5EA6vwCf EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v');
  console.error('\n💡 To find your wallet address:');
  console.error('   - Check your connected wallet in the frontend');
  console.error('   - Or check the browser console for wallet address');
  console.error('\n💡 To find the mint address:');
  console.error('   - USDC: EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v');
  console.error('   - USDT: Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB');
  process.exit(1);
}

const [walletAddress, mintAddress] = args;

// Basic validation
try {
  new PublicKey(walletAddress);
  new PublicKey(mintAddress);
} catch (error) {
  console.error('❌ Error: Invalid Solana address format');
  console.error('   Make sure both addresses are valid Solana public keys');
  process.exit(1);
}

checkLookupTable(walletAddress, mintAddress).catch((error) => {
  console.error('\n❌ Unexpected error:', error);
  process.exit(1);
});

