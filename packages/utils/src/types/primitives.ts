import { Type, Static } from '@sinclair/typebox';

// strings aliases: these function more as documentation for devs than checked types
export type Address = string; // aka HexString of length 42
export type HexString = string; // eg "0xabc123" of arbitrary length
export type PublicIdentifier = string; // "vector" + base58(<publicKey>)
export type PublicKey = string; // aka HexString of length 132
export type PrivateKey = string; // aka Bytes32
export type SignatureString = string; // aka HexString of length 132
export type UrlString = string; // eg "<protocol>://<host>[:<port>]/<path>

// String pattern types
export const TAddress = Type.RegEx(/^0x[a-fA-F0-9]{40}$/);
export const TBytes32 = Type.RegEx(/^0x[a-fA-F0-9]{64}$/);
export const TIntegerString = Type.RegEx(/^([0-9])*$/);
export const TUrl = Type.String({ format: 'uri' });
// Convenience types
export const TChainId = Type.Number({ minimum: 1 });
export const TDomainId = Type.String({ maxLength: 66 });
export const TDecimalString = Type.RegEx(/^[0-9]*\.?[0-9]*$/);

export const TAssetConfig = Type.Object({
  symbol: Type.String(),
  address: Type.String(),
  decimals: Type.Number(),
  isNative: Type.Boolean({ default: false }),
  price: Type.Object({
    isStable: Type.Optional(Type.Boolean({ default: false })),
    mainnetEquivalent: Type.Optional(Type.String()),
    priceFeed: Type.Optional(Type.String()), // chainlink price feed
    univ2: Type.Optional(
      Type.Object({
        pair: Type.String(), // univ2 pair address
      }),
    ),
    univ3: Type.Optional(
      Type.Object({
        pool: Type.String(), // univ3 pool address
      }),
    ),
    coingeckoId: Type.Optional(Type.String()),
  }),
  tickerHash: Type.String(),
});
export type AssetConfig = Static<typeof TAssetConfig>;

export const TChainConfig = Type.Object({
  providers: Type.Array(Type.String()),
  gasLimit: Type.Optional(Type.Number()), // defaults to 30M (evm standard)
  subgraphUrls: Type.Array(Type.String()),
  confirmations: Type.Optional(Type.Number()),
  deployments: Type.Optional(
    Type.Object({
      everclear: Type.Optional(Type.String()),
      gateway: Type.Optional(Type.String()),
    }),
  ),
  // keyed on asset ticker
  assets: Type.Optional(Type.Record(Type.String(), TAssetConfig)),
});
export type ChainConfig = Static<typeof TChainConfig>;

export const THubConfig = Type.Object({
  domain: Type.String(),
  providers: Type.Array(Type.String()),
  subgraphUrls: Type.Array(Type.String()),
  confirmations: Type.Optional(Type.Number()),
  deployments: Type.Object({
    gateway: TAddress,
    everclear: TAddress,
    gauge: TAddress,
    rewardDistributor: TAddress,
    tokenomicsHubGateway: TAddress,
  }),
  assets: Type.Optional(Type.Record(Type.String(), TAssetConfig)),
});

export const TOptionalPeripheralConfig = Type.Object({
  port: Type.Optional(Type.Integer({ minimum: 1, maximum: 65535 })),
  host: Type.Optional(Type.String()),
});

export const TABIConfig = Type.Object({
  hub: Type.Object({
    everclear: Type.Any(),
    gateway: Type.Any(),
    gauge: Type.Any(),
    rewardDistributor: Type.Any(),
    tokenomicsHubGateway: Type.Any(),
  }),
  spoke: Type.Object({
    everclear: Type.Any(),
    gateway: Type.Any(),
  }),
});
export type ABIConfig = Static<typeof TABIConfig>;

export const TEverclearConfig = Type.Object({
  chains: Type.Record(Type.String(), TChainConfig),
  hub: THubConfig,
  abis: Type.Optional(TABIConfig),
  monitorUrl: Type.Optional(Type.String()),
});
export type EverclearConfig = Static<typeof TEverclearConfig>;

