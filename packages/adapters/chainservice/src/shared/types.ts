export type ReadTransaction = {
  domain: number;
  to: string;
  data: string;
  funcSig: string;
};

export type WriteTransaction = {
  from?: string;
  value: string;
  gasLimit?: string;
  gasPrice?: string;
} & ReadTransaction;

export type Gas = {
  limit: string;
  // v0
  price?: string;
  // v2 (EIP-1559)
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
};

export interface ISignerApi {
  getPublicKey: () => Promise<string>;
  sign: (identifier: string, data: string | Uint8Array) => Promise<string>;
}

// Note: This is the minimum required fields for a block as used in the txservice
export interface ISigner {
  getAddress: () => Promise<string>;
  sendTransaction: (transaction: ITransactionRequest) => Promise<ITransactionResponse>;
  signerApi?: ISignerApi;
}
export interface IBlock {
  hash: string;
  parentHash: string;
  number: number;
  timestamp: number;
}
export interface ITransactionRequest {
  to: string;
  data: string;
  value: string;
  nonce?: number;
  type?: number; // TODO: remove?
  gasLimit?: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  funcSig: string;
  chainId?: number; // Required for EIP-155 transactions (replay protection)
}
export interface ITransactionResponse {
  hash: string;
  confirmations: number;
  nonce: number;
  gasPrice?: bigint;
  gasLimit: bigint;
}

export interface IContractLog {
  blockNumber: number;
  blockHash: string;
  transactionIndex: number;

  removed: boolean;

  address: string;
  data: string;

  topics: Array<string>;

  transactionHash: string;
  logIndex: number;
}
export interface ITransactionReceipt {
  blockNumber: number;
  status?: number;
  transactionHash: string;
  confirmations: number;
  logs: IContractLog[];
}
