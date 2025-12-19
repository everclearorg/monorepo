import { Logger } from '@chimera-monorepo/utils';
import { ISigner, ITransactionRequest, ITransactionResponse } from '../../types';
import { createTronWeb, getTestTronPrivateKey, getTestTronAddress } from '@chimera-monorepo/utils';

/**
 * Native Tron Signer that uses private keys directly
 * This bypasses Web3Signer for Tron-specific transaction signing
 */
export class TronNativeSigner implements ISigner {
  private readonly tronWeb: any;
  private readonly privateKey: string;
  private readonly logger: Logger;

  constructor(privateKey?: string, fullHost: string = 'https://api.trongrid.io', logger?: Logger) {
    this.privateKey = privateKey || getTestTronPrivateKey();
    this.tronWeb = createTronWeb(this.privateKey, fullHost);
    this.logger = logger || new Logger({ name: 'TronNativeSigner' });

    this.logger.info('TronNativeSigner initialized');
  }

  public async getAddress(): Promise<string> {
    if (this.tronWeb.defaultAddress.base58) {
      return this.tronWeb.defaultAddress.base58;
    }
    
    // Fallback to test address
    return getTestTronAddress();
  }

  public async sendTransaction(transaction: ITransactionRequest): Promise<ITransactionResponse> {
    this.logger.info('=== TronNativeSigner sendTransaction START ===');

    try {
      // Get the from address
      const fromAddress = await this.getAddress();
      this.logger.info('Using Tron address for transaction');

      // Prepare the smart contract call
      const tx = await this.tronWeb.transactionBuilder.triggerSmartContract(
        this.tronWeb.address.toHex(transaction.to),
        transaction.data,
        {
          feeLimit: parseInt(transaction.gasLimit || '150000000'), // Default 150 TRX fee limit
          callValue: 0,
          tokenId: '',
          tokenValue: 0,
        },
        [],
        this.tronWeb.address.toHex(fromAddress),
      );

      if (!tx.result || !tx.result.result) {
        throw new Error(`Failed to create transaction: ${tx.result?.message || 'Unknown error'}`);
      }

      this.logger.info('Transaction created successfully');

      // Sign the transaction using TronWeb's native signing
      const signedTx = await this.tronWeb.trx.sign(tx.transaction);
      
      this.logger.info('Transaction signed successfully');

      // Broadcast the transaction
      const result = await this.tronWeb.trx.sendRawTransaction(signedTx);
      
      if (!result.result) {
        throw new Error(`Transaction broadcast failed: ${result.code || result.message || 'Unknown error'}`);
      }

      this.logger.info('Transaction broadcast successfully');

      // Get transaction info to calculate confirmations
      let confirmations = 0;
      try {
        const txInfo = await this.tronWeb.trx.getTransactionInfo(result.txid);
        if (txInfo.blockNumber) {
          const currentBlock = await this.tronWeb.trx.getCurrentBlock();
          confirmations = currentBlock.block_header.raw_data.number - txInfo.blockNumber;
        }
      } catch (error) {
        this.logger.warn('Could not get transaction confirmations');
      }

      // Convert response to ITransactionResponse format
      return {
        hash: result.txid,
        confirmations,
        nonce: 0, // Tron doesn't use nonces
        gasPrice: BigInt(transaction.gasPrice || '1'),
        gasLimit: BigInt(transaction.gasLimit || '0'),
      };

    } catch (error) {
      this.logger.error('TronNativeSigner transaction failed');
      throw error;
    }
  }

  public async signMessage(message: string): Promise<string> {
    this.logger.info('Signing message with TronNativeSigner');
    
    try {
      const signature = await this.tronWeb.trx.signMessageV2(message);
      this.logger.info('Message signed successfully');
      return signature;
    } catch (error) {
      this.logger.error('Failed to sign message');
      throw error;
    }
  }

  public connect(): Promise<ISigner> {
    // For native signer, return self as it's already "connected"
    return Promise.resolve(this);
  }
} 