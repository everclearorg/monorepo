// Run command: yarn ts-node --files --project tsconfig.json tron/deploy/configure.ts
const TronWeb = require('tronweb');
import dotenv from 'dotenv';
dotenv.config();

// The JSON artifacts produced by TronBox or another compiler
import EverclearSpokeArtifact from '../build/contracts/EverclearSpoke.json';

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});

const EVERCLEAR_SPOKE = '419b266df36c882a73d45b18876104d5728424828f';
// const EVERCLEAR_SPOKE_GATEWAY_IMPL = '417039676630aba9606afa13bfb4b822d67c05282a'; // TLCbT376siRg4PvzGBXYq4a1xafWJyzM5n || 417039676630aba9606afa13bfb4b822d67c05282a
const EVERCLEAR_SPOKE_GATEWAY_PROXY = '4154ea655e20e515c85143dab8a6baae0b11d137a6';
const POLYMER_ISM = '41cbcbc532cf88bacf1c8a6359604c784d042bb692';
const POLYMER_MAILBOX = '415b34081e9d453fc2ba925d893583d89d1b7175dd';

async function updateGateway(newAddress: string): Promise<void> {
  // Updating the Spoke gateway address //
  const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, EVERCLEAR_SPOKE);
  let spokeGateway = await spokeInstance.gateway().call();
  console.log('Gateway of the Spoke:', spokeGateway);
  spokeInstance.updateGateway(newAddress).send({ feeLimit: 1_000_000_000, callValue: 0 });
  spokeGateway = await spokeInstance.gateway().call();
  console.log('Updated Gateway of the Spoke:', spokeGateway);
}

async function updateIsM(newAddress: string): Promise<void> {
  // Updating the ISM address //
  const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, EVERCLEAR_SPOKE);
  const gatewayInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, EVERCLEAR_SPOKE_GATEWAY_PROXY);

  let ismAddress = await gatewayInstance.interchainSecurityModule().call();
  console.log('ISM of the Spoke:', ismAddress);
  spokeInstance.updateSecurityModule(newAddress).send({ feeLimit: 1_000_000_000, callValue: 0 });
  ismAddress = await gatewayInstance.interchainSecurityModule().call();
  console.log('Updated ISM of the Spoke:', ismAddress);
}

async function updateMailbox(newAddress: string): Promise<void> {
  // Updating the Mailbox address //
  const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, EVERCLEAR_SPOKE);
  const gatewayInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, EVERCLEAR_SPOKE_GATEWAY_PROXY);
  let mailboxAddress = await gatewayInstance.mailbox().call();
  console.log('Mailbox of the Spoke:', mailboxAddress);
  spokeInstance.updateMailbox(newAddress).send({ feeLimit: 1_000_000_000, callValue: 0 });
  mailboxAddress = await gatewayInstance.mailbox().call();
  console.log('Updated Mailbox of the Spoke:', mailboxAddress);
}

(async () => {
  try {
    // Actions to execute//
    const shouldUpdateGateway = true;
    const newGatewayAddress = EVERCLEAR_SPOKE_GATEWAY_PROXY;

    const shouldUpdateIsM = false;
    const newISMAddress = POLYMER_ISM;

    const shouldUpdateMailbox = false;
    const newMailboxAddress = POLYMER_MAILBOX;

    // Logic //
    if (shouldUpdateGateway) await updateGateway(newGatewayAddress);
    if (shouldUpdateIsM) await updateIsM(newISMAddress);
    if (shouldUpdateMailbox) await updateMailbox(newMailboxAddress);

    console.log('DONE!');
  } catch (err) {
    console.error(err);
  }
})();