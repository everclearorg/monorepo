// Run command: yarn ts-node --files --project tsconfig.json tron/scripts/debugSignature.ts
const TronWeb = require('tronweb');
import dotenv from 'dotenv';
dotenv.config();

import FeeAdapterArtifact from '../build/contracts/FeeAdapter.json';
const FEE_ADAPTER_ADDRESS = 'TX6HShGoFuR3R5ZXqA6aNieKseW3SfWMkC';

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});

async function debugSigner() {
  /// Validating the signature //
  const feeAdapterInstance = await tronWeb.contract(FeeAdapterArtifact.abi, FEE_ADAPTER_ADDRESS);
  // 1. Verify what is stored (returns WITH 41, that's fine)
  console.log(await feeAdapterInstance.feeSigner().call());
  //  -> 0x4110f9e750b4d8877f39f47d32fd38dc8c9d1d1e16

  // 2. Verify that the signature really recovers the 20‑byte signer
  const { ethers } = require('ethers');
  const rsvSig =
    '0x705fee6e0c92f2bc15ad85638382ccb9564c4da240c134a06f3738fbb6450be27d69df73d03f8979bbe2a5541587f4d43e901b665b3696e1ce60e82005597ab61b';

  // v5 keeps the coder in `utils`
  const payload = ethers.utils.defaultAbiCoder.encode(
    ['uint256', 'uint256', 'address', 'uint256'],
    [70, 0, '0xa614f803b6fd780986a42c78ec9c7f77e6ded13c', 1753885329],
  );

  const digest = ethers.utils.hashMessage(ethers.utils.arrayify(ethers.utils.keccak256(payload)));

  console.log(digest);
  console.log(ethers.utils.recoverAddress(digest, rsvSig));
}

debugSigner();