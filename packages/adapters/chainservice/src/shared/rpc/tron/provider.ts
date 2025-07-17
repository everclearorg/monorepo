/* eslint-disable @typescript-eslint/no-explicit-any */
import { BigNumber, constants, utils } from 'ethers';
import { Block, TransactionReceipt, TransactionResponse } from '@ethersproject/abstract-provider';
import {
  ISigner,
  ISignerApi,
  ITransactionRequest,
  ITransactionResponse,
  ReadTransaction,
  WriteTransaction,
} from '../../types';
import { SyncProvider } from '../eth';
import { UnpredictableGasLimit, TransactionReadError } from '../../errors';
import { TronWeb } from '../../../mockable';
import { Interface } from 'ethers/lib/utils';

interface TronLog {
  address: string;
  topics: string[];
  data: string;
}

type TronWebInstance = InstanceType<typeof TronWeb>;

const DEFAULT_ADDRESS = '410000000000000000000000000000000000000000';

export interface TronWebFactory {
  create(config: { fullHost: string; apiKey?: string }): TronWebInstance;
}

class DefaultTronWebFactory implements TronWebFactory {
  create(config: { fullHost: string; apiKey?: string }): TronWebInstance {
    return new TronWeb({ fullHost: config.fullHost, headers: config.apiKey ? { 'TRON-PRO-API-KEY': config.apiKey } : undefined });
  }
}

/**
 * Converts EVM addresses in transaction data to Tron addresses for specific function calls.
 * This handles known function signatures that contain address parameters by doing direct
 * byte manipulation instead of ABI decoding/encoding.
 * 
 * @param data - The transaction data (0x...)
 * @param funcSig - The function signature
 * @param tronWeb - TronWeb instance for address conversion
 * @returns Modified transaction data with converted addresses
 */
const convertAddressesInTransactionData = (data: string, funcSig: string, tronWeb: TronWebInstance): string => {
  try {
    // Only process known function signatures that need address conversion
    if (!funcSig.includes('processIntentQueueViaRelayer') && !funcSig.includes('processFillQueueViaRelayer')) {
      return data;
    }
    
    // Function signatures with their relayer address parameter positions
    const FUNCTION_SIGNATURES = {
      'processIntentQueueViaRelayer': {
        // processIntentQueueViaRelayer(uint32,Intent[],address,uint256,uint256,uint256,bytes)
        // The address parameter is at position 2 (0-indexed)
        // After 4-byte function selector: 32 bytes (uint32), 32 bytes (Intent[] offset), then 32 bytes (address)
        relayerAddressOffset: 4 + 32 + 32 // 68 bytes from start
      },
      'processFillQueueViaRelayer': {
        // processFillQueueViaRelayer(uint32,uint32,address,uint256,uint256,uint256,bytes)
        // The address parameter is at position 2 (0-indexed)
        // After 4-byte function selector: 32 bytes (uint32), 32 bytes (uint32), then 32 bytes (address)
        relayerAddressOffset: 4 + 32 + 32 // 68 bytes from start
      }
    };
    
    let functionName: keyof typeof FUNCTION_SIGNATURES;
    if (funcSig.includes('processIntentQueueViaRelayer')) {
      functionName = 'processIntentQueueViaRelayer';
    } else if (funcSig.includes('processFillQueueViaRelayer')) {
      functionName = 'processFillQueueViaRelayer';
    } else {
      return data;
    }
    
    const config = FUNCTION_SIGNATURES[functionName];
    const addressOffset = config.relayerAddressOffset;
    
    // Extract the EVM address from the transaction data (32 bytes, but only last 20 bytes are the address)
    const startPos = addressOffset * 2; // Convert to hex string position
    const endPos = startPos + 64; // 32 bytes = 64 hex characters
    
    if (data.length < endPos + 2) { // +2 for "0x"
      return data;
    }
    
    // Extract the 32-byte parameter (padded address)
    const paddedAddress = data.slice(startPos + 2, endPos + 2); // Skip "0x"
    
    // Get the actual 20-byte address (take the last 40 hex characters from the 64-char padded value)
    // This correctly handles addresses with leading zeros
    const evmAddress = '0x' + paddedAddress.slice(-40); // Take last 40 chars (20 bytes)
    
    // Convert EVM address to Tron address
    const tronAddress = tronWeb.address.fromHex(evmAddress);
    
    // Convert Tron address back to hex format for transaction data
    const tronAddressHex = tronWeb.address.toHex(tronAddress);
    
    // Create new padded address (32 bytes with leading zeros)
    // CRITICAL FIX: Tron address hex doesn't have '0x' prefix, so use it directly
    const newPaddedAddress = tronAddressHex.padStart(64, '0'); // Pad to 64 chars with leading zeros
    
    // Replace the address in the transaction data
    const convertedData = data.slice(0, startPos + 2) + newPaddedAddress + data.slice(endPos + 2);
    
    return convertedData;
    
  } catch (error) {
    // If conversion fails, return original data
    console.warn('Failed to convert addresses in transaction data:', error);
    return data;
  }
};

