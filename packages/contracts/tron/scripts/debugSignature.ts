// Debug script to verify signatures and addresses
// yarn ts-node tron/scripts/debugSignature.ts

import TronWeb from 'tronweb';
import fs from 'fs/promises';
import 'dotenv/config';

const tronGrid = new TronWeb.TronWeb({
  fullHost: 'https://api.trongrid.io',
  headers: { 'TRON-PRO-API-KEY': process.env.TRONGRID_API_KEY },
});

async function debugSignature() {
  console.log('🔍 Debug Signature Verification Script');
  console.log('=====================================\n');

  // 1. Check TRON_KEY environment variable
  console.log('1. Environment Check:');
  const privateKey = process.env.TRON_KEY;
  if (!privateKey) {
    console.log('❌ TRON_KEY is not set');
    return;
  }
  console.log('✅ TRON_KEY is set');
  console.log('   Length:', privateKey.length);
  console.log('   Starts with 0x:', privateKey.startsWith('0x'));
  
  // Clean the private key
  const cleanPrivateKey = privateKey.startsWith('0x') ? privateKey.slice(2) : privateKey;
  console.log('   Clean length:', cleanPrivateKey.length);
  console.log('   Clean key (first 8 chars):', cleanPrivateKey.substring(0, 8) + '...');

  // 2. Verify the address from private key
  console.log('\n2. Address Verification:');
  try {
    const tronWeb = new TronWeb.TronWeb({
      fullHost: 'https://api.trongrid.io',
      privateKey: cleanPrivateKey
    });
    const address = tronWeb.defaultAddress.base58;
    console.log('✅ Address from private key:', address);
    console.log('✅ Expected address: TATCzhQqxq9DRppGHiEFvFuoDW6tHaESqg');
    console.log('✅ Match:', address === 'TATCzhQqxq9DRppGHiEFvFuoDW6tHaESqg');
  } catch (err: any) {
    console.log('❌ Error getting address from private key:', err.message);
  }

  // 3. Load and analyze the transaction
  console.log('\n3. Transaction Analysis:');
  try {
    const tx = JSON.parse(await fs.readFile('tron/pendingTransactions/updateSecurityModule.json', 'utf8'));
    console.log('✅ Transaction loaded:', tx.txID);
    console.log('   Signatures count:', tx.signature?.length || 0);
    
    if (tx.signature && tx.signature.length > 0) {
      console.log('\n   Signature Analysis:');
      tx.signature.forEach((sig: string, index: number) => {
        console.log(`   Signature ${index + 1}:`);
        console.log(`     Length: ${sig.length}`);
        console.log(`     Has 0x prefix: ${sig.startsWith('0x')}`);
        console.log(`     First 16 chars: ${sig.substring(0, 16)}...`);
        console.log(`     Last 16 chars: ...${sig.substring(sig.length - 16)}`);
      });
    }
  } catch (err: any) {
    console.log('❌ Error loading transaction:', err.message);
  }

  // 4. Test signature creation
  console.log('\n4. Signature Creation Test:');
  try {
    const tronWeb = new TronWeb.TronWeb({
      fullHost: 'https://api.trongrid.io',
      privateKey: cleanPrivateKey
    });
    
    // Create a test message
    const testMessage = 'Hello, Tron!';
    console.log('   Test message:', testMessage);
    
    // Sign the message
    const signature = await tronWeb.trx.signMessage(testMessage);
    console.log('   Signature created:', signature);
    console.log('   Signature length:', signature.length);
    console.log('   Has 0x prefix:', signature.startsWith('0x'));
    
    // Verify the signature
    const isValid = await tronWeb.trx.verifyMessage(testMessage, signature, tronWeb.defaultAddress.base58);
    console.log('   Signature valid:', isValid);
    
  } catch (err: any) {
    console.log('❌ Error testing signature creation:', err.message);
  }

  // 5. Check multisig contract permissions
  console.log('\n5. Multisig Contract Check:');
  try {
    const multisigAddress = 'TCx6QEfz24VYDTcwzyoEzhRe6a3YTAPmSp';
    console.log('   Multisig address:', multisigAddress);
    
    // Get contract info
    const contract = await tronGrid.trx.getContract(multisigAddress);
    console.log('   Contract exists:', !!contract);
    
    // Try to get account info
    const account = await tronGrid.trx.getAccount(multisigAddress);
    console.log('   Account balance:', account.balance || 0, 'sun');
    
  } catch (err: any) {
    console.log('❌ Error checking multisig contract:', err.message);
  }

  // 6. Check transaction weight
  console.log('\n6. Transaction Weight Check:');
  try {
    const tx = JSON.parse(await fs.readFile('tron/pendingTransactions/updateSecurityModule.json', 'utf8'));
    const weight = await tronGrid.trx.getSignWeight(tx);
    console.log('   Weight result:', JSON.stringify(weight, null, 2));
  } catch (err: any) {
    console.log('❌ Error checking transaction weight:', err.message);
  }

  console.log('\n🔍 Debug complete!');
}

debugSignature().catch(console.error);