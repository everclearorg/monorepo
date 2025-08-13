// Run with: yarn ts-node --files --project tsconfig.json tron/scripts/proposeTxMultisig.ts
const TronWeb = require('tronweb');
import TransportNodeHid from '@ledgerhq/hw-transport-node-hid';
import Trx from '@ledgerhq/hw-app-trx';
import fs from "fs/promises";

import dotenv from 'dotenv';
import { FEE_ADAPTER_PROD, SPOKE_PROD, SPOKE_STAGING } from './constants';
dotenv.config();

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});
const LEDGER_PATH = "44'/195'/0'/0/0";
const MULTI_SIG_ADDRESS = 'TCx6QEfz24VYDTcwzyoEzhRe6a3YTAPmSp';

const tronGrid = new TronWeb.TronWeb({
  fullHost: 'https://api.trongrid.io', // same cluster used by TronScan
  headers: { 'TRON-PRO-API-KEY': process.env.TRONGRID_API_KEY }, // free key in TronGrid dashboard
});

(async () => {
  // 1. build
  const contract = SPOKE_PROD;
  const multiSigHex = tronWeb.address.toHex(MULTI_SIG_ADDRESS); // convert Base58 → hex
  const transactionName = 'updateFeeAdapterProd'

  const { transaction: tx0 } = await tronWeb.transactionBuilder.triggerSmartContract(
    contract,
    'updateFeeAdapter(address)',
    { permissionId: 0, feeLimit: 5_000_000 },
    [{ type: 'address', value: FEE_ADAPTER_PROD }, { type: 'bytes', value: '0x' }],
    multiSigHex,
  );
  const tx = await tronWeb.transactionBuilder.extendExpiration(tx0, 86400); // extend expiration by 24 hours

  // 2. sign on Ledger
  const paths = await TransportNodeHid.list();
  const transport = await TransportNodeHid.open(paths[0]);
  const ledger = new Trx(transport);

  console.log(`Using Ledger at path: ${paths[0]}`);
  console.log('Transport:', transport);
  console.log('Ledger App:', ledger);

  // Sense checking
  const cfg = await ledger.getAppConfiguration();
  console.log(`Ledger TRON app ${cfg.version}, blind signing must be enabled`);
  if (!tx.raw_data_hex) throw new Error('tx.raw_data_hex is empty – did you pick tx.transaction?');

  // Sign the transaction
  console.log('Signing transaction with Ledger...');
  console.log('Transaction:', tx);
  console.log('Transaction ID:', tx.txID);
  console.log('Raw Data Hex:', tx.raw_data_hex);
  const sig = await ledger.signTransaction(LEDGER_PATH, tx.raw_data_hex, []);
  tx.signature = [sig];

  // 3. publish; ignore SIGERROR
  const response = await tronWeb.trx.broadcast(tx);
  console.log('Response:', response);

  console.log(`Partially‑signed tx pushed: ${tx.txID}`);
  
  // Writing tx
  await fs.writeFile(
    `tron/pendingTransactions/${transactionName}.json`,
    JSON.stringify(tx, null, 2)
  );
  console.log('\nArtifacts written:');
  console.log(`  • pendingTransactions/${transactionName}.json         – full JSON for offline signers`);

  // Reviewing if the transaction is pending
  try {
    const pending = await tronGrid.trx.getTransaction(tx.txID);
    if (pending.ret && pending.ret[0].contractRet === 'SUCCESS') {
      console.log('Transaction is pending and successful:', pending);
    } else {
      console.log('Transaction is pending but not successful:', pending);
    }
  } catch (err: any) {
    console.log('Error checking transaction status:', err.message);
    const rebroadcastTx = await tronGrid.trx.broadcast(tx); // still returns SIGERROR, that’s fine
    console.log('Rebroadcasted transaction:', rebroadcastTx);
    return;
  }
})();
