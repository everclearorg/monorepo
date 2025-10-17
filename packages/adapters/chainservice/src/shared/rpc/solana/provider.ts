/* eslint-disable @typescript-eslint/no-explicit-any */
import { MAX_CONFIRMATION, RpcProvider } from '..';
import {
  IBlock,
  ISigner,
  ISignerApi,
  ITransactionReceipt,
  ITransactionRequest,
  ITransactionResponse,
  ReadTransaction,
  WriteTransaction,
} from '../../types';
import { appendTransactionMessageInstruction, createKeyPairSignerFromPrivateKeyBytes, createSolanaRpc, createSolanaRpcSubscriptions, createTransactionMessage, lamports, KeyPairSigner, pipe, Rpc, RpcSubscriptions, sendAndConfirmTransactionFactory, SendTransactionApi, setTransactionMessageFeePayer, SolanaRpcApiMainnet, SolanaRpcSubscriptionsApi, signTransactionMessageWithSigners, getSignatureFromTransaction, createSignableMessage, setTransactionMessageLifetimeUsingBlockhash, Address, address, signAndSendTransactionMessageWithSigners, getTransactionDecoder, TransactionMessage, FullySignedTransaction, signTransaction, assertIsTransactionMessageWithBlockhashLifetime, Transaction, compileTransaction, Base64EncodedWireTransaction, Signature, getAddressEncoder, getProgramDerivedAddress, getBase64EncodedWireTransaction } from '@solana/kit';
import { getTransferSolInstruction } from '@solana-program/system';

// In Solana, system program address is nomrally used as a zero address
const SOLANA_NATIVE_ASSET_ID = '11111111111111111111111111111111';

const TOKEN_PROGRAM_ID = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';

const SPL_ASSOCIATED_TOKEN_ACCOUNT_PROGRAM_ID = 'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL';

// Assume a big enough number of confirmations and treat it as final.
const SOLANA_MAX_CONFIRMATIONS = 1000;

class SolanaWeb3Signer implements ISigner {
  constructor(
    private readonly rpc: Rpc<SolanaRpcApiMainnet>,
    private readonly rpcSubscriptions: RpcSubscriptions<SolanaRpcSubscriptionsApi>,
    private readonly signer: KeyPairSigner,
    private readonly api?: ISignerApi,
  ) { }

  public get signerApi(): ISignerApi | undefined {
    return this.api;
  }

  public async getAddress(): Promise<string> {
    return this.signer.address;
  }

  public async sendTransaction(transaction: ITransactionRequest): Promise<ITransactionResponse> {
    let tx: Transaction;

    const { value: latestBlockhash } = await this.rpc.getLatestBlockhash().send();

    const sendAndConfirmTransaction = sendAndConfirmTransactionFactory({ rpc: this.rpc, rpcSubscriptions: this.rpcSubscriptions });

    if (!transaction.data || transaction.data === '0x' || transaction.data.length === 0) {
      // Native SOL transfer
      const unsignedTx = pipe(
        createTransactionMessage({ version: 0 }),
        tx => setTransactionMessageFeePayer(this.signer.address, tx),
        tx => setTransactionMessageLifetimeUsingBlockhash(latestBlockhash, tx),
        tx => appendTransactionMessageInstruction(
          getTransferSolInstruction({
            amount: lamports(BigInt(transaction.value)),
            destination: address(transaction.to),
            source: this.signer,
          }),
          tx,
        ),
      );
      tx = compileTransaction(unsignedTx);
    } else {
      // Custom instruction or pre-serialized transaction
      // Assume transaction.data is a base64-encoded or hex-encoded serialized transaction
      let transactionBytes;
      if (transaction.data.startsWith('0x')) {
        // Hex-encoded
        transactionBytes = Buffer.from(transaction.data.slice(2), 'hex');
      } else {
        transactionBytes = Buffer.from(transaction.data, 'base64');
      }
      const transactionDecoder = getTransactionDecoder();
      tx = transactionDecoder.decode(Uint8Array.from(transactionBytes));
    }
 
    const signedTx = await signTransaction([this.signer.keyPair], tx);
    const signedTxWithLifetime = {
      ...signedTx,
      lifetimeConstraint: {
        lastValidBlockHeight: latestBlockhash.lastValidBlockHeight
      }
    };
    const signature = getSignatureFromTransaction(signedTx);

    await sendAndConfirmTransaction(
      signedTxWithLifetime,
      { 
        commitment: 'confirmed',
      }
    );

    return {
      hash: signature,
      confirmations: MAX_CONFIRMATION,
      nonce: 0, // Solana does not use nonces in the same way as EVM
      gasPrice: '0', // Solana does not use gas price
      gasLimit: transaction.gasLimit || '0',
    };
  }
}

