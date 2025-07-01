// Run command: yarn ts-node --files --project tsconfig.json tron/deploy/read.ts
const TronWeb = require('tronweb');
import dotenv from 'dotenv';
dotenv.config();

// The JSON artifacts produced by TronBox or another compiler
import EverclearSpokeArtifact from '../build/contracts/EverclearSpoke.json';
import SpokeGatewayArtifact from '../build/contracts/SpokeGateway.json';

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});

const EVERCLEAR_SPOKE = '419b266df36c882a73d45b18876104d5728424828f';
// const EVERCLEAR_SPOKE_GATEWAY_IMPL = '417039676630aba9606afa13bfb4b822d67c05282a'; // TLCbT376siRg4PvzGBXYq4a1xafWJyzM5n || 417039676630aba9606afa13bfb4b822d67c05282a
const EVERCLEAR_SPOKE_GATEWAY = '4154ea655e20e515c85143dab8a6baae0b11d137a6';

(async () => {
  try {
    console.log('Logging the state of the deployed contracts...');

    // Construct spoke (proxy) state
    const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, EVERCLEAR_SPOKE);

    // Construct gateway (proxy) state 
    const gatewayInstance = await tronWeb.contract(SpokeGatewayArtifact.abi, EVERCLEAR_SPOKE_GATEWAY);

    // Reading the Spoke instance state //
    const spokeOwner = await spokeInstance.owner().call();
    console.log('Owner of the Spoke:', spokeOwner);

    const spokeGateway = await spokeInstance.gateway().call();
    console.log('Gateway address:', spokeGateway);

    // Reading the gateway instance state // 
    // Get the owner of the contract
    const gatewayOwner = await gatewayInstance.owner().call();
    console.log('Owner of the Spoke Gateway:', gatewayOwner);

    // Get the mailbox address
    const mailbox = await gatewayInstance.mailbox().call();
    console.log('Mailbox address:', mailbox);

    // Getting the ism address
    const ismAddress = await gatewayInstance.interchainSecurityModule().call();
    console.log('ISM address:', ismAddress);

    // Get the receiver address
    const receiver = await gatewayInstance.receiver().call();
    console.log('Receiver address:', receiver);

    console.log('DONE!');
  } catch (err) {
    console.error(err);
  }
})();