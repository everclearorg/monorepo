/* eslint-disable @typescript-eslint/no-explicit-any */
import { EverclearError } from '@chimera-monorepo/utils';

// Thrown when config doesnt pass schema validation
export class InvalidConfig extends EverclearError {
  constructor(
    public readonly details: string,
    public readonly config: any,
  ) {
    super('Invalid lighthouse config: ' + details, { config, details });
  }
}

// thrown if invalid service provided to lighthouse, likely types
// misalignment
export class InvalidService extends EverclearError {
  constructor(public readonly service: string) {
    super('Invalid service: ' + service);
  }
}
