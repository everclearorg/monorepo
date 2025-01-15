import { Type, Static } from '@sinclair/typebox';

import { RelayerTaskStatus } from './relayer';
import { ErrorJsonSchema } from './error';
import { TelemetryType } from './telemetry';

/// Shared API
export const AdminSchema = Type.Object({
  adminToken: Type.String(),
  additions: Type.Optional(Type.Any()),
});
export type AdminRequest = Static<typeof AdminSchema>;

export const ClearCacheRequestSchema = AdminSchema;
export type ClearCacheRequest = Static<typeof ClearCacheRequestSchema>;

/// Relayer API ------------------------------------------------------------------------------

export const RelayerApiFeeSchema = Type.Object({
  chain: Type.Integer(),
  amount: Type.String(),
  token: Type.String(),
});
export type RelayerApiFee = Static<typeof RelayerApiFeeSchema>;

export const RelayerApiPostTaskRequestParamsSchema = Type.Object({
  to: Type.String(),
  data: Type.String(),
  fee: RelayerApiFeeSchema,
  apiKey: Type.String(),
});
export type RelayerApiPostTaskRequestParams = Static<typeof RelayerApiPostTaskRequestParamsSchema>;

export const RelayerApiPostTaskResponseSchema = Type.Object({
  message: Type.String(),
  taskId: Type.String(),
});
export type RelayerApiPostTaskResponse = Static<typeof RelayerApiPostTaskResponseSchema>;

export const RelayerApiErrorResponseSchema = Type.Object({
  message: Type.String(),
  error: Type.Optional(ErrorJsonSchema),
});
export type RelayerApiErrorResponse = Static<typeof RelayerApiErrorResponseSchema>;

export const RelayerApiStatusResponseSchema = Type.Object({
  chain: Type.String(),
  taskId: Type.String(),
  status: Type.Enum(RelayerTaskStatus),
  error: Type.String(),
});
export type RelayerApiStatusResponse = Static<typeof RelayerApiStatusResponseSchema>;

export const TelemetryPostRequestSchema = Type.Object({
  from: Type.String(),
  status: Type.Number(),
  type: Type.Enum(TelemetryType),
  message: Type.String(),
  data: Type.Any(),
  timestamp: Type.Number(),
  signed: Type.String(),
});
export type TelemetryPostRequest = Static<typeof TelemetryPostRequestSchema>;
