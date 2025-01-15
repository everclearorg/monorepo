import { EverclearError, QueueType } from '@chimera-monorepo/utils';
import { LighthouseConfig } from '../../config';

/**
 * NOTE: may not be specific to just the spoke queue, could be relevant to all queues
 */
export class MissingThresholds extends EverclearError {
  constructor(
    public readonly queue: QueueType,
    public readonly domain: string,
    public readonly config: LighthouseConfig['thresholds'],
  ) {
    super(`Missing threshold for domain`, { queue, config, domain });
  }
}

export class UnknownQueueType extends EverclearError {
  constructor(
    public readonly type: string,
    public readonly context: object = {},
  ) {
    super(`Unknown queue type`, { ...context, type });
  }
}

export class UnsupportedSpokeQueue extends EverclearError {
  constructor(
    public readonly type: string,
    public readonly context: object = {},
  ) {
    super(`Unsupported spoke queue type`, { ...context, type });
  }
}
