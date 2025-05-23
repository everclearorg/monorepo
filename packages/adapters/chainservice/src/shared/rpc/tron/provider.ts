/* eslint-disable @typescript-eslint/no-explicit-any */
import { BigNumber, constants } from 'ethers';
import { Block, TransactionReceipt, TransactionResponse } from '@ethersproject/abstract-provider';
import { ISigner, ITransactionRequest, ITransactionResponse, ReadTransaction, WriteTransaction } from '../../types';
import { SyncProvider } from '../eth';
import { GasEstimateInvalid, TransactionReadError } from '../../errors';
import { TronWeb } from '../../../mockable';
import { Interface } from 'ethers/lib/utils';

interface ContractFunctionParameter {
  type: string;
  value: string;
}

interface TronLog {
  address: string;
  topics: string[];
  data: string;
}

type TronWebInstance = InstanceType<typeof TronWeb>;

export interface TronWebFactory {
  create(config: { fullHost: string }): TronWebInstance;
}

class DefaultTronWebFactory implements TronWebFactory {
  create(config: { fullHost: string }): TronWebInstance {
    return new TronWeb(config);
  }
}

function decodeParameters(data: string, funcSig: string, value?: string): ContractFunctionParameter[] {
  const iface = new Interface([`function ${funcSig}`]);
  const tx = iface.parseTransaction({ data, value });

  return tx.args.map((arg, index) => ({
    type: tx.functionFragment.inputs[index].type,
    value: arg.toString(),
  }));
}

class TronWebSigner implements ISigner {
  constructor(private readonly tronWeb: TronWebInstance) {}

  public async getAddress(): Promise<string> {
    return this.tronWeb.defaultAddress.hex as string;
  }

