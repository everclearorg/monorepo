// yarn ts-node tron/scripts/signTxMultisig.ts tron/pendingTransactions/tx.json [hot|cold]


import TronWeb from 'tronweb';
import TransportNodeHid from '@ledgerhq/hw-transport-node-hid';
import Trx from '@ledgerhq/hw-app-trx';
import fs from 'fs/promises';
import 'dotenv/config';

const LEDGER_PATH = "44'/195'/0'/0/0";

const tronGrid = new TronWeb.TronWeb({
  fullHost: 'https://api.trongrid.io',
  headers: { 'TRON-PRO-API-KEY': process.env.TRONGRID_API_KEY },
});

async function checkAccountResources(address: string, tx?: any) {
  try {
    const account = await tronGrid.trx.getAccount(address);
    const resources = await tronGrid.trx.getAccountResources(address);
    console.log(`Account ${address} resources:`);
    console.log('  - Balance:', account.balance || 0, 'sun (', (account.balance || 0) / 1000000, 'TRX)');
    console.log('  - Bandwidth used:', resources.freeNetUsed || 0);
    console.log('  - Bandwidth limit:', resources.freeNetLimit || 0);
    console.log('  - Bandwidth remaining:', (resources.freeNetLimit || 0) - (resources.freeNetUsed || 0));
    console.log('  - Energy used:', resources.EnergyUsed || 0);
    console.log('  - Energy limit:', resources.EnergyLimit || 0);
    console.log('  - Energy remaining:', (resources.EnergyLimit || 0) - (resources.EnergyUsed || 0));
    
    // Calculate transaction size if tx is provided
    if (tx?.raw_data_hex) {
      const txSize = Math.ceil(tx.raw_data_hex.length / 2);
      const feeLimit = tx.raw_data?.fee_limit || 0;
      console.log('  - Transaction size (bytes):', txSize);
      console.log('  - Fee limit:', feeLimit, 'sun (', feeLimit / 1000000, 'TRX)');
      console.log('  - Can fit in remaining bandwidth:', txSize <= (resources.freeNetLimit || 0) - (resources.freeNetUsed || 0));
      console.log('  - Sufficient balance for fee:', (account.balance || 0) >= feeLimit);
      
      // Check if this is a contract interaction (multisig)
      if (tx.raw_data?.contract?.[0]?.type === 'TriggerSmartContract') {
        console.log('  - ⚠️  This is a contract interaction - requires ENERGY, not bandwidth');
        console.log('  - ⚠️  Account has 0 energy limit - will use TRX to pay for energy');
        console.log('  - ⚠️  Need at least', feeLimit / 1000000, 'TRX to pay for energy');
      }
    }
    
    return { account, resources };
  } catch (err: any) {
    console.log('Error checking account resources:', err.message);
    return null;
  }
}

async function loadTx(source: string) {
  if (source.endsWith('.json')) return JSON.parse(await fs.readFile(source, 'utf8'));

  // assume it's a txID
  const tx = await tronGrid.trx.getTransaction(source);
  if (!tx) throw new Error('txID not found on TronGrid');
  return tx;
}

async function saveTransaction(tx: any, originalPath: string) {
  // Only save if the original path is a JSON file
  if (!originalPath.endsWith('.json')) {
    console.log('⚠️  Cannot save transaction - original input was a transaction ID, not a JSON file');
    console.log('   Transaction data:', JSON.stringify(tx, null, 2));
    return;
  }

  try {
    // Create backup of original file
    const backupPath = `${originalPath}.backup.${Date.now()}`;
    try {
      await fs.copyFile(originalPath, backupPath);
      console.log(`📁 Backup created: ${backupPath}`);
    } catch (err) {
      console.log('⚠️  Could not create backup (file may not exist yet)');
    }

    // Write updated transaction
    await fs.writeFile(originalPath, JSON.stringify(tx, null, 2));
    console.log(`💾 Transaction saved to: ${originalPath}`);
  } catch (err: any) {
    console.log('❌ Error saving transaction:', err.message);
    console.log('   Transaction data:', JSON.stringify(tx, null, 2));
  }
}

