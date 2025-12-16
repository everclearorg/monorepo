/* eslint-disable @typescript-eslint/no-explicit-any */
import { type PublicClient, type Hex, chainWrapper } from '@chimera-monorepo/utils';
import { getAddressFromPublicKey } from '@chimera-monorepo/utils';
import { ITransactionRequest, ITransactionResponse, ISigner } from '@chimera-monorepo/chainservice';

import { Web3SignerApi } from './api';

export class Web3Signer implements ISigner {
  private static MESSAGE_PREFIX = '\x19Ethereum Signed Message:\n';

  private static getAddressFromPublicKey(publicKey: string): string {
    return getAddressFromPublicKey(publicKey);
  }

  private static prepareEthereumSignedMessage(message: Uint8Array | string): Hex {
    // Convert message to bytes, conversion method depends on the type of message,
    // whether it is a hex string or utf-8 string, or use as is if it is already a byte array.
    const messageBytes = typeof message === 'string' ? chainWrapper.toBytes(message) : message;
    const prefixBytes = chainWrapper.stringToBytes(Web3Signer.MESSAGE_PREFIX);
    const lengthBytes = chainWrapper.stringToBytes(messageBytes.length.toString());
    const ethMessage = chainWrapper.concat([prefixBytes, lengthBytes, messageBytes]) as Uint8Array;

    return chainWrapper.toHex(ethMessage, { size: ethMessage.length });
  }

  public address?: string;
  public publicClient?: PublicClient;
  private readonly api: Web3SignerApi;

  public get signerApi(): Web3SignerApi {
    return this.api;
  }

  constructor(
    public readonly web3SignerUrl: string,
    publicClient?: PublicClient,
  ) {
    this.web3SignerUrl = web3SignerUrl;
    this.publicClient = publicClient;
    this.api = new Web3SignerApi(web3SignerUrl);
  }

  public connect(publicClient: PublicClient): Web3Signer {
    this.publicClient = publicClient;
    return new Web3Signer(this.web3SignerUrl, publicClient);
  }

  public async getAddress(): Promise<string> {
    const publicKey = await this.api.getPublicKey();
    const address = Web3Signer.getAddressFromPublicKey(publicKey);
    this.address = address;
    return address;
  }

  public async signMessage(message: Hex | string): Promise<Hex> {
    const identifier = await this.api.getPublicKey();
    const data = Web3Signer.prepareEthereumSignedMessage(message);

    return (await this.api.sign(identifier, data)) as Hex;
  }

  public async signTransaction(transaction: any): Promise<Hex> {
    const baseTx = Object.assign(
      {
        to: transaction.to || undefined,
        nonce: transaction.nonce ? Number(BigInt(transaction.nonce)) : undefined,
        gasLimit: BigInt(transaction.gasLimit) || undefined,
        data: transaction.data || undefined,
        value: BigInt(transaction.value) || undefined,
        chainId: transaction.chainId || undefined,
      },
      // If an EIP-1559 transaction, use the EIP-1559 specific fields.
      transaction.type === 2
        ? {
            maxFeePerGas: BigInt(transaction.maxFeePerGas),
            maxPriorityFeePerGas: BigInt(transaction.maxPriorityFeePerGas),
            type: 2,
          }
        : {
            gasPrice: BigInt(transaction.gasPrice),
            type: 0,
          },
    );

    const identifier = await this.api.getPublicKey();
    const digestBytes = chainWrapper.serializeTransaction(baseTx as any);

    const signatureHex = await this.api.sign(identifier, digestBytes);
    const signature = chainWrapper.parseSignature(signatureHex as Hex);
    return chainWrapper.serializeTransaction(baseTx as any, signature);
  }

  public async sendTransaction(transaction: ITransactionRequest): Promise<ITransactionResponse> {
    if (!this.publicClient) {
      throw new Error('PublicClient is required to send transactions');
    }

    const hash = await this.publicClient.sendRawTransaction({
      serializedTransaction: await this.signTransaction(transaction),
    });

    return {
      hash,
      confirmations: 0, // Will be updated by the chain service
      nonce: transaction.nonce || 0,
      gasPrice: transaction.gasPrice ? BigInt(transaction.gasPrice) : undefined,
      gasLimit: BigInt(transaction.gasLimit || '0'),
    };
  }
}
