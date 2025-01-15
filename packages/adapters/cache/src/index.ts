import { TasksCache, MQCache } from './lib/caches';
import { StoreManagerParams } from './lib/entities/store';

export interface Store {
  readonly tasks: TasksCache;
}

export class StoreManager implements Store {
  private static instance: StoreManager | undefined;

  public readonly tasks: TasksCache;
  public readonly mq: MQCache;

  private constructor({ redis, mock }: StoreManagerParams) {
    const { host, port } = redis ?? {};
    this.tasks = new TasksCache({
      host,
      port,
      mock: !!mock,
    });
    this.mq = new MQCache({
      host,
      port,
      mock: !!mock,
    });
  }

  public static getInstance(params: StoreManagerParams): StoreManager {
    if (StoreManager.instance) {
      return StoreManager.instance;
    } else {
      const store = new StoreManager(params);
      StoreManager.instance = store;
      return store;
    }
  }
}

export * from './lib/caches';
