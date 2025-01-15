/* eslint-disable @typescript-eslint/no-explicit-any */
import { EverclearError } from '@chimera-monorepo/utils';
import { LighthouseConfig } from '../../config';

export class NoGatewayConfigured extends EverclearError {
  constructor(
    public readonly domain: string = '',
    public readonly config: LighthouseConfig['chains'],
    context: any = {},
  ) {
    super(`Missing gateway deployment`, { config, domain, ...context });
  }
}
