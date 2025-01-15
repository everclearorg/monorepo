import { Signer, providers } from 'ethers';
import {
  ReadTransaction,
  WriteTransaction,
  IBlock,
  ISigner,
  ITransactionResponse,
  ITransactionReceipt,
} from '../types';
import { getEthRpcProvider } from './eth';
export { SyncProvider } from './eth';

// VM Type mappings
// NOTE: to add a new VM type, add a new key in all the mappings so its properly typed
// on `getRpcClient` return values.
// NOTE: These can be used to strongly type the RpcProvider responses
export const SupportedVms = {
  evm: 'evm',
} as const;
export type SupportedVm = (typeof SupportedVms)[keyof typeof SupportedVms];

export interface SignerTypeMaps {
  [SupportedVms.evm]: Signer;
}
export interface BlockTypeMap {
  [SupportedVms.evm]: providers.Block;
}

export interface TransactionRequestTypeMap {
  [SupportedVms.evm]: providers.TransactionRequest;
}
export interface TransactionResponseTypeMap {
  [SupportedVms.evm]: providers.TransactionResponse;
}
export interface TransactionReceiptTypeMap {
  [SupportedVms.evm]: providers.TransactionReceipt;
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
  prepareRequest: (method: string, params: unknown) => [string, unknown[]];
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
  getSigner: (signer: string | ISigner) => ISigner;
  connect: (signer: ISigner | string) => ISigner;
};

/**
 * Get the VM type from a domain id
 * TODO: should likely move to utils?
 */
export const getVmFromDomainId = (domainId: number): SupportedVm => {
  if (domainId === 0) {
    throw new Error(`Invalid domain id: ${domainId}`);
  }
  return 'evm';
};

/**
 * Returns an RPC provider for the given domain. Must pass in a qualified URL
 * for the given domain.
 */
export const getRpcClient = (domainId: number, url: string): RpcProvider => {
  const vm = getVmFromDomainId(domainId);
  switch (vm) {
    case SupportedVms.evm:
      return getEthRpcProvider(domainId, url);
    default:
      throw new Error(`Unsupported vm: ${vm}`);
  }
};
