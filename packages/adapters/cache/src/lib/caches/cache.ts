import Redis from 'ioredis';

import { CacheParams, RedisClearFailure } from '../entities';

/**
 * @classdesc Manages storage, updates, and retrieval of a set of data determined by use-case.
 */
export abstract class Cache {
  protected readonly data!: Redis;

  constructor({ host, port, mock }: CacheParams) {
    if (mock) {
      const IoRedisMock = require('ioredis-mock');
      this.data = new IoRedisMock();
    } else {
      this.data = new Redis({
        host: host,
        port: port,
        connectTimeout: 17000,
        maxRetriesPerRequest: 4,
        retryStrategy: (times) => Math.min(times * 30, 1000),
      });
    }
  }

  /**
   * Flushes the entire cache.
   *
   * @returns string "OK"
   */
  public async clear(): Promise<void> {
    const ret = await this.data.flushall();
    if (ret !== 'OK') {
      throw new RedisClearFailure(ret);
    }
    return;
  }
}