async function signWithLedger(tx: any): Promise<string> {
  console.log('🔐 Using Ledger for signing...');
  
  const paths = await TransportNodeHid.list();
  if (paths.length === 0) {
    throw new Error('No Ledger device found. Please connect your Ledger and open the Tron app.');
  }
  
  const transport = await TransportNodeHid.open(paths[0]);
  const ledger = new Trx(transport);

  console.log(`📱 Using Ledger at path: ${paths[0]}`);
  
  try {
    const sig = await ledger.signTransaction(LEDGER_PATH, tx.raw_data_hex, []);
    console.log('✅ Ledger signature obtained successfully');
    return sig;
  } finally {
    await transport.close();
  }
}

async function signWithPrivateKey(tx: any): Promise<string> {
  console.log('🔑 Using private key for signing...');
  
  const privateKey = process.env.TRON_KEY;
  if (!privateKey) {
    throw new Error('TRON_KEY environment variable not set. Please set it for hot wallet signing.');
  }
  
  // Remove '0x' prefix if present
  const cleanPrivateKey = privateKey.startsWith('0x') ? privateKey.slice(2) : privateKey;
  
  if (cleanPrivateKey.length !== 64) {
    throw new Error('Invalid private key length. Expected 64 hex characters (32 bytes).');
  }
  
  try {
    // Create TronWeb instance with private key
    const tronWeb = new TronWeb.TronWeb({
      fullHost: 'https://api.trongrid.io',
      headers: { 'TRON-PRO-API-KEY': process.env.TRONGRID_API_KEY },
      privateKey: cleanPrivateKey
    });
    
    // Try approach 1: Create a completely clean transaction object
    try {
      const cleanTx = {
        txID: tx.txID,
        raw_data: tx.raw_data,
        raw_data_hex: tx.raw_data_hex,
        visible: tx.visible
        // No signature field at all
      };
      
      const signedTx = await tronWeb.trx.sign(cleanTx);
      const signature = signedTx.signature[0];
      
      console.log('✅ Private key signature obtained successfully');
      return signature;
    } catch (err: any) {
      console.log('⚠️  First approach failed, trying alternative method...');
      
      // Try approach 2: Sign using raw hex data directly
      const rawDataHex = tx.raw_data_hex;
      const signature = await tronWeb.trx.signMessage(rawDataHex);
      
      console.log('✅ Private key signature obtained successfully (alternative method)');
      return signature;
    }
  } catch (err: any) {
    throw new Error(`Failed to sign with private key: ${err.message}`);
  }
}

(async () => {
  const src = process.argv[2];
  const signingMode = process.argv[3]; // 'hot' or 'cold'
  
  if (!src) throw new Error('Usage: add-signature.ts <txID | tx.json> [hot|cold]');
  if (signingMode && !['hot', 'cold'].includes(signingMode)) {
    throw new Error('Signing mode must be either "hot" (private key) or "cold" (Ledger)');
  }
  
  // Default to cold (Ledger) if no mode specified
  const isHotWallet = signingMode === 'hot';
  console.log(`🔐 Signing mode: ${isHotWallet ? 'HOT WALLET (private key)' : 'COLD WALLET (Ledger)'}`);

  const tx: any = await loadTx(src);
  console.log('loaded tx', tx.txID, '  signatures so far:', tx.signature?.length ?? 0);

  // Check if transaction already has enough signatures to execute
  if (tx.signature && tx.signature.length > 0) {
    console.log('Checking if transaction already has enough signatures...');
    const weight = await tronGrid.trx.getSignWeight(tx);
    const cur = (weight.result as any).current_weight;
    const thr = (weight.permission as any).threshold;
    console.log(`Current signature weight: ${cur} / ${thr}`);

    if ((weight.result as any).ENOUGH_PERMISSION) {
      console.log('🎉 Transaction already has enough signatures! Attempting to broadcast...');
      
      // Debug: Log transaction details
      const ownerAddress = tx.raw_data?.contract?.[0]?.parameter?.value?.owner_address;
      console.log('Transaction details:');
      console.log('  - From address:', ownerAddress);
      console.log('  - Contract address:', tx.raw_data?.contract?.[0]?.parameter?.value?.contract_address);
      console.log('  - Fee limit:', tx.raw_data?.fee_limit);
      console.log('  - Call value:', tx.raw_data?.contract?.[0]?.parameter?.value?.call_value);
      
      // Check account resources before broadcasting
      if (ownerAddress) {
        await checkAccountResources(ownerAddress, tx);
      }
      
      try {
        const response = await tronGrid.trx.broadcast(tx);
        console.log('Broadcast response:', response);
        if (response.result) {
          console.log('✅ Transaction broadcast successful!');
          return;
        } else {
          console.log('⚠️  Broadcast failed, proceeding with signing...');
        }
      } catch (err: any) {
        console.log('⚠️  Broadcast error:', err.message, '- proceeding with signing...');
        
        // Provide specific guidance for bandwidth errors
        if (err.message?.includes('BANDWIDTH_ERROR') || err.message?.includes('INSUFFICIENT')) {
          const account = await tronGrid.trx.getAccount(ownerAddress);
          const feeLimit = tx.raw_data?.fee_limit || 0;
          console.log('\n🔧 SOLUTION: The multisig account needs more TRX to pay for energy');
          console.log('   Current balance:', account.balance || 0, 'sun (', (account.balance || 0) / 1000000, 'TRX)');
          console.log('   Required fee:', feeLimit, 'sun (', feeLimit / 1000000, 'TRX)');
          console.log('   Need to send:', Math.max(0, feeLimit - (account.balance || 0)), 'sun (', Math.max(0, feeLimit - (account.balance || 0)) / 1000000, 'TRX)');
          console.log('   to address:', ownerAddress);
        }
      }
    }
  }

  // Sign the transaction using the selected method
  let sig: string;
  try {
    if (isHotWallet) {
      sig = await signWithPrivateKey(tx);
    } else {
      sig = await signWithLedger(tx);
    }
  } catch (err: any) {
    console.log('❌ Signing failed:', err.message);
    if (isHotWallet) {
      console.log('💡 For hot wallet signing, make sure TRON_KEY is set in your environment');
    } else {
      console.log('💡 For cold wallet signing, make sure your Ledger is connected and Tron app is open');
    }
    return;
  }

  if (tx.signature?.includes(sig)) {
    console.log('⚠️  This key has already signed. Exiting.');
    return;
  }
  
  // Add the new signature
  tx.signature = [...(tx.signature || []), sig];
  console.log(`✅ Signature added. Total signatures: ${tx.signature.length}`);

  const weight = await tronGrid.trx.getSignWeight(tx);
  const cur = (weight.result as any).current_weight;
  const thr = (weight.permission as any).threshold;
  console.log(`Signature weight: ${cur} / ${thr}`);

  if ((weight.result as any).ENOUGH_PERMISSION) {
    console.log('🎉 threshold reached – attempting to broadcast transaction!');
    try {
      const response = await tronGrid.trx.broadcast(tx);
      console.log('Broadcast response:', response);
      if (response.result) {
        console.log('✅ Transaction broadcast successful!');
      } else {
        console.log('⚠️  Broadcast failed, but transaction has enough signatures');
        await saveTransaction(tx, src);
      }
    } catch (err: any) {
      console.log('⚠️  Broadcast error:', err.message);
      await saveTransaction(tx, src);
    }
  } else {
    await saveTransaction(tx, src);
  }
})();