class TronWeb3Signer implements ISigner {
  constructor(
    private readonly provider: TronSyncProvider,
    private readonly api?: ISignerApi,
  ) {}

  public get signerApi(): ISignerApi | undefined {
    return this.api;
  }

  public async getAddress(): Promise<string> {
    return this.provider.tronWeb.defaultAddress.hex as string;
  }

  public async sendTransaction(transaction: ITransactionRequest): Promise<ITransactionResponse> {
    let tx = {} as any;
    const fromAddress = this.provider.tronWeb.defaultAddress.hex as string;

    if (!transaction.data || !transaction.data.length || transaction.data === '0x') {
      // Handle TRX transfer
      tx.transaction = await this.provider.tronWeb.transactionBuilder.sendTrx(
        this.provider.getTronAddress(transaction.to),
        Number.parseInt(transaction.value || '0'),
      );
    } else {
      // Handle smart contract transaction
      // Convert addresses in transaction data for known function signatures
      const convertedData = convertAddressesInTransactionData(
        transaction.data, 
        transaction.funcSig || '', 
        this.provider.tronWeb
      );
      
      tx = await this.provider.tronWeb.transactionBuilder.triggerSmartContract(
        this.provider.getTronAddress(transaction.to),
        transaction.funcSig,
        {
          feeLimit: Number.parseInt(transaction.gasLimit || '100000000'), // 100 TRX default fee limit
          callValue: Number.parseInt(transaction.value || '0'),
          rawParameter: convertedData.slice(10), // Remove function selector from converted data
        },
        [], // Empty parameters array since we're using rawParameter
        fromAddress,
      );
    }

    // Sign and broadcast the transaction
    let signedTx: any;
    if (this.api) {
      // Use the signer API to sign the transaction
      signedTx = tx.transaction;
      const identifier = await this.api.getPublicKey();
      const signature = await this.api.sign(identifier, utils.arrayify(signedTx.txID));
      signedTx.signature = [signature];
    } else {
      // Sign using TronWeb directly
      signedTx = await this.provider.tronWeb.trx.sign(tx.transaction);
    }
    const result = await this.provider.tronWeb.trx.sendRawTransaction(signedTx);

    // Get transaction info to calculate confirmations
    let confirmations = 0;
    try {
      const txInfo = await this.provider.tronWeb.trx.getTransactionInfo(result.txid);
      if (txInfo.blockNumber) {
        const currentBlock = await this.provider.tronWeb.trx.getCurrentBlock();
        confirmations = currentBlock.block_header.raw_data.number - txInfo.blockNumber;
      }
    } catch (error) {
      // If we can't get transaction info, confirmations will remain 0
      // This is normal for newly sent transactions
    }

    // Increment nonce for the sender address
    const currentNonce = this.provider.nonces.get(fromAddress) || 0;
    this.provider.nonces.set(fromAddress, currentNonce + 1);

    // Convert response to ITransactionResponse format
    return {
      hash: result.txid,
      confirmations,
      nonce: 0, // Tron doesn't use nonces
      gasPrice: BigNumber.from(1), // Tron uses energy instead of gas
      gasLimit: transaction.gasLimit || '0',
    };
  }
}

export class TronSyncProvider extends SyncProvider {
  public readonly tronWeb: TronWebInstance;
  public readonly nonces: Map<string, number> = new Map();

