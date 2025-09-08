/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  type Address,
  chainWrapper,
  type Hex,
  type PrivateKeyAccount,
  type WalletClient
} from '@chimera-monorepo/utils';
import { ISigner, ITransactionRequest, ITransactionResponse } from '../../types';

export interface EthWalletConfig {
  rpcUrl?: string;
  chainId?: number;
}

export class EthWallet implements ISigner {
  public address: string;

  private _privateKey: string;
  private config: EthWalletConfig;
  private account: PrivateKeyAccount;
  private readonly walletClient?: WalletClient;

  constructor(privateKey: string, config: EthWalletConfig = {}) {
    this.config = config;
    this._privateKey = privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`;
    this.account = chainWrapper.privateKeyToAccount(this._privateKey as Hex);
    this.address = this.account.address;

    if (this.config.rpcUrl) {
      this.walletClient = chainWrapper.createWalletClient({
        account: this.account,
        transport: chainWrapper.http(this.config.rpcUrl),
      }) as WalletClient;
    }
  }

  public static fromMnemonic(mnemonic: string, path?: string, config: EthWalletConfig = {}): EthWallet {
    const defaultPath = "m/44'/60'/0'/0/0" as const;
    const account = chainWrapper.mnemonicToAccount(mnemonic, { path: (path as any) || defaultPath });
    return new EthWallet(chainWrapper.toHex(account.getHdKey().privateKey as any), config);
  }

  static createRandom(config: EthWalletConfig = {}): EthWallet {
    return new EthWallet(chainWrapper.generatePrivateKey(), config);
  }

  public async getAddress(): Promise<string> {
    return this.address;
  }

  public async getPublicKey(): Promise<string> {
    return this.account.publicKey;
  }

  get privateKey(): string {
    return this._privateKey;
  }

  set privateKey(value: string) {
    this._privateKey = value.startsWith('0x') ? value : `0x${value}`;
    this.account = chainWrapper.privateKeyToAccount(this._privateKey as Hex);
    this.address = this.account.address;
  }

  public async signMessage(message: Uint8Array | string): Promise<string> {
    let messageBytes: Uint8Array;
    if (typeof message === 'string') {
      // Convert to UTF-8 bytes
      messageBytes = chainWrapper.toBytes(message);
    } else {
      // If it's already Uint8Array, use it directly
      messageBytes = message;
    }

    // Use the wallet client if available, otherwise create a temporary one with a default RPC
    const walletClient = this.walletClient || chainWrapper.createWalletClient({
      account: this.account,
      transport: chainWrapper.http('https://eth.llamarpc.com'), // Default RPC for signing
    });

    return await walletClient.signMessage({
      account: this.account,
      message: {
        raw: messageBytes,
      },
    });
  }

  public async sendTransaction(request: ITransactionRequest): Promise<ITransactionResponse> {
    if (!this.walletClient) {
      throw new Error('The ethereum wallet client is not initialized.');
    }

    // exclude funcSig
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { funcSig, ...tx } = request;

    const transaction = {
      to: tx.to as Address,
      data: tx.data as Hex,
      value: BigInt(tx.value),
      gas: tx.gasLimit ? BigInt(tx.gasLimit) : undefined,
      gasPrice: tx.gasPrice ? BigInt(tx.gasPrice) : undefined,
      nonce: tx.nonce,
      type: tx.type as any,
      maxFeePerGas: tx.maxFeePerGas ? BigInt(tx.maxFeePerGas) : undefined,
    };

    const hash = await (this.walletClient as any).sendTransaction(transaction);

    return {
      hash,
      confirmations: 0,
      nonce: tx.nonce || 0,
      gasPrice: tx.gasPrice ? BigInt(tx.gasPrice) : undefined,
      gasLimit: tx.gasLimit ? BigInt(tx.gasLimit) : BigInt(0),
    };
  }

  connect(config: EthWalletConfig): EthWallet {
    return new EthWallet(this._privateKey, config);
  }
}
