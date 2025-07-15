// Run command: yarn ts-node --files --project tsconfig.json tron/deploy/configure.ts
const TronWeb = require('tronweb');
import dotenv from 'dotenv';
dotenv.config();
import { fetchAddresses } from './constants';

// The JSON artifacts produced by TronBox or another compiler
import EverclearSpokeArtifact from '../build/contracts/EverclearSpoke.json';

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});

async function updateGateway(newAddress: string, spokeAddress: string): Promise<void> {
  // Updating the Spoke gateway address //
  console.log(`Updating the Spoke gateway address to: ${newAddress}`);
  const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, spokeAddress);
  let spokeGateway = await spokeInstance.gateway().call();
  console.log('Gateway of the Spoke:', spokeGateway);
  spokeInstance.updateGateway(newAddress).send({ feeLimit: 1_000_000_000, callValue: 0 });
  spokeGateway = await spokeInstance.gateway().call();
  console.log('Updated Gateway of the Spoke:', spokeGateway);
}

async function updateIsM(newAddress: string, spokeAddress: string, gatewayAddress: string): Promise<void> {
  // Updating the ISM address //
  const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, spokeAddress);
  const gatewayInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, gatewayAddress);

  let ismAddress = await gatewayInstance.interchainSecurityModule().call();
  console.log('ISM of the Spoke:', ismAddress);
  spokeInstance.updateSecurityModule(newAddress).send({ feeLimit: 1_000_000_000, callValue: 0 });
  ismAddress = await gatewayInstance.interchainSecurityModule().call();
  console.log('Updated ISM of the Spoke:', ismAddress);
}

async function updateMailbox(newAddress: string, spokeAddress: string, gatewayAddress: string): Promise<void> {
  // Updating the Mailbox address //
  const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, spokeAddress);
  const gatewayInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, gatewayAddress);
  let mailboxAddress = await gatewayInstance.mailbox().call();
  console.log('Mailbox of the Spoke:', mailboxAddress);
  spokeInstance.updateMailbox(newAddress).send({ feeLimit: 1_000_000_000, callValue: 0 });
  mailboxAddress = await gatewayInstance.mailbox().call();
  console.log('Updated Mailbox of the Spoke:', mailboxAddress);
}

(async () => {
  try {
    // Configuring prod or staging address //
    const configureProd = false;
    const { spokeAddress, gatewayAddress } = fetchAddresses(configureProd);

    // Actions to execute//
    const shouldUpdateGateway = true;
    const newGatewayAddress = '';

    const shouldUpdateIsM = false;
    const newISMAddress = '';

    const shouldUpdateMailbox = false;
    const newMailboxAddress = '';

    // Logic //
    if (shouldUpdateGateway) await updateGateway(newGatewayAddress, spokeAddress);
    if (shouldUpdateIsM) await updateIsM(newISMAddress, spokeAddress, gatewayAddress);
    if (shouldUpdateMailbox) await updateMailbox(newMailboxAddress, spokeAddress, gatewayAddress);

    console.log('DONE!');
  } catch (err) {
    console.error(err);
  }
})();