  constructor(
    domain: number,
    url = 'https://api.trongrid.io',
    stallTimeout = 10_000,
    debugLogging = false,
    private readonly tronWebFactory: TronWebFactory = new DefaultTronWebFactory(),
  ) {
    // Extract API key from URL if present
    const urlObj = new URL(url);
    const apiKey = urlObj.searchParams.get('apiKey');
    
    // Remove API key from URL to get clean fullHost
    urlObj.searchParams.delete('apiKey');
    const cleanUrl = urlObj.toString();
    
    // For ethers compatibility: append /jsonrpc to URL if not already present
    // This fixes 405 errors when making JSON-RPC calls like eth_gasPrice
    const jsonRpcUrl = cleanUrl.endsWith('/jsonrpc') ? cleanUrl : cleanUrl.replace(/\/$/, '') + '/jsonrpc';
    
    super(jsonRpcUrl, domain, stallTimeout, debugLogging);
    this.tronWeb = this.tronWebFactory.create({ fullHost: cleanUrl, apiKey: apiKey || undefined });
  }

  public async sync(): Promise<void> {
    // Tronweb does not have a concept of syncing like Ethereum, let's assume we are always synced
    // and reduce the number of API calls.
    this.syncedBlockNumber = 1;
    this.synced = true;
    // try {
    //   const block = await this.tronWeb.trx.getCurrentBlock();
    //   this.syncedBlockNumber = block.block_header.raw_data.number;
    //   this.synced = true;
    // } catch (error) {
    //   this.synced = false;
    //   throw error;
    // }
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  public async call(tx: ReadTransaction, _block: number | string): Promise<string> {
    // CRITICAL FIX: Ensure the 'to' address is always converted to Tron format
    const tronToAddress = this.getTronAddress(tx.to);
    
    // Convert addresses in transaction data for known function signatures
    const convertedData = convertAddressesInTransactionData(
      tx.data, 
      tx.funcSig || '', 
      this.tronWeb
    );
    
    const result = await this.tronWeb.transactionBuilder.triggerConstantContract(
      tronToAddress, // Use converted Tron address
      tx.funcSig,
      {
        rawParameter: convertedData.slice(10), // Use converted data
      },
      [],
      this.tronWeb.defaultAddress.hex || DEFAULT_ADDRESS,
    );

    if (!result.constant_result || result.constant_result.length === 0) {
      throw new TransactionReadError(TransactionReadError.reasons.ContractReadError, { error: result.Error });
    }

    return `0x${result.constant_result[0]}`;
  }

  private async getTransactionData(hash: string, retryCount: number = 0): Promise<any> {
    const maxRetries = 5;
    const retryDelay = 2000; // 2 seconds
    
    try {
      const tx = await this.tronWeb.trx.getTransaction(hash);
      const txInfo = await this.tronWeb.trx.getTransactionInfo(hash);
      const from = tx.raw_data.contract[0].parameter.value.owner_address || '';
      const to =
        (tx as any).raw_data.contract[0].parameter.value.to_address ||
        (tx as any).raw_data.contract[0].parameter.value.contract_address ||
        '';
      const status = (tx as any).ret[0].contractRet === 'SUCCESS' ? 1 : 0;
      const currentBlock = await this.tronWeb.trx.getCurrentBlock();
      const confirmations = txInfo.blockNumber ? currentBlock.block_header.raw_data.number - txInfo.blockNumber : 0;
      const blockHash = txInfo.blockNumber
        ? (await this.tronWeb.trx.getBlockByNumber(txInfo.blockNumber)).blockID
        : undefined;
      const callValue = (tx as any).raw_data.contract[0].parameter.value.call_value || '0';

      // Enhanced logging for debugging
      console.log(`[TronProvider] Transaction found successfully: ${hash}, status: ${status}, confirmations: ${confirmations}, attempt: ${retryCount + 1}`);

      return { tx, txInfo, from, to, status, currentBlock, confirmations, blockHash, callValue };
    } catch (error: any) {
      console.log(`[TronProvider] Transaction lookup failed: ${hash}, attempt: ${retryCount + 1}, error: ${error.message}`);
      
      if (retryCount < maxRetries) {
        console.log(`[TronProvider] Retrying transaction lookup in ${retryDelay * (retryCount + 1)}ms...`);
      }
      
      if (retryCount < maxRetries) {
        // Wait before retrying
        await new Promise(resolve => setTimeout(resolve, retryDelay * (retryCount + 1)));
        return this.getTransactionData(hash, retryCount + 1);
      }
      
      // Enhanced error information
      const enhancedError = new Error(`Transaction not found after ${maxRetries + 1} attempts. This could indicate:\n` +
        `1. Transaction was rejected by Tron network during validation\n` +
        `2. Contract validation failed (e.g., address format mismatch)\n` +
        `3. Transaction is still propagating through the network\n` +
        `Original error: ${error.message}`);
      enhancedError.stack = error.stack;
      throw enhancedError;
    }
  }

  public async getTransaction(hash: string): Promise<TransactionResponse> {
    const { tx, txInfo, from, to, confirmations, blockHash, callValue } = await this.getTransactionData(hash);

    return {
      hash: tx.txID,
      confirmations,
      nonce: 0, // Tron doesn't use nonces
      gasPrice: BigNumber.from(1),
      gasLimit: BigNumber.from(tx.raw_data.fee_limit || 0),
      to,
      from,
      data: (tx as any).raw_data.contract[0].parameter.value.data,
      value: BigNumber.from(callValue),
      chainId: this.internalProvider.domain,
      blockNumber: txInfo.blockNumber,
      blockHash,
      wait: () => Promise.reject(new Error('Not implemented')),
    };
  }

  public async getTransactionReceipt(hash: string): Promise<TransactionReceipt> {
    const { txInfo, from, to, status, confirmations, blockHash } = await this.getTransactionData(hash);

    // Enhanced logging for transaction status
    console.log(`[TronProvider] Transaction receipt retrieved: ${hash}, status: ${status}, confirmations: ${confirmations}, blockNumber: ${txInfo.blockNumber}`);

    // Check for specific failure reasons in Tron transaction info
    if (status === 0 && txInfo.receipt?.result) {
      const failureReason = txInfo.receipt.result;
      console.error(`[TronProvider] Transaction failed: ${hash}, reason: ${failureReason}`);
    }

    return {
      transactionHash: hash,
      blockNumber: txInfo.blockNumber || 0,
      confirmations,
      status,
      logs:
        txInfo.log?.map((log: TronLog, index: number) => ({
          address: this.tronWeb.address.fromHex(log.address),
          topics: log.topics || [],
          data: log.data || '0x',
          logIndex: index,
          blockNumber: txInfo.blockNumber || 0,
          blockHash,
          transactionHash: hash,
          transactionIndex: 0, // Tron doesn't have transaction index
          removed: false,
        })) || [],
      to,
      from,
      contractAddress: txInfo.contract_address || '',
      transactionIndex: 0, // Tron doesn't have transaction index
      gasUsed: BigNumber.from(txInfo.receipt?.energy_usage || 0),
      effectiveGasPrice: BigNumber.from(0),
      type: 0,
      byzantium: true,
      logsBloom: '0x',
      blockHash,
      cumulativeGasUsed: BigNumber.from(txInfo.receipt?.energy_usage_total || 0),
    };
  }

  public async getBlock(block: number | string): Promise<Block> {
    const blockData =
      typeof block === 'string'
        ? await this.tronWeb.trx.getBlock(block)
        : await this.tronWeb.trx.getBlockByNumber(block);

    return {
      hash: blockData.blockID,
      parentHash: blockData.block_header.raw_data.parentHash,
      number: blockData.block_header.raw_data.number,
      timestamp: blockData.block_header.raw_data.timestamp,
      transactions: blockData.transactions?.map((tx) => tx.txID) || [],
      nonce: '',
      difficulty: 0,
      _difficulty: BigNumber.from(0),
      gasLimit: BigNumber.from(0),
      gasUsed: BigNumber.from(0),
      miner: '',
      extraData: '',
      baseFeePerGas: null,
    };
  }

  public async getBlockNumber(): Promise<number> {
    const blockData = await this.tronWeb.trx.getBlock('latest');
    return blockData.block_header.raw_data.number;
  }

  public async getCode(address: string): Promise<string> {
    const contract = await this.tronWeb.trx.getContract(this.getTronAddress(address));
    return contract.bytecode || '0x';
  }

  public async getBalance(address: string, assetId: string): Promise<string> {
    const tronAddress = this.getTronAddress(address);
    if (assetId === constants.AddressZero) {
      // Get TRX balance
      const balance = await this.tronWeb.trx.getBalance(tronAddress);
      return balance.toString();
    }

    // Get TRC20 token balance
    const contract = await this.tronWeb.contract().at(this.getTronAddress(assetId));
    // Set the owner address to the address we want to check balance for
    const originalAddress = this.tronWeb.defaultAddress.hex;
    try {
      // Temporarily set the default address to the address we want to check
      this.tronWeb.defaultAddress.hex = DEFAULT_ADDRESS;
      const balance = await contract.balanceOf(tronAddress).call();
      return balance.toString();
    } finally {
      // Restore the original address
      this.tronWeb.defaultAddress.hex = originalAddress;
    }
  }

  public async getDecimals(address: string): Promise<number> {
    if (address === constants.AddressZero) {
      return 6; // TRX has 6 decimals
    }
    const contract = await this.tronWeb.contract().at(this.getTronAddress(address));
    // Set a default owner address for the contract call
    const originalAddress = this.tronWeb.defaultAddress.hex;
    try {
      // Use a default address for the contract call
      this.tronWeb.defaultAddress.hex = DEFAULT_ADDRESS;
      const decimals = await contract.decimals().call();
      return Number(decimals);
    } finally {
      // Restore the original address
      this.tronWeb.defaultAddress.hex = originalAddress;
    }
  }

  public async estimateGas(tx: ReadTransaction | WriteTransaction): Promise<string> {
    const isWriteTx = 'value' in tx || 'from' in tx;
    const writeTx = isWriteTx ? (tx as WriteTransaction) : undefined;

    // If from address is provided, convert it to Tron format if needed
    let fromAddress = writeTx?.from;
    if (fromAddress) {
      fromAddress = this.getTronAddress(fromAddress);
    }

    // CRITICAL FIX: Ensure the 'to' address is always converted to Tron format
    const tronToAddress = this.getTronAddress(tx.to);
    
    // Convert addresses in transaction data for known function signatures
    const convertedData = convertAddressesInTransactionData(
      tx.data, 
      tx.funcSig || '', 
      this.tronWeb
    );

    const result = await this.tronWeb.transactionBuilder.triggerConstantContract(
      tronToAddress, // Use converted Tron address
      tx.funcSig,
      {
        callValue: Number.parseInt(writeTx?.value || '0'),
        rawParameter: convertedData.slice(10), // Use converted data
      },
      [],
      fromAddress || (this.tronWeb.defaultAddress.hex as string),
    );
    
    // Check if the transaction succeeded
    if (!result.result?.result) {
      throw new UnpredictableGasLimit();
    }
    
    // TronWeb returns energy_used for successful calls, not energy_required
    // Use energy_used as the gas estimate if available, otherwise fallback to energy_required
    const gasEstimate = result.energy_used || result.energy_required;
    if (!gasEstimate) {
      throw new UnpredictableGasLimit();
    }
    
    return gasEstimate.toString();
  }

  public async getSigner(signer: ISigner | string): Promise<ISigner> {
    const privateKey = typeof signer === 'string' ? signer : (signer as any).privateKey;
    if (privateKey) {
      this.tronWeb.setPrivateKey(privateKey.startsWith('0x') ? privateKey.slice(2) : privateKey);
      return new TronWeb3Signer(this);
    }

    return new TronWeb3Signer(this, (signer as ISigner).signerApi);
  }

  public async connect(signer: ISigner | string): Promise<ISigner> {
    return this.getSigner(signer);
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  public async getTransactionCount(address: string, _blockTag: string | number = 'latest'): Promise<number> {
    return this.nonces.get(address) || 0;
  }

  /**
   * Converts EVM-style addresses (0x format) to Tron T-addresses when needed.
   * 
   * This method implements the runtime address conversion strategy:
   * - Configuration files store addresses in unified EVM format (0x...)
   * - At runtime, when interacting with Tron network, convert to T-address format
   * - This approach maintains consistency across all domains while supporting VM-specific formats
   * 
   * @param address - Address in either EVM format (0x...) or Tron format (T...)
   * @returns Tron-compatible address (T-address format)
   * 
   * @example
   * // Config address (EVM format):  "0xD84173290E0E486B12B973F704CdDEF6E46A308E"
   * // Converted to Tron format:     "TLsV52sRDL79HXGGm9yzwKibb6BeruhUzy"
   */
  public getTronAddress(address: string): string {
    if (address.startsWith('0x')) {
      return this.tronWeb.address.fromHex(`0x${address.slice(-40)}`);
    }

    return address;
  }
}
