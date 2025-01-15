import { Type, Static } from '@sinclair/typebox';

export const TMQConnectionConfig = Type.Object({
  uri: Type.String(),
});

export const TMQExchangeConfig = Type.Object({
  name: Type.String(),
  type: Type.Union([Type.Literal('fanout'), Type.Literal('topic'), Type.Literal('direct')]),
  durable: Type.Boolean(),
});

export const TMQQueueConfig = Type.Object({
  name: Type.String(),
  queueLimit: Type.Optional(Type.Number()),
});

export const TMQBindingConfig = Type.Object({
  exchange: Type.String(),
  target: Type.String(),
  key: Type.String(),
});

export const TMQConfig = Type.Object({
  connection: TMQConnectionConfig,
  exchange: TMQExchangeConfig,
  queues: Type.Array(TMQQueueConfig),
  bindings: Type.Array(TMQBindingConfig),
  prefetchSize: Type.Number(),
});
export type MQConfig = Static<typeof TMQConfig>;

export enum MQStatus {
  None = 'None',
  Enqueued = 'Enqueued',
  Dequeued = 'Dequeued',
  Completed = 'Completed',
}
