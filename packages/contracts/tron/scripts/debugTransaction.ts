// Run command: yarn ts-node --files --project tsconfig.json tron/scripts/debugTransaction.ts
const TronWeb = require('tronweb');
import dotenv from 'dotenv';
dotenv.config();

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});

async function debug(txId: string) {
  /// Logging the transaction //
  const tx = await tronWeb.trx.getTransaction(txId);
  const info = await tronWeb.trx.getTransactionInfo(txId);
  console.log('Transaction:', tx);
  console.log('Transaction Info:', info);

  if (!info) {
    console.error('No transaction info found for ID:', txId);
    return;
  }

  if (info.log && Array.isArray(info.log)) {
    info.log.forEach((log: any) => {
      console.log('Log:', log);
      // You may need to adjust how you decode logs here
      // console.log('Decoded Log:', tronWeb.utils.abi.decodeLog(log));
    });
  } else {
    console.log('No logs found in transaction info.');
  }

  if (info.receipt.result !== 'SUCCESS') {
    const contractAddress = tx.raw_data.contract[0].parameter.value.contract_address;
    const ownerAddress = tx.raw_data.contract[0].parameter.value.owner_address;
    const data = tx.raw_data_hex;
    const callValue = tx.raw_data.contract[0].parameter.value.call_value || 0;

    const params = {
      owner_address: ownerAddress,
      contract_address: contractAddress,
      function_selector: '1a8f139f', // leave blank when you send full data
      parameter: data,
      fee_limit: 1_000_000_000,
      call_value: callValue,
    };

    const ext = await tronWeb.fullNode.request('wallet/gettransactioninfobyid', params, 'post');
    console.log(JSON.stringify(ext, null, 2));
  }
}

debug('0bd568acd9b697a50a11ec16a1a231542877bf551632163d9cfc61b40e7f6e22');