export class SolanaProvider implements RpcProvider {
  private readonly rpc: Rpc<SolanaRpcApiMainnet>;
  private readonly rpcSubscription: RpcSubscriptions<SolanaRpcSubscriptionsApi>;
  public syncedBlockNumber: number = 0;
  public synced: boolean = false;
  public name: string;
  public priority = 0;
  public lag = 0;
  public reliability = 1.0;
  public latency = 0.0;
  // Used for tracking how many calls we've made in the last second.
  public cpsTimestamps: number[] = [];
  public get cps(): number {
    // Average CPS over the last 10 seconds.
    const now = Date.now();
    this.cpsTimestamps = this.cpsTimestamps.filter((ts) => now - ts < 10_000);
    return this.cpsTimestamps.length / 10;
  }

  constructor(
    url = 'api.mainnet-beta.solana.com',
  ) {
    this.name = 'SolanaProvider'
    const defaultRpcSubscription = 'wss://api.mainnet-beta.solana.com/';
    // use default rpc subscription if provided is rpc specified
    if (url.startsWith('https://')) {
      this.rpc = createSolanaRpc(url);
      this.rpcSubscription = createSolanaRpcSubscriptions(defaultRpcSubscription);
    } else {
      this.rpc = createSolanaRpc(`https://${url}`);
      this.rpcSubscription = createSolanaRpcSubscriptions(`wss://${url}`);
    }
  }

  public async sync(): Promise<void> {
    try {
      this.syncedBlockNumber = Number(await this.rpc.getBlockHeight().send());
      this.synced = true;
    } catch (error) {
      this.synced = false;
      throw error;
    }
  }

  public async getSigner(signer: ISigner | string): Promise<ISigner> {
    let key;
    if (typeof signer === 'string') {
      key = signer;
    } else if ((signer as any).privateKey) {
      key = (signer as any).privateKey;
    } else {
      return signer;
    }
    const buffer = key.startsWith('0x') ? Buffer.from(key.slice(2), 'hex') : Buffer.from(key);
    const keypairSigner = await createKeyPairSignerFromPrivateKeyBytes(Uint8Array.from(buffer));
    return new SolanaWeb3Signer(this.rpc, this.rpcSubscription, keypairSigner);
  }

  public async connect(signer: ISigner | string): Promise<ISigner> {
    return this.getSigner(signer);
  }

  public async call(tx: ReadTransaction, block: number | string): Promise<string> {
    // call rpc with read only transaction using simulateTransaction
    let transactionBytes;
    if (tx.data.startsWith('0x')) {
      // Hex-encoded
      transactionBytes = Buffer.from(tx.data.slice(2), 'hex');
    } else {
      transactionBytes = Buffer.from(tx.data, 'base64');
    }
    const transactionDecoder = getTransactionDecoder();
    const txObject = transactionDecoder.decode(Uint8Array.from(transactionBytes));
    const base64Encoded = getBase64EncodedWireTransaction(txObject);
    const result = await this.rpc.simulateTransaction(base64Encoded as Base64EncodedWireTransaction, { encoding: 'base64' }).send();
    return result.value.returnData?.data.toString() || '';
  }

  public async send(method: string, params: unknown[]): Promise<unknown> {
    // Implement send method
    throw new Error('Method not implemented.');
  }

  public async getTransaction(hash: string): Promise<ITransactionResponse | undefined> {
    // Implement getTransaction method
    const result = await this.rpc.getTransaction(hash as Signature, {
      // NOTE: this is required to also support v0 transactions
      maxSupportedTransactionVersion: 0,
      encoding: 'json',
      commitment: 'finalized',
    }).send();
    return {
      hash: hash,
      confirmations: result ? SOLANA_MAX_CONFIRMATIONS : 0,
      nonce: 0, // this is not used in solana
      gasPrice: '1', // assume 1 lamport per unit
      gasLimit: result?.meta?.fee?.toString() || '0',
    };
  }

  public prepareRequest(method: string, params: unknown): [string, unknown[]] {
    // Implement prepareRequest method
    throw new Error('Method not implemented.');
  }

  public async estimateGas(tx: ReadTransaction | WriteTransaction): Promise<string> {
    // Implement estimateGas method
    throw new Error('Method not implemented.');
  }

  public async getTransactionReceipt(hash: string): Promise<ITransactionReceipt> {
    // Implement getTransactionReceipt method
    const result = await this.rpc.getTransaction(hash as Signature, {
      // NOTE: this is required to also support v0 transactions
      maxSupportedTransactionVersion: 0,
      encoding: 'json',
      commitment: 'finalized',
    }).send();
    return {
      blockNumber: Number(result?.slot) || 0,
      status: result?.meta?.err ? 0 : 1,
      transactionHash: hash,
      confirmations: result ? SOLANA_MAX_CONFIRMATIONS : 0,
      logs: result?.meta?.logMessages?.map((logLine, index) => {
        return {
          blockNumber: Number(result?.slot) || 0,
          blockHash: result?.transaction?.message.recentBlockhash,
          transactionIndex: 0,
          removed: false,
          address: '',
          topics: [],
          transactionHash: hash,
          logIndex: index,
          data: logLine,
        }
      }) || [],
    };
  }

  public async getGasPrice(): Promise<string> {
    // return lamports estimated by the rpc via getRecentPrioritizationFees
    const result = await this.rpc.getRecentPrioritizationFees().send();
    let sum = 0n;
    let count = 0n;
    result.forEach(value => {
      sum += value.prioritizationFee.valueOf() as bigint;
      count++;
    });
    return (sum / count).toString();
  }

  public async getBlock(block: number | string): Promise<IBlock> {
    // Implement getBlock method
    const result = await this.rpc.getBlock(BigInt(block)).send();
    if (!result) {
      throw new Error('Block not found');
    }
    return {
      hash: result?.blockhash ?? '',
      parentHash: result?.previousBlockhash ?? '',
      number: Number(result.blockHeight),
      timestamp: Number(result.blockTime),
    };
  }

  public async getBlockNumber(): Promise<number> {
    // get block height from rpc
    const result = await this.rpc.getBlockHeight().send();
    return Number(result);
  }

  public async getCode(address: string): Promise<string> {
    // Implement getCode method
    throw new Error('Method not implemented.');
  }

  public async getBalance(address: string, assetId: string): Promise<string> {
    if (assetId === SOLANA_NATIVE_ASSET_ID) {
      const result = await this.rpc.getBalance(address as Address).send();
      return result.value.toString();
    }
    const addressEncoder = getAddressEncoder();
    const [userTokenAccountPublicKey, _] = await getProgramDerivedAddress({
        programAddress: SPL_ASSOCIATED_TOKEN_ACCOUNT_PROGRAM_ID as Address,
        seeds: [
          addressEncoder.encode(address as Address),
          addressEncoder.encode(TOKEN_PROGRAM_ID as Address),
          addressEncoder.encode(assetId as Address),
        ]
    });
    const result = await this.rpc.getTokenAccountBalance(userTokenAccountPublicKey as Address).send();
    return result.value.amount;
  }

  public async getDecimals(address: string): Promise<number> {
    // Implement getDecimals method
    throw new Error('Method not implemented.');
  }

  public async getTransactionCount(address: string, block: number | string): Promise<number> {
    // Implement getTransactionCount method
    throw new Error('Method not implemented.');
  }
}
