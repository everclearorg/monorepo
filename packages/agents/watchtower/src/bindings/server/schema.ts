import { AdminSchema, ErrorJsonSchema, TAddress, TIntegerString } from '@chimera-monorepo/utils';
import { Static, Type } from '@sinclair/typebox';

export const PauseRequestSchema = Type.Intersect([AdminSchema, Type.Object({ reason: Type.String() })]);
export type PauseRequest = Static<typeof PauseRequestSchema>;

export const PauseResponseSchema = Type.Array(
  Type.Object({
    paused: Type.Boolean(),
    needsAction: Type.Boolean(),
    domainId: Type.String(),
    reason: Type.Optional(Type.String()),
    tx: Type.Optional(Type.String()),
    error: Type.Optional(Type.Unknown()),
  }),
);
export type PauseResponse = Static<typeof PauseResponseSchema>;

export const WatcherApiErrorResponseSchema = Type.Object({
  message: Type.String(),
  error: Type.Optional(ErrorJsonSchema),
});
export type WatcherApiErrorResponse = Static<typeof WatcherApiErrorResponseSchema>;

export const WatcherErrorSchema = Type.String();

export const BalanceResponseSchema = Type.Object({
  address: TAddress,
  balances: Type.Record(Type.String(), TIntegerString),
});
export type BalanceResponse = Static<typeof BalanceResponseSchema>;
