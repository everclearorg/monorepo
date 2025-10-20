// save as recover-tron-signer.ts
import { createHash } from 'crypto';
import * as secp256k1 from 'secp256k1';
import { keccak_256 } from 'js-sha3';
// @ts-ignore
import bs58check from 'bs58check';

// Paste your values here:
const raw_data_hex = '0a02608722087ae626f19d02e8ff40d8df8f839c335a8e01081f1289010a31747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e54726967676572536d617274436f6e747261637412540a154120b273a03d0296706729ae2f9fbfcf773d485d7b1215419b266df36c882a73d45b18876104d5728424828f22240144a6610000000000000000000000003104e840ef2a18abe54b1d3514ddfe989c0a89f670f9d9f2d99b339001c096b102';
const sigHex = 'd81c08be8df4bb58cef9ad54046350dc2f9d7647d0e73025ee95876e8bb9cf256177a7f303db051eedc2159ca8f1ff5da661b09a7c4005812ea9b1d1cf38c18f01';

// 1) Hash raw_data -> txID hash
const raw = Buffer.from(raw_data_hex, 'hex');
const hash = createHash('sha256').update(raw).digest();

// 2) Split signature (r,s,v). Tron Ledger returns 65 bytes, v in {0,1,27,28}
const sig = Buffer.from(sigHex.replace(/^0x/, ''), 'hex');
const r = sig.slice(0, 32);
const s = sig.slice(32, 64);
let v = sig[64];
if (v >= 27) v -= 27; // normalize to 0/1

// 3) Recover uncompressed pubkey (65 bytes)
// Create the signature in the format expected by secp256k1 (r + s)
const signature = Buffer.concat([r, s]);
const recovered = secp256k1.ecdsaRecover(signature, v, hash, false); // false => uncompressed
const pubkey = recovered.slice(1); // drop 0x04

// 4) Derive Tron address: keccak(pubkey)[12..] with 0x41 prefix, Base58Check
const addr20 = Buffer.from(keccak_256.arrayBuffer(pubkey)).slice(-20);
const tronPayload = Buffer.concat([Buffer.from([0x41]), addr20]);
const tronBase58 = bs58check.encode(tronPayload);

console.log('Signer Tron address:', tronBase58);
