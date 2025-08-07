// yarn ts-node tron/scripts/signTxMultisig.ts  tron/pendingTransactions/tx.json

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
  if (source.endsWith('.txt')) {
    const [id, b64] = (await fs.readFile(source, 'utf8')).trim().split('\n');
    return JSON.parse(Buffer.from(b64, 'base64').toString());
  }
  if (source.endsWith('.json')) return JSON.parse(await fs.readFile(source, 'utf8'));

  // assume it's a txID
  const tx = await tronGrid.trx.getTransaction(source);
  if (!tx) throw new Error('txID not found on TronGrid');
  return tx;
}

(async () => {
  const src = process.argv[2];
  if (!src) throw new Error('Usage: add-signature.ts <txID | tx.json | txtoken.txt>');

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

  // Setting up ledger
  const paths = await TransportNodeHid.list();
  const transport = await TransportNodeHid.open(paths[0]);
  const ledger = new Trx(transport);

  // Logging 
  console.log(`Using Ledger at path: ${paths[0]}`);
  console.log('Transport:', transport);
  console.log('Ledger App:', ledger);

  const sig = await ledger.signTransaction(LEDGER_PATH, tx.raw_data_hex, []);

  if (tx.signature?.includes(sig)) {
    console.log('⚠️  This key has already signed.  Exiting.');
    return;
  }
  tx.signature = [...(tx.signature || []), sig];

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
        await fs.writeFile('tron/pendingTransactions/tx.json', JSON.stringify(tx, null, 2));
        console.log('tx.json written – transaction ready for manual broadcast');
      }
    } catch (err: any) {
      console.log('⚠️  Broadcast error:', err.message);
      await fs.writeFile('tron/pendingTransactions/tx.json', JSON.stringify(tx, null, 2));
      console.log('tx.json written – transaction ready for manual broadcast');
    }
  } else {
    await fs.writeFile('tron/pendingTransactions/tx.json', JSON.stringify(tx, null, 2));
    console.log('tx.json written – send it to the next co‑signer.');
  }
})();
