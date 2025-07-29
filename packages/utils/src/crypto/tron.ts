import { TronWeb } from 'tronweb';

export interface TronKeyPair {
  privateKey: string;
  publicKey: string;
  address: {
    hex: string;
    base58: string;
  };
}

export interface TronSignature {
  r: string;
  s: string;
  v: number;
  fullSig: string;
}

/**
 * Generate a new Tron key pair
 */
export async function generateTronKeyPair(): Promise<TronKeyPair> {
  const account = await TronWeb.createAccount();

  return {
    privateKey: account.privateKey,
    publicKey: account.publicKey,
    address: {
      hex: account.address.hex,
      base58: account.address.base58,
    },
  };
}

/**
 * Get Tron address from private key
 */
export function getAddressFromPrivateKey(privateKey: string): TronKeyPair['address'] {
  const base58Address = TronWeb.address.fromPrivateKey(privateKey);
  if (!base58Address) {
    throw new Error('Invalid private key');
  }
  const hexAddress = TronWeb.address.toHex(base58Address);

  return {
    hex: hexAddress,
    base58: base58Address,
  };
}

/**
 * Convert Ethereum address to Tron address format
 */
export function ethereumToTronAddress(ethAddress: string): string {
  if (!ethAddress.startsWith('0x')) {
    throw new Error('Invalid Ethereum address format');
  }
  
  const ethHex = ethAddress.slice(2); // Remove '0x'
  const tronHex = '41' + ethHex; // Add Tron prefix
  
  return TronWeb.address.fromHex(tronHex);
}

/**
 * Sign a transaction hash using Tron's signing scheme
 */
export async function signTransactionHash(privateKey: string, txHash: string): Promise<TronSignature> {
  const tronWeb = new TronWeb({
    fullHost: 'https://api.trongrid.io',
    privateKey: privateKey,
    headers: {
      'TRON-PRO-API-KEY': process.env.TRON_PRO_API_KEY || '',
    },
  });
  
  // Ensure txHash has 0x prefix for TronWeb
  const hashWithPrefix = txHash.startsWith('0x') ? txHash : `0x${txHash}`;
  
  // Use TronWeb's internal signing
  const signature = await tronWeb.trx.sign(hashWithPrefix);
  
  // Extract r, s, v from the signature
  const r = signature.slice(0, 64);
  const s = signature.slice(64, 128);
  const v = parseInt(signature.slice(128, 130), 16);
  
  return {
    r,
    s,
    v,
    fullSig: signature,
  };
}

/**
 * Sign a message using TIP-191 (Tron's equivalent to EIP-191)
 */
export async function signMessage(privateKey: string, message: string): Promise<string> {
  const tronWeb = new TronWeb({
    fullHost: 'https://api.trongrid.io',
    privateKey: privateKey,
    headers: {
      'TRON-PRO-API-KEY': process.env.TRON_PRO_API_KEY || '',
    },
  });
  
  return await tronWeb.trx.signMessageV2(message);
}

/**
 * Verify a TIP-191 signed message
 */
export async function verifyMessage(message: string, signature: string): Promise<string> {
  const tronWeb = new TronWeb({
    fullHost: 'https://api.trongrid.io',
    headers: {
      'TRON-PRO-API-KEY': process.env.TRON_PRO_API_KEY || '',
    },
  });
  
  return await tronWeb.trx.verifyMessageV2(message, signature);
}

/**
 * Create a TronWeb instance with private key
 */
export function createTronWeb(privateKey: string, fullHost: string = 'https://api.trongrid.io'): any {
  const tronWeb = new TronWeb({
    fullHost,
    privateKey,
    headers: {
      'TRON-PRO-API-KEY': 'b28bbd21-f962-4a02-94fe-57ef36f1d8d2',
    },
  });
  return tronWeb;
} 