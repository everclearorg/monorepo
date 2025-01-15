import { EverclearError } from '@chimera-monorepo/utils';

export class RedisClearFailure extends EverclearError {
  constructor(ret: any, context: any = {}) {
    super(`Failed to clear redis`, { ...context, redisReturn: ret }, RedisClearFailure.name);
  }
}
