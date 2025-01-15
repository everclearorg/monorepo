import { AdminSchema, ErrorJsonSchema, TIntegerString, TIntentStatus } from '@chimera-monorepo/utils';
import { Type, Static } from '@sinclair/typebox';

export const MonitorApiErrorResponseSchema = Type.Object({
  message: Type.String(),
  error: Type.Optional(ErrorJsonSchema),
});
export type MonitorApiErrorResponse = Static<typeof MonitorApiErrorResponseSchema>;

export const HyperlaneMessageSummarySchema = Type.Object({
  messageId: Type.String(),
  status: Type.String(),
});
export type HyperlaneMessageSummary = Static<typeof HyperlaneMessageSummarySchema>;

export const IntentMessageSummarySchema = Type.Object({
  settlement: HyperlaneMessageSummarySchema,
  fill: HyperlaneMessageSummarySchema,
  add: HyperlaneMessageSummarySchema,
});
export type IntentMessageSummary = Static<typeof IntentMessageSummarySchema>;

export const IntentStatusSummarySchema = Type.Object({
  origin: Type.Enum(TIntentStatus),
  hub: Type.Enum(TIntentStatus),
  destinations: Type.Record(TIntegerString, Type.Enum(TIntentStatus)),
});
export type IntentStatusSummary = Static<typeof IntentStatusSummarySchema>;

export const IntentLiquiditySummarySchema = Type.Object({
  notice: Type.Optional(Type.String()),
  tickerHash: Type.String(),
  elapsedEpochs: Type.Number(),
  discount: Type.Number(),
  invoiceValue: TIntegerString,
  settlementValue: TIntegerString,
  unclaimed: Type.Record(TIntegerString, Type.Object({ custodied: TIntegerString, required: TIntegerString })), // keyed on domain
});
export type IntentLiquiditySummary = Static<typeof IntentLiquiditySummarySchema>;

export const IntentReportResponseSchema = Type.Object({
  intentId: Type.String(),
  status: IntentStatusSummarySchema,
  messages: IntentMessageSummarySchema,
  liquidity: IntentLiquiditySummarySchema,
});
export type IntentReportResponse = Static<typeof IntentReportResponseSchema>;

export const ChainStatusResponseSchema = Type.Array(
  Type.Object({
    domain: Type.String(),
    rpc: Type.Object({
      blockNumber: Type.Number(),
      timestamp: Type.Number(),
    }),
    subgraphBlockNumber: Type.Number(),
  }),
);
export type ChainStatusResponse = Static<typeof ChainStatusResponseSchema>;

export const TelemetryInfoResponseSchema = Type.Record(
  Type.String(),
  Type.Object({
    message: Type.String(),
    status: Type.Number(),
    data: Type.Any(),
    timestamp: Type.Number(),
  }),
);
export type TelemetryInfoResponse = Static<typeof TelemetryInfoResponseSchema>;

export const TokenPriceResponseSchema = Type.Object({
  price: Type.Number(),
});
export type TokenPriceResponse = Static<typeof TokenPriceResponseSchema>;

export const SelfRelaySchema = Type.Intersect([
  AdminSchema,
  Type.Object({
    messageIds: Type.Optional(Type.Array(Type.String())),
  }),
]);
export type SelfRelayRequest = Static<typeof SelfRelaySchema>;

export const SelfRelayResponseSchema = Type.Array(
  Type.Object({
    messageId: Type.Optional(Type.String()),
    taskId: Type.Optional(Type.String()),
    relayerType: Type.Optional(Type.String()),
    error: Type.Optional(Type.Unknown()),
  }),
);
export type SelfRelayResponse = Static<typeof SelfRelayResponseSchema>;

export const CheckGasResponseSchema = Type.Array(
  Type.Object({
    domain: Type.String(),
    relayerAddress: Type.Optional(Type.String()),
    belowRelayerThreshold: Type.Optional(Type.Boolean()),
    relayerGas: Type.Optional(Type.String()),
    gatewayAddress: Type.Optional(Type.String()),
    gatewayGas: Type.Optional(Type.String()),
    belowGatewayThreshold: Type.Optional(Type.Boolean()),
  }),
);
export type CheckGasResponse = Static<typeof CheckGasResponseSchema>;

export const DataExportStatusSchema = Type.Object({
  latestTimestamp: Type.Date(),
  now: Type.Date(),
  diff: Type.Number(),
});
export type DataExportStatus = Static<typeof DataExportStatusSchema>;

export const DataExportLatencySchema = Type.Array(
  Type.Object({
    name: Type.String(),
    latency: Type.Number(),
    blockNumber: Type.Number(),
    transactionHash: Type.String({ maxLength: 66 }),
  }),
);
export type DataExportLatency = Static<typeof DataExportLatencySchema>;
