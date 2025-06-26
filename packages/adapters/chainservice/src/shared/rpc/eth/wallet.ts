/* eslint-disable @typescript-eslint/no-explicit-any */
import { Wallet, providers } from 'ethers';
import { ITransactionRequest } from '../../types';
import { Wordlist } from '@ethersproject/wordlists';
import { Provider } from '@ethersproject/abstract-provider';

export class EthWallet extends Wallet {
  public static fromMnemonic(mnemonic: string, path?: string, wordlist?: Wordlist): EthWallet {
    const wallet = super.fromMnemonic(mnemonic, path, wordlist);
    return new EthWallet(wallet);
  }

  static createRandom(options?: any): EthWallet {
    const wallet = super.createRandom(options);
    return new EthWallet(wallet);
  }
  public async sendTransaction(transaction: providers.TransactionRequest): Promise<providers.TransactionResponse> {
    // exclude funcSig
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { funcSig, ...tx } = transaction as unknown as ITransactionRequest;
    return await super.sendTransaction(tx);
  }

  connect(provider: Provider): Wallet {
    return new EthWallet(this, provider);
  }
}
