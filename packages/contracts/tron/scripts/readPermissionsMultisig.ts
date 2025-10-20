// Run with: yarn ts-node --files --project tsconfig.json tron/scripts/readPermissionMultisig.ts
import axios from 'axios';

async function readMultisig(address: string) {
  try {
    const response = await axios.post('https://api.trongrid.io/wallet/getaccount', {
      address,
      visible: true,
    }, {
      headers: { 'Content-Type': 'text/plain' },
    });
    const data = response.data;
    if (!data) {
      console.error('No data returned for address:', address);
      return;
    }
    console.log('Account:', address);
    if (data.owner_permission) {
      console.log('Owner Permission:');
      console.log('  Name:', data.owner_permission.permission_name);
      console.log('  Threshold:', data.owner_permission.threshold);
      data.owner_permission.keys.forEach((key: any, i: number) => {
        console.log(`    Key ${i + 1}: ${key.address} (weight: ${key.weight})`);
      });
    }
    console.log(data);
    if (data.active_permission && Array.isArray(data.active_permission)) {
      data.active_permission.forEach((perm: any, idx: number) => {
        console.log(`Active Permission #${idx + 1}:`);
        console.log('  Name:', perm.permission_name);
        console.log('  Threshold:', perm.threshold);
        if (perm.keys) {
          perm.keys.forEach((key: any, i: number) => {
            console.log(`    Key ${i + 1}: ${key.address} (weight: ${key.weight})`);
          });
        }
      });
    }
  } catch (err: any) {
    if (err.response && err.response.data) {
      console.error('Error:', err.response.data);
    } else {
      console.error('Error:', err.message);
    }
  }
}

// Usage: ts-node readMultisig.ts <base58address>
const args = process.argv.slice(2);
if (args.length < 1) {
  console.error('Usage: ts-node readMultisig.ts <base58address>');
  process.exit(1);
}
readMultisig(args[0]);
