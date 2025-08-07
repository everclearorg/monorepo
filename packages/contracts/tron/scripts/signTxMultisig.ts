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
    console.log('🎉 threshold reached – transaction will execute next block!');
  } else {
    await fs.writeFile('tron/pendingTransactions/tx.json', JSON.stringify(tx, null, 2));
    console.log('tx.json written – send it to the next co‑signer.');
  }
})();