  public async sendTransaction(transaction: ITransactionRequest): Promise<ITransactionResponse> {
    let tx = {} as any;

    if (!transaction.data || !transaction.data.length || transaction.data === '0x') {
      // Handle TRX transfer
      tx.transaction = await this.tronWeb.transactionBuilder.sendTrx(
        transaction.to,
        Number.parseInt(transaction.value || '0'),
      );
    } else {
      // Handle smart contract transaction
      tx = await this.tronWeb.transactionBuilder.triggerSmartContract(
        transaction.to,
        transaction.funcSig,
        {
          feeLimit: Number.parseInt(transaction.gasLimit || '0'),
          callValue: Number.parseInt(transaction.value || '0'),
        },
        decodeParameters(transaction.data, transaction.funcSig, transaction.value),
        this.tronWeb.defaultAddress.hex as string,
      );
    }

    // Sign and broadcast the transaction
    const signedTx = await this.tronWeb.trx.sign(tx.transaction);
    const result = await this.tronWeb.trx.sendRawTransaction(signedTx);

    // Get transaction info to calculate confirmations
    let confirmations = 0;
    try {
      const txInfo = await this.tronWeb.trx.getTransactionInfo(result.txid);
      if (txInfo.blockNumber) {
        const currentBlock = await this.tronWeb.trx.getCurrentBlock();
        confirmations = currentBlock.block_header.raw_data.number - txInfo.blockNumber;
      }
    } catch (error) {
      // If we can't get transaction info, confirmations will remain 0
      // This is normal for newly sent transactions
    }

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
  private readonly tronWeb: TronWebInstance;

  constructor(
    domain: number,
    url = 'https://api.trongrid.io',
    stallTimeout = 10_000,
    debugLogging = false,
    private readonly tronWebFactory: TronWebFactory = new DefaultTronWebFactory(),
  ) {
    super(url, domain, stallTimeout, debugLogging);
    this.tronWeb = this.tronWebFactory.create({ fullHost: url });
  }

  public async sync(): Promise<void> {
    try {
      const block = await this.tronWeb.trx.getCurrentBlock();
      this.syncedBlockNumber = block.block_header.raw_data.number;
      this.synced = true;
    } catch (error) {
      this.synced = false;
      throw error;
    }
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  public async call(tx: ReadTransaction, block: number | string): Promise<string> {
    const result = await this.tronWeb.transactionBuilder.triggerConstantContract(
      tx.to,
      tx.funcSig,
      {},
      decodeParameters(tx.data, tx.funcSig),
    );

    if (!result.constant_result || result.constant_result.length === 0) {
      throw new TransactionReadError(TransactionReadError.reasons.ContractReadError, { error: result.Error });
    }

    return result.constant_result[0];
  }

  public async getTransaction(hash: string): Promise<TransactionResponse> {
    const tx = await this.tronWeb.trx.getTransaction(hash);
    const txInfo = await this.tronWeb.trx.getTransactionInfo(hash);
    const from = tx.raw_data.contract[0].parameter.value.owner_address || '';
    const currentBlock = await this.tronWeb.trx.getCurrentBlock();
    const confirmations = txInfo.blockNumber ? currentBlock.block_header.raw_data.number - txInfo.blockNumber : 0;
    const blockHash = txInfo.blockNumber
      ? (await this.tronWeb.trx.getBlockByNumber(txInfo.blockNumber)).blockID
      : undefined;
    const callValue = (tx as any).raw_data.contract[0].parameter.value.call_value || '0';

    return {
      hash: tx.txID,
      confirmations,
      nonce: 0, // Tron doesn't use nonces
      gasPrice: BigNumber.from(1),
      gasLimit: BigNumber.from(tx.raw_data.fee_limit || 0),
      to: (tx as any).raw_data.contract[0].parameter.value.contract_address,
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
    const receipt = await this.tronWeb.trx.getTransactionInfo(hash);
    const tx = await this.getTransaction(hash);
    const currentBlock = await this.tronWeb.trx.getCurrentBlock();
    const confirmations = receipt.blockNumber ? currentBlock.block_header.raw_data.number - receipt.blockNumber : 0;
    const blockHash = receipt.blockNumber ? (await this.tronWeb.trx.getBlockByNumber(receipt.blockNumber)).blockID : '';

    // Type guard to ensure from is a string
    const fromAddress = (value: unknown): string => {
      if (typeof value === 'string') {
        return value;
      }
      return '';
    };

    return {
      transactionHash: hash,
      blockNumber: receipt.blockNumber || 0,
      confirmations,
      status: receipt.receipt.result === 'SUCCESS' ? 1 : 0,
      logs:
        receipt.log?.map((log: TronLog, index: number) => ({
          address: this.tronWeb.address.fromHex(log.address),
          topics: log.topics || [],
          data: log.data || '0x',
          logIndex: index,
          blockNumber: receipt.blockNumber || 0,
          blockHash,
          transactionHash: hash,
          transactionIndex: 0, // Tron doesn't have transaction index
          removed: false,
        })) || [],
      to: tx.to || '',
      from: fromAddress(tx.from),
      contractAddress: receipt.contract_address || '',
      transactionIndex: 0, // Tron doesn't have transaction index
      gasUsed: BigNumber.from(receipt.receipt.energy_usage || 0),
      effectiveGasPrice: BigNumber.from(0),
      type: 0,
      byzantium: true,
      logsBloom: '0x',
      blockHash,
      cumulativeGasUsed: BigNumber.from(receipt.receipt.energy_usage_total || 0),
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

  public async getCode(address: string): Promise<string> {
    const contract = await this.tronWeb.trx.getContract(address);
    return contract.bytecode || '0x';
  }

  public async getBalance(address: string, assetId: string): Promise<string> {
    if (assetId === constants.AddressZero) {
      // Get TRX balance
      const balance = await this.tronWeb.trx.getBalance(address);
      return balance.toString();
    } else {
      // Get TRC20 token balance
      const contract = await this.tronWeb.contract().at(assetId);
      // Set the owner address to the address we want to check balance for
      const originalAddress = this.tronWeb.defaultAddress.hex;
      try {
        // Temporarily set the default address to the address we want to check
        this.tronWeb.defaultAddress.hex = address;
        const balance = await contract.balanceOf(address).call();
        return balance.toString();
      } finally {
        // Restore the original address
        this.tronWeb.defaultAddress.hex = originalAddress;
      }
    }
  }

  public async getDecimals(address: string): Promise<number> {
    if (address === constants.AddressZero) {
      return 6; // TRX has 6 decimals
    }
    const contract = await this.tronWeb.contract().at(address);
    // Set a default owner address for the contract call
    const originalAddress = this.tronWeb.defaultAddress.hex;
    try {
      // Use a default address for the contract call
      this.tronWeb.defaultAddress.hex = '0x0000000000000000000000000000000000000000';
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

    const result = await this.tronWeb.transactionBuilder.estimateEnergy(
      tx.to,
      tx.funcSig,
      {
        callValue: Number.parseInt(writeTx?.value || '0'),
      },
      decodeParameters(tx.data, tx.funcSig, writeTx?.value),
      writeTx?.from,
    );
    if (!result.result.result) {
      throw new GasEstimateInvalid('failed to estimate energy');
    }
    return result.energy_required.toString();
  }

  public getSigner(signer: ISigner | string): ISigner {
    if (typeof signer === 'string') {
      this.tronWeb.setPrivateKey(signer);
      return new TronWebSigner(this.tronWeb);
    }
    return signer;
  }

  public connect(signer: ISigner | string): ISigner {
    return this.getSigner(signer);
  }
}
