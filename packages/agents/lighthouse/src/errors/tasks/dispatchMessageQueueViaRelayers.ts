import { EverclearError, RelayerType, jsonifyError } from '@chimera-monorepo/utils';

export class RelayerSendFailed extends EverclearError {
  constructor(
    public readonly domain: string,
    public readonly relayers: RelayerType[],
    public readonly errors: Error[],
    public readonly context: object = {},
  ) {
    super(`Failed to send transaction via relayers`, {
      domain,
      relayers,
      errors: errors.map(jsonifyError),
      ...context,
    });
  }
}
