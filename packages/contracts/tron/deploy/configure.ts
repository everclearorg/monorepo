// Run command: yarn ts-node --files --project tsconfig.json tron/deploy/read.ts
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
const EVERCLEAR_SPOKE_GATEWAY_PROXY = '41a35c21eb3b0a2211998fc407eb0bc6912baf6522';

async function updateGateway(newAddress: string): Promise<void> {
  // Updating the Spoke gateway address //
  const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, EVERCLEAR_SPOKE);
  let spokeGateway = await spokeInstance.gateway().call();
  console.log('Gateway of the Spoke:', spokeGateway);
  spokeInstance.updateGateway(newAddress).send({ feeLimit: 1_000_000_000, callValue: 0 });
  spokeGateway = await spokeInstance.gateway().call();
  console.log('Updated Gateway of the Spoke:', spokeGateway);
}

(async () => {
  try {
    // Actions to execute//
    const shouldUpdateGateway = true;
    const newGatewayAddress = EVERCLEAR_SPOKE_GATEWAY_PROXY;

    // Logic //
    if (shouldUpdateGateway) await updateGateway(newGatewayAddress);

    console.log('DONE!');
  } catch (err) {
    console.error(err);
  }
})();