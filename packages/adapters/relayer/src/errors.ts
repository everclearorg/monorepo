import { EverclearError } from '@chimera-monorepo/utils';

export class RelayerSendFailed extends EverclearError {
  constructor(context: any = {}) {
    super(`Relayer Send Failed`, context, RelayerSendFailed.name);
  }
}

export class UnableToGetTaskStatus extends EverclearError {
  constructor(taskId: string, context: any = {}) {
    super(`Unable to get task status`, { ...context, taskId }, UnableToGetTaskStatus.name);
  }
}

export class UnableToGetGelatoSupportedChains extends EverclearError {
  constructor(chainId: number, context: any = {}) {
    super(`Unable to get chains from gelato`, { ...context, chainId }, UnableToGetGelatoSupportedChains.name);
  }
}

export class UnableToGetTransactionHash extends EverclearError {
  constructor(taskId: string, context: any = {}) {
    super(`Unable to get transaction hash`, { ...context, taskId }, UnableToGetTransactionHash.name);
  }
}

export class TransactionHashTimeout extends EverclearError {
  constructor(taskId: string, context: any = {}) {
    super(`Timed out waiting for transaction hash`, { ...context, taskId }, TransactionHashTimeout.name);
  }
}
