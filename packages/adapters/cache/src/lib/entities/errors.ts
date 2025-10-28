import { EverclearError } from '@chimera-monorepo/utils';

export class RedisClearFailure extends EverclearError {
  constructor(ret: unknown, context: Record<string, unknown> = {}) {
    super(`Failed to clear redis`, { ...context, redisReturn: ret }, RedisClearFailure.name);
  }
}
