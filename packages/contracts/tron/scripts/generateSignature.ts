// node.js + tronweb
const TronWeb = require('tronweb');
import dotenv from 'dotenv';
dotenv.config();

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});

async function generateSignature() {
  const { ethers } = require('ethers');
  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
  const fee = 0;
  const nativeFee = 0;
  const inputAsset = '0xa614f803b6fd780986a42c78ec9c7f77e6ded13c'; // USDT on Tron
  // Use your private key from .env or hardcode for testing
  const privateKey = process.env.TRON_KEY; // Make sure this is set in your .env

  // 1. Encode the payload
  const payload = ethers.utils.defaultAbiCoder.encode(
    ['uint256', 'uint256', 'address', 'uint256'],
    [fee, nativeFee, inputAsset, deadline],
  );

  // Logging the inputAsset and deadline
  console.log('----- Generating Signature with Ethers -----');
  console.log('Input Asset:', inputAsset);
  console.log('Deadline:', deadline);

  // 2. Hash the payload and get the digest
  const digest = ethers.utils.hashMessage(ethers.utils.arrayify(ethers.utils.keccak256(payload)));

  // 3. Sign the digest
  const wallet = new ethers.Wallet(privateKey);
  const signature = await wallet.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(payload)));

  // 4. Output - Ethers
  console.log('Payload:', payload);
  console.log('Digest:', digest);
  console.log('Signature:', signature);

  // Optionally, recover the address to verify
  const recovered = ethers.utils.recoverAddress(digest, signature);
  console.log('Recovered Ethers address:', recovered);

  console.log('--------------------------------');
  const base58Address = 'TPRnuwo64F7ndhEKhWByyPs7BgNMpzQwuP';
  const hexAddress = tronWeb.address.toHex(base58Address);
  console.log('Hex address:', hexAddress);

  console.log('--------------------------------');

  console.log('------- Generating Signature with TronWeb -------');
  // Logging the address linked to the TronWeb private key
  const tronAddress = tronWeb.address.fromPrivateKey(process.env.TRON_KEY);
  console.log('TronWeb address (base58):', tronAddress);
  console.log('TronWeb address (hex):', tronWeb.address.toHex(tronAddress));

  const payloadTronWeb = tronWeb.abi.encodeParams(
    ['uint256', 'uint256', 'address', 'uint256'],
    [fee, nativeFee, inputAsset, deadline],
  );

  // Logging the inputAsset and deadline
  console.log('----- Generating Signature with TronWeb -----');

  const digestTronWeb = tronWeb.utils.hashMessage(payloadTronWeb);
  const signatureTron = tronWeb.trx.signMessageV2(payloadTronWeb, process.env.TRON_KEY);

  // 4. Output - TronWeb
  console.log('Payload:', payloadTronWeb);
  console.log('Digest:', digestTronWeb);
  console.log('Signature:', signatureTron);

  // Optionally, recover the address to verify
  const recoveredTron = tronWeb.utils.recoverAddress(digestTronWeb, signatureTron);
  console.log('Recovered Tron address:', recoveredTron);
}

generateSignature();
