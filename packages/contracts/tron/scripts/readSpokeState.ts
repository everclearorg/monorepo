// Run command: yarn ts-node --files --project tsconfig.json tron/scripts/readSpokeState.ts
const TronWeb = require('tronweb');
import dotenv from 'dotenv';
dotenv.config();
import { fetchAddresses } from './constants';

// The JSON artifacts produced by TronBox or another compiler
import EverclearSpokeV5Artifact from '../build/contracts/EverclearSpokeV5.json';
import SpokeGatewayArtifact from '../build/contracts/SpokeGateway.json';
import XERC20ModuleArtifact from '../build/contracts/XERC20Module.json';
import FeeAdapterArtifact from '../build/contracts/FeeAdapter.json';

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});

(async () => {
  try {
    const logProd = false;
    const { spokeAddress, gatewayAddress, xerc20Module, feeAdapter } = fetchAddresses(logProd);
    console.log(`Logging the state of the deployed contracts ${logProd ? 'on Production' : 'on Staging'}`);

    // Construct spoke (proxy) state
    const spokeInstance = await tronWeb.contract(EverclearSpokeV5Artifact.abi, spokeAddress);
    console.log('-- Spoke address:', tronWeb.address.fromHex(spokeInstance.address));

    // Construct gateway (proxy) state
    const gatewayInstance = await tronWeb.contract(SpokeGatewayArtifact.abi, gatewayAddress);
    console.log('-- Gateway address:', tronWeb.address.fromHex(gatewayInstance.address));

    // XERC20 module //
    const xerc20Instance = await tronWeb.contract(XERC20ModuleArtifact.abi, xerc20Module);
    console.log('XERC20 module address:', tronWeb.address.fromHex(xerc20Instance.address));

    // Fee adapter //
    const feeAdapterInstance = await tronWeb.contract(FeeAdapterArtifact.abi, feeAdapter);
    console.log('Fee Adapter address:', tronWeb.address.fromHex(feeAdapterInstance.address));

    // Reading the Spoke instance state //
    const spokeOwner = await spokeInstance.owner().call();
    console.log('Owner of the Spoke:', tronWeb.address.fromHex(spokeOwner));

    const spokeGateway = await spokeInstance.gateway().call();
    console.log('Gateway address:', tronWeb.address.fromHex(spokeGateway));

    // Reading the messageReceiver and callExecutor //
    const messageReceiver = await spokeInstance.messageReceiver().call();
    console.log('Message Receiver address:', tronWeb.address.fromHex(messageReceiver));

    const callExecutor = await spokeInstance.callExecutor().call();
    console.log('Call Executor address:', tronWeb.address.fromHex(callExecutor));

    // Reading the spoke FeeAdapter //
    const spokeFeeAdapter = await spokeInstance.feeAdapter().call();
    console.log('Spoke Fee Adapter address:', tronWeb.address.fromHex(spokeFeeAdapter));

    // Reading the gateway instance state //
    // Get the owner of the contract
    const gatewayOwner = await gatewayInstance.owner().call();
    console.log('Owner of the Spoke Gateway:', tronWeb.address.fromHex(gatewayOwner));

    // Get the mailbox address
    const mailbox = await gatewayInstance.mailbox().call();
    console.log('Mailbox address:', tronWeb.address.fromHex(mailbox));

    // Getting the ism address
    const ismAddress = await gatewayInstance.interchainSecurityModule().call();
    console.log('ISM address:', tronWeb.address.fromHex(ismAddress));

    // Get the receiver address
    const receiver = await gatewayInstance.receiver().call();
    console.log('Receiver address:', tronWeb.address.fromHex(receiver));

    // Hub gateway //
    const hubGateway = await gatewayInstance.EVERCLEAR_GATEWAY().call();
    console.log('Hub Gateway address:', tronWeb.address.fromHex(hubGateway));

    // Reading XERC20 module state //
    const xerc20ModuleSpoke = await xerc20Instance.spoke().call();
    console.log('XERC20 module spoke address:', tronWeb.address.fromHex(xerc20ModuleSpoke));

    // Reading Fee Adapter state //
    const feeAdapterSpoke = await feeAdapterInstance.spoke().call();
    console.log('Fee Adapter spoke address:', tronWeb.address.fromHex(feeAdapterSpoke));

    const feeAdapterOwner = await feeAdapterInstance.owner().call();
    console.log('Fee Adapter owner address:', tronWeb.address.fromHex(feeAdapterOwner));

    const feeAdapterXerc20Module = await feeAdapterInstance.xerc20Module().call();
    console.log('Fee Adapter XERC20 Module address:', tronWeb.address.fromHex(feeAdapterXerc20Module));

    const feeAdapterFeeSigner = await feeAdapterInstance.feeSigner().call();
    console.log('Fee Adapter Fee Signer address:', tronWeb.address.fromHex(feeAdapterFeeSigner));

    const feeAdapterFeeReceipient = await feeAdapterInstance.feeRecipient().call();
    console.log('Fee Adapter Fee Recipient address:', tronWeb.address.fromHex(feeAdapterFeeReceipient));

    console.log('DONE!');
  } catch (err) {
    console.error(err);
  }
})();
