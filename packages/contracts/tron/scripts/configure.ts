// Run command: yarn ts-node --files --project tsconfig.json tron/scripts/configure.ts
const TronWeb = require('tronweb');
import dotenv from 'dotenv';
dotenv.config();
import { fetchAddresses } from './constants';

// The JSON artifacts produced by TronBox or another compiler
import EverclearSpokeArtifact from '../build/contracts/EverclearSpoke.json';
import FeeAdapterArtifact from '../build/contracts/FeeAdapter.json';
import SpokeGatewayArtifact from '../build/contracts/SpokeGateway.json';

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});
``
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

async function updateMessageReceiver(newAddress: string, spokeAddress: string): Promise<void> {
  // Updating the Message Receiver address //
  const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, spokeAddress);
  let messageReceiverAddress = await spokeInstance.messageReceiver().call();
  console.log('Message Receiver of the Spoke:', messageReceiverAddress);
  spokeInstance.updateMessageReceiver(newAddress).send({ feeLimit: 1_000_000_000, callValue: 0 });
  messageReceiverAddress = await spokeInstance.messageReceiver().call();
  console.log('Updated Message Receiver of the Spoke:', messageReceiverAddress);
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

async function updateFeeSigner(newAddress: string, feeAdapter: string): Promise<void> {
  // Updating the Fee Signer address //
  const feeAdapterInstance = await tronWeb.contract(FeeAdapterArtifact.abi, feeAdapter);
  let feeSignerAddress = await feeAdapterInstance.feeSigner().call();
  console.log('Fee Signer of the Spoke:', feeSignerAddress);
  feeAdapterInstance.updateFeeSigner(newAddress).send({ feeLimit: 1_000_000_000, callValue: 0 });
  feeSignerAddress = await feeAdapterInstance.feeSigner().call();
  console.log('Updated Fee Signer of the Spoke:', feeSignerAddress);
}

async function updateSpokeOwner(newOwner: string, spokeAddress: string): Promise<void> {
  // Updating the Spoke owner //
  const spokeInstance = await tronWeb.contract(EverclearSpokeArtifact.abi, spokeAddress);
  let spokeOwner = await spokeInstance.owner().call();
  console.log('Owner of the Spoke:', spokeOwner);
  spokeInstance.transferOwnership(newOwner).send({ feeLimit: 1_000_000_000, callValue: 0 });
  spokeOwner = await spokeInstance.owner().call();
  console.log('Updated Owner of the Spoke:', spokeOwner);
}

async function updateGatewayOwner(newOwner: string, gatewayAddress: string): Promise<void> {
  // Updating the Gateway owner //
  const gatewayInstance = await tronWeb.contract(SpokeGatewayArtifact.abi, gatewayAddress);
  let gatewayOwner = await gatewayInstance.owner().call();
  console.log('Owner of the Gateway:', gatewayOwner);
  gatewayInstance.transferOwnership(newOwner).send({ feeLimit: 1_000_000_000, callValue: 0 });
  gatewayOwner = await gatewayInstance.owner().call();
  console.log('Updated Owner of the Gateway:', gatewayOwner);
}

async function sendIntent(feeAdapterAddress: string): Promise<void> {
  // Sending an intent to the Spoke //
  const feeAdapterInstance = await tronWeb.contract(FeeAdapterArtifact.abi, feeAdapterAddress);

  // Inputs
  const destinations = [8453]; // Use plain number
  const receiver = '41ade09131c6f43fe22c2cbabb759636c43cfc181e';
  const inputAsset = '41a614f803b6fd780986a42c78ec9c7f77e6ded13c';
  const outputAsset = '41fde4c96c8593536e31f229ea8f37b2ada2699bb2';
  const amount = 99930;
  const fee = 0;
  const ttl = 0;
  const data = '0x';
  const feeParams = [
    1120, // fee
    1753884060, // deadline
    '0xc5f1bfd71fc1c532cbe74a9d55185169ddbb5e0419b9e20b7435617d2eaa731475babfc1d29e3b4adb31736c278db1ce42e8a337ec77e30adb7e9a7e70a037541b', // signature
  ];

  // Working implementation //
  // Pass arguments as separate parameters, not as a single array
  const tx = await feeAdapterInstance.methods[
    'newIntent(uint32[],address,address,address,uint256,uint24,uint48,bytes,(uint256,uint256,bytes))'
  ](destinations, receiver, inputAsset, outputAsset, amount, fee, ttl, data, feeParams).send({
    feeLimit: 1_000_000_000,
    callValue: 0,
  });
  console.log('Intent sent to the Spoke', tx);
}

(async () => {
  try {
    // Configuring prod or staging address //
    const configureProd = true;
    const { spokeAddress, gatewayAddress, feeAdapter } = fetchAddresses(configureProd);

    // Actions to execute//
    const shouldUpdateGateway = false;
    const newGatewayAddress = '';

    const shouldUpdateIsM = false;
    const newISMAddress = '';

    const shouldUpdateMailbox = false;
    const newMailboxAddress = '';

    const shouldUpdateFeeSigner = false;
    const newFeeSignerAddress = 'TPRnuwo64F7ndhEKhWByyPs7BgNMpzQwuP';

    const shouldUpdateMessageReceiver = false;
    const newMessageReceiverAddress = 'TYJPGb4PZUgD342nThx4YsTomqJbShVnKz';

    const shouldSendIntent = false;

    const shouldUpdateSpokeOwner = true;
    const newOwnerAddress = 'TCx6QEfz24VYDTcwzyoEzhRe6a3YTAPmSp';

    const shouldUpdateGatewayOwner = true;
    const newGatewayOwnerAddress = 'TCx6QEfz24VYDTcwzyoEzhRe6a3YTAPmSp';

    // Logic //
    if (shouldUpdateGateway) await updateGateway(newGatewayAddress, spokeAddress);
    if (shouldUpdateIsM) await updateIsM(newISMAddress, spokeAddress, gatewayAddress);
    if (shouldUpdateMessageReceiver) await updateMessageReceiver(newMessageReceiverAddress, spokeAddress);
    if (shouldUpdateMailbox) await updateMailbox(newMailboxAddress, spokeAddress, gatewayAddress);
    if (shouldUpdateFeeSigner) await updateFeeSigner(newFeeSignerAddress, feeAdapter);
    if (shouldSendIntent) await sendIntent(feeAdapter);
    if (shouldUpdateSpokeOwner) await updateSpokeOwner(newOwnerAddress, spokeAddress);
    if (shouldUpdateGatewayOwner) await updateGatewayOwner(newGatewayOwnerAddress, gatewayAddress);

    console.log('DONE!');
  } catch (err) {
    console.error(err);
  }
})();
