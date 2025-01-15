import { Type, Static } from '@sinclair/typebox';
import {
  TIntegerString,
  TChainConfig as _TChainConfig,
  THubConfig as _THubConfig,
  TABIConfig,
} from '@chimera-monorepo/utils';

export const TChainConfig = Type.Intersect([
  Type.Omit(_TChainConfig, ['subgraphUrls']),
  Type.Object({
    minGasPrice: Type.Optional(TIntegerString),
  }),
]);
export type ChainConfig = Static<typeof TChainConfig>;

export const THubConfig = Type.Intersect([
  Type.Omit(_THubConfig, ['subgraphUrls']),
  Type.Object({
    minGasPrice: Type.Optional(TIntegerString),
  }),
]);
export type HubConfig = Static<typeof THubConfig>;

export const TServerConfig = Type.Object({
  port: Type.Integer({ minimum: 1, maximum: 65535 }),
  host: Type.String({ format: 'ipv4' }),
  adminToken: Type.String(),
});

export const TPollerConfig = Type.Object({
  port: Type.Integer({ minimum: 1, maximum: 65535 }),
  host: Type.String({ format: 'ipv4' }),
  interval: Type.Integer({ minimum: 100 }),
});

export const TRedisConfig = Type.Object({
  port: Type.Optional(Type.Integer({ minimum: 1, maximum: 65535 })),
  host: Type.Optional(Type.String()),
});

export const TModeConfig = Type.Object({
  cleanup: Type.Boolean(),
});

export const TService = Type.Union([Type.Literal('poller')]);

export const RelayerConfigSchema = Type.Object({
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
  poller: TPollerConfig,
  mode: TModeConfig,
  environment: Type.Union([Type.Literal('staging'), Type.Literal('production')]),
  healthUrls: Type.Partial(Type.Record(TService, Type.String({ format: 'uri' }))),
});

export type RelayerConfig = Static<typeof RelayerConfigSchema>;
