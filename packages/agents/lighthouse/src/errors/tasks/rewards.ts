import { EverclearError } from '@chimera-monorepo/utils';

export class InvalidAddressProof extends EverclearError {
  constructor(
    public readonly addressProof: string[],
    public readonly context: object = {},
  ) {
    super(`Invalid address merkle proof`, { ...context, addressProof });
  }
}

export class InvalidAsset extends EverclearError {
  constructor(
    public readonly address: string,
    public readonly context: object = {},
  ) {
    super(`Invalid asset`, { ...context, address });
  }
}

export class InvalidState extends EverclearError {
  constructor(public readonly context: object = {}) {
    super(`Invalid calculation state`, { ...context });
  }
}

export class NewLockPositionZero extends EverclearError {
  constructor(public readonly context: object = {}) {
    super(`First new lock position is zero`, { ...context });
  }
}

export class UpdateRewardsMetadataTxFailure extends EverclearError {
  constructor(
    public readonly reason: string,
    public readonly context: object = {},
  ) {
    super(`Update rewards metadata tx failed`, { ...context, reason });
  }
}
