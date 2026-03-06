import { Type, Static } from '@sinclair/typebox';

import { TBytes32 } from './primitives';

export const ExecutorDataSchema = Type.Object({
  executorVersion: Type.String(),
  transferId: TBytes32,
  origin: Type.String(),
  encodedData: Type.String(),
});

export type ExecutorData = Static<typeof ExecutorDataSchema>;

export enum RelayerTaskStatus {
  CheckPending = 'CheckPending',
  ExecPending = 'ExecPending',
  ExecSuccess = 'ExecSuccess',
  ExecReverted = 'ExecReverted',
  WaitingForConfirmation = 'WaitingForConfirmation',
  Blacklisted = 'Blacklisted',
  Cancelled = 'Cancelled',
  NotFound = 'NotFound',
}

export enum RelayerType {
  Gelato = 'Gelato',
  Everclear = 'Everclear',
  Mock = 'Mock',
}

// Record of important data for any meta tx.
export type MetaTxTask = {
  // Timestamp of when execution meta tx was sent.
  timestamp: string;
  // task ID.
  taskId: string;
  // Number of meta tx attempts sent. Should be 1 in 99% of cases.
  attempts: number;
};

// @deprecated - Legacy Gelato Relay SDK types. Use @gelatocloud/gasless SDK types instead.
// Kept for backward compatibility.
export type RelayerRequest = {
  chainId: bigint;
  target: string;
  data: string;
  feeToken?: string;
};

// @deprecated - Use @gelatocloud/gasless sendTransaction({ chainId, to, data }) instead.
export type RelayerSyncFeeRequest = {
  chainId: bigint;
  target: string;
  data: string;
  isRelayContext?: boolean | undefined;
  feeToken: string;
};

// @deprecated - Gasless SDK returns task ID as string directly from sendTransaction().
export type RelayResponse = {
  taskId: string;
};

// @deprecated - Gasless SDK no longer supports per-call options. Configure at client creation.
export type RelayRequestOptions = {
  gasLimit?: bigint;
  retries?: number;
};
