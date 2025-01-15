import { Type, Static } from '@sinclair/typebox';
import { TChainConfig as _TChainConfig, THubConfig as _THubConfig, Logger, TABIConfig } from '@chimera-monorepo/utils';

export enum Severity {
  Warning = 'warning',
  Critical = 'critical',
  Informational = 'info',
}

export interface Report {
  severity: Severity;
  type: string;
  domains: string[];
  timestamp: number;
  reason: string;
  logger: Logger;
  env: string;
}

export interface ActionStatus {
  paused: boolean;
  domainId: string;
  needsAction: boolean;
  reason: string;
  tx?: string;
  error?: unknown;
}

export const TRpcProvider = Type.Object({
  url: Type.String(),
  priority: Type.Optional(Type.Number({ minimum: 0 })),
});

export const TChainConfig = Type.Intersect([
  Type.Omit(_TChainConfig, ['providers']),
  Type.Object({
    providers: Type.Array(TRpcProvider),
  }),
  Type.Object({
    gasMultiplier: Type.Number({ minimum: 2, maximum: 10 }),
  }),
]);
export type ChainConfig = Static<typeof TChainConfig>;

export const THubConfig = Type.Intersect([
  Type.Omit(_THubConfig, ['providers']),
  Type.Object({
    providers: Type.Array(TRpcProvider),
  }),
  Type.Object({
    gasMultiplier: Type.Number({ minimum: 2, maximum: 10 }),
  }),
]);
export type HubConfig = Static<typeof THubConfig>;

export const TServerConfig = Type.Object({
  port: Type.Integer({ minimum: 1, maximum: 65535 }),
  host: Type.String({ format: 'ipv4' }),
  adminToken: Type.String(),
});

export const TRedisConfig = Type.Object({
  port: Type.Optional(Type.Integer({ minimum: 1, maximum: 65535 })),
  host: Type.Optional(Type.String()),
});

export const TWatcherConfigSchema = Type.Object({
  chains: Type.Record(Type.String(), TChainConfig),
  hub: THubConfig,
  abis: TABIConfig,
  logLevel: Type.Union([
    Type.Literal('fatal'),
    Type.Literal('error'),
    Type.Literal('warn'),
    Type.Literal('info'),
    Type.Literal('debug'),
    Type.Literal('trace'),
    Type.Literal('silent'),
  ]),
  network: Type.Union([
    Type.Literal('testnet'),
    Type.Literal('mainnet'),
    Type.Literal('local'),
    Type.Literal('devnet'),
  ]),
  web3SignerUrl: Type.Optional(Type.String()),
  redis: TRedisConfig,
  server: TServerConfig,
  environment: Type.Union([Type.Literal('staging'), Type.Literal('production')]),
  reloadConfigInterval: Type.Number({ minimum: 100_000 }),
  assetCheckInterval: Type.Number({ minimum: 5_000, maximum: 500_000 }),
  discordHookUrl: Type.Optional(Type.String({ format: 'uri' })),
  twilio: Type.Object({
    number: Type.Optional(Type.RegEx(/^\+?[1-9]\d{1,14}$/)),
    accountSid: Type.Optional(Type.String()),
    authToken: Type.Optional(Type.String()),
    toPhoneNumbers: Type.Array(Type.RegEx(/^\+?[1-9]\d{1,14}$/)),
  }),
  telegram: Type.Object({
    apiKey: Type.Optional(Type.String()),
    chatId: Type.Optional(Type.String()),
  }),
  betterUptime: Type.Object({
    apiKey: Type.Optional(Type.String()),
    requesterEmail: Type.Optional(Type.String()),
  }),
  failedCheckRetriesLimit: Type.Number({ minimum: 1 }),
});

export type WatcherConfig = Static<typeof TWatcherConfigSchema>;
export type TelegramConfig = Static<typeof TWatcherConfigSchema>['telegram'];
export type BetterUptimeConfig = Static<typeof TWatcherConfigSchema>['betterUptime'];
export type TwillioConfig = Static<typeof TWatcherConfigSchema>['twilio'];
