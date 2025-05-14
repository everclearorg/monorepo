import { Type, Static } from '@sinclair/typebox';
import {
  TChainConfig,
  THubConfig,
  TOptionalPeripheralConfig,
  TUrl,
  TABIConfig,
  Logger,
  TThresholdsConfig,
  TRelayerConfig,
  TLogLevel,
  TSolanaConfig,
} from '@chimera-monorepo/utils';

// Extend the chain config to include gas threshold properties
export const TExtendedChainConfig = Type.Intersect([
  TChainConfig,
  Type.Object({
    minGasOnRelayer: Type.Optional(Type.Number()),
    minGasOnGateway: Type.Optional(Type.Number()),
    maxDelayedSubgraphBlock: Type.Optional(Type.Number()),
  }),
]);

// Extend the hub config to include gas threshold properties
export const TExtendedHubConfig = Type.Intersect([
  THubConfig,
  Type.Object({
    minGasOnRelayer: Type.Optional(Type.Number()),
    minGasOnGateway: Type.Optional(Type.Number()),
    maxDelayedSubgraphBlock: Type.Optional(Type.Number()),
  }),
]);

export enum CheckItem {
  All = 'all',
  Agent = 'agent',
  Chain = 'chain',
}

export enum Severity {
  Warning = 'warning',
  Critical = 'critical',
  Informational = 'info',
}

export interface Report {
  severity: Severity;
  type: string;
  ids: string[]; // domain, ticker hashes, etc. dependent on the check
  timestamp: number;
  reason: string;
  logger: Logger;
  env: string;
}

export const TAgents = Type.Record(Type.String(), TUrl);

export const TService = Type.Union([Type.Literal('poller')]);

export const TServerConfig = Type.Object({
  port: Type.Integer({ minimum: 1, maximum: 65535 }),
  host: Type.String(),
  adminToken: Type.String(),
});

export const TMonitorConfigSchema = Type.Object({
  environment: Type.String(),
  network: Type.String(),
  hub: TExtendedHubConfig,
  chains: Type.Record(Type.String(), TExtendedChainConfig),
  agents: TAgents,
  redis: TOptionalPeripheralConfig,
  server: TServerConfig,
  logLevel: TLogLevel,
  polling: Type.Object({
    agent: Type.Number(),
    config: Type.Number(),
  }),
  abis: TABIConfig,
  database: Type.Object({
    url: Type.String(),
  }),
  relayers: Type.Array(TRelayerConfig),
  thresholds: TThresholdsConfig,
  telegram: Type.Optional(
    Type.Object({
      apiKey: Type.Optional(Type.String()),
      chatId: Type.Optional(Type.String()),
    }),
  ),
  betterUptime: Type.Optional(
    Type.Object({
      apiKey: Type.Optional(Type.String()),
      requesterEmail: Type.Optional(Type.String()),
    }),
  ),
  discord: Type.Optional(
    Type.Object({
      url: Type.String(),
    }),
  ),
  healthUrls: Type.Partial(Type.Record(TService, Type.String({ format: 'uri' }))),
  tokenomicsTables: Type.Optional(Type.Array(Type.String())),
  solana: TSolanaConfig,
});

// Type definitions for the extended configs
export type ExtendedChainConfig = Static<typeof TExtendedChainConfig>;
export type ExtendedHubConfig = Static<typeof TExtendedHubConfig>;

export type MonitorConfig = Static<typeof TMonitorConfigSchema> & {
  chains: Record<string, ExtendedChainConfig>;
  hub: ExtendedHubConfig;
};

export type TelegramConfig = Static<typeof TMonitorConfigSchema>['telegram'];
export type BetterUptimeConfig = Static<typeof TMonitorConfigSchema>['betterUptime'];