export type ContractDeployment = {
  address: string;
  startBlock: number;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  abi: any[];
};

export type ChainDeployments = {
  everclear: ContractDeployment;
  gateway: ContractDeployment;
  gauge?: Partial<ContractDeployment>;
  rewardDistributor?: Partial<ContractDeployment>;
  tokenomicsHubGateway?: Partial<ContractDeployment>;
};

export const TLogLevel = Type.Union([
  Type.Literal('fatal'),
  Type.Literal('error'),
  Type.Literal('warn'),
  Type.Literal('info'),
  Type.Literal('debug'),
  Type.Literal('trace'),
  Type.Literal('silent'),
]);

export const TRelayerConfig = Type.Object({
  url: Type.String({ format: 'uri' }),
  type: Type.Union([Type.Literal('Gelato'), Type.Literal('Everclear')]),
  apiKey: Type.String(),
});
export type RelayerConfig = Static<typeof TRelayerConfig>;

export const TThresholdsConfig = Type.Object({
  maxExecutionQueueCount: Type.Optional(Type.Number()),
  maxExecutionQueueLatency: Type.Optional(Type.Number()),
  maxIntentQueueCount: Type.Optional(Type.Number()),
  maxIntentQueueLatency: Type.Optional(Type.Number()),
  openTransferMaxTime: Type.Optional(Type.Number()),
  openTransferInterval: Type.Optional(Type.Number()),
  maxSettlementQueueCount: Type.Optional(Type.Number()),
  maxSettlementQueueLatency: Type.Optional(Type.Number()),
  maxSettlementQueueAssetAmounts: Type.Record(Type.String(), Type.Number()),
  maxDepositQueueCount: Type.Optional(Type.Number()),
  maxDepositQueueLatency: Type.Optional(Type.Number()),
  messageMaxDelay: Type.Optional(Type.Number()),
  maxDelayedSubgraphBlock: Type.Optional(Type.Number()),
  averageElapsedEpochs: Type.Optional(Type.Number()),
  averageElapsedEpochsAlertAmount: Type.Optional(Type.Number()),
  maxInvoiceProcessingTime: Type.Optional(Type.Number()),
  minGasOnRelayer: Type.Optional(Type.Number()),
  minGasOnGateway: Type.Optional(Type.Number()),
  maxShadowExportDelay: Type.Optional(Type.Number()),
  maxShadowExportLatency: Type.Optional(Type.Number()),
  maxTokenomicsExportDelay: Type.Optional(Type.Number()),
  maxTokenomicsExportLatency: Type.Optional(Type.Number()),
});
export type ThresholdsConfig = Static<typeof TThresholdsConfig>;

export const TEnvironment = Type.Union([Type.Literal('local'), Type.Literal('staging'), Type.Literal('production')]);
export type Environment = Static<typeof TEnvironment>;

export const TTokenVolumeReward = Type.Object({
  address: TAddress,
  epochVolumeReward: Type.String(),
  baseRewardDbps: Type.Number(),
  maxBpsUsdVolumeCap: Type.Number(),
});
export type TokenVolumeReward = Static<typeof TTokenVolumeReward>;

export const TVolumeRewardConfig = Type.Object({
  tokens: Type.Array(TTokenVolumeReward),
});

export const TTokenStakingReward = Type.Object({
  address: TAddress,
  apy: Type.Array(
    Type.Object({
      term: Type.Number(),
      apyBps: Type.Number(),
    }),
  ),
});
export type TokenStakingReward = Static<typeof TTokenStakingReward>;

export const TStakingRewardConfig = Type.Object({
  tokens: Type.Array(TTokenStakingReward),
});

export const TRewardConfig = Type.Object({
  clearAssetAddress: TAddress,
  volume: TVolumeRewardConfig,
  staking: TStakingRewardConfig,
});
export type RewardConfig = Static<typeof TRewardConfig>;

export const TSafeConfig = Type.Object({
  txService: Type.String(),
  safeAddress: Type.String(),
  signer: Type.String(),
  masterCopyAddress: Type.String(),
  fallbackHandlerAddress: Type.String(),
});
export type SafeConfig = Static<typeof TSafeConfig>;
