import { EverclearError, Values } from '@chimera-monorepo/utils';

export class UnsupportedFeeToken extends EverclearError {
  constructor(token: string, context: any = {}) {
    super('Unsupported fee token', { token, ...context }, UnsupportedFeeToken.name);
  }
}
export class DecodeExecuteError extends EverclearError {
  constructor(context: any = {}) {
    super('Failed to decode execute function data.', context, DecodeExecuteError.name);
  }
}

export class ChainNotSupported extends EverclearError {
  constructor(chain: number, context: any = {}) {
    super(
      'Relayer does not support relaying transactions on this chain.',
      { ...context, chain },
      ChainNotSupported.name,
    );
  }
}

export class ParamsInvalid extends EverclearError {
  constructor(context: any = {}) {
    super('Params for `execute` call were invalid.', context, ParamsInvalid.name);
  }
}

export class ContractDeploymentMissing extends EverclearError {
  public static contracts = {
    everclear: 'Everclear',
  };

  constructor(contract: Values<typeof ContractDeploymentMissing.contracts>, chain: number, context: any = {}) {
    super(
      `Could not find ${contract} contract deployment address for this chain`,
      { chainId: chain, ...context },
      ContractDeploymentMissing.name,
    );
  }
}
