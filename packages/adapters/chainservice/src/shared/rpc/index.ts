import {
  ReadTransaction,
  WriteTransaction,
  IBlock,
  ISigner,
  ITransactionResponse,
  ITransactionReceipt,
  ITransactionRequest,
} from '../types';
import { getEthRpcProvider } from './eth';
import { getTronRpcProvider } from './tron';
import { getSolanaRpcProvider } from './solana';
export { SyncProvider } from './eth';

// VM Type mappings
// NOTE: to add a new VM type, add a new key in all the mappings so its properly typed
// on `getRpcClient` return values.
// NOTE: These can be used to strongly type the RpcProvider responses
export const SupportedVms = {
  evm: 'evm',
  tvm: 'tvm',
  svm: 'svm',
} as const;
export type SupportedVm = (typeof SupportedVms)[keyof typeof SupportedVms];

export const MAX_CONFIRMATION = 10000;

export interface SignerTypeMaps {
  [SupportedVms.evm]: ISigner;
}
export interface BlockTypeMap {
  [SupportedVms.evm]: IBlock;
}

export interface TransactionRequestTypeMap {
  [SupportedVms.evm]: ITransactionRequest;
}
export interface TransactionResponseTypeMap {
  [SupportedVms.evm]: ITransactionResponse;
}
export interface TransactionReceiptTypeMap {
  [SupportedVms.evm]: ITransactionReceipt;
}

/**
 * Defines the interface for a generic RPC provider for a given VM
 * S = Signer type for the transaction (whats used to sign + send a transaction)
 * B = Block type for the chain (whats returned when block is fetched)
 * T = TransactionResponse type for the chain (whats returned when transaction is submitted)
 * R = TransactionReceipt type for the chain (whats returned when transaction is mined)
 */
export type RpcProvider = {
  // Properties used to calculate priority in aggregator
  name: string;
  priority: number;
  lag: number;
  synced: boolean;
  reliability: number;
  latency: number;
  cps: number;
  syncedBlockNumber: number;

  // Read Methods
  sync(): Promise<void>;
  call: (tx: ReadTransaction, block: number | string) => Promise<string>;
  send: (method: string, params: unknown[]) => Promise<unknown>;
  // Tx methods
  getTransaction: (hash: string) => Promise<ITransactionResponse | undefined>;
  estimateGas: (tx: ReadTransaction | WriteTransaction) => Promise<string>;
  getTransactionReceipt: (hash: string) => Promise<ITransactionReceipt>;
  // Env methods
  getGasPrice: () => Promise<string>;
  getBlock: (block: number | string) => Promise<IBlock>;
  getBlockNumber: () => Promise<number>;
  getCode: (address: string) => Promise<string>;
  // Token / Contract read methods
  getBalance: (address: string, assetId: string) => Promise<string>;
  getDecimals: (address: string) => Promise<number>;
  // Signer Methods
  getTransactionCount: (address: string, block: number | string) => Promise<number>;
  getSigner: (signer: string | ISigner) => Promise<ISigner>;
  connect: (signer: ISigner | string) => Promise<ISigner>;
};

/**
 * Get the VM type from a domain id
 * TODO: should likely move to utils?
 */
export const getVmFromDomainId = (domainId: number): SupportedVm => {
  if (domainId === 0) {
    throw new Error(`Invalid domain id: ${domainId}`);
  }
  switch (domainId) {
    case 728126428:
    case 2494104990:
      return SupportedVms.tvm;
    case 1399811149:
      return SupportedVms.svm;
    default:
      return SupportedVms.evm;
  }
};

/**
 * Returns an RPC provider for the given domain. Must pass in a qualified URL
 * for the given domain.
 */
export const getRpcClient = (domainId: number, urls: string[]): RpcProvider => {
  const vm = getVmFromDomainId(domainId);
  switch (vm) {
    case SupportedVms.evm:
      return getEthRpcProvider(domainId, urls);
    case SupportedVms.tvm:
      return getTronRpcProvider(domainId, urls[0]);
    case SupportedVms.svm:
      return getSolanaRpcProvider(domainId, urls[0]);
    default:
      throw new Error(`Unsupported vm: ${vm}`);
  }
};
