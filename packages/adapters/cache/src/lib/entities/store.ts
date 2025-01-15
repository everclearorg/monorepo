import { Redis } from 'ioredis';

export type StoreManagerParams = {
  redis: { host: string | undefined; port: number | undefined; instance?: Redis };
  mock?: boolean;
};
