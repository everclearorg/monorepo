import { Type, Static } from '@sinclair/typebox';
import { Logger } from '../logging';
import { AnalyzeWithToolsFn } from './tools/types';

export const TTriageMode = Type.Union([
  Type.Literal('disabled'),
  Type.Literal('dry-run'),
  Type.Literal('shadow'),
  Type.Literal('enabled'),
]);

export const TProviderName = Type.Union([
  Type.Literal('anthropic'),
  Type.Literal('openai'),
]);

export const TTriageRoutingRule = Type.Object({
  match: Type.Object({
    severity: Type.Optional(Type.String()),
    type: Type.Optional(Type.String()),
    minBlastRadius: Type.Optional(Type.Number({ minimum: 1 })),
  }),
  use: Type.Object({
    provider: TProviderName,
    model: Type.String(),
  }),
});

export const TTriageConfigSchema = Type.Object({
  mode: Type.Optional(TTriageMode),
  timeoutMs: Type.Optional(Type.Number({ minimum: 1000 })),
  maxToolRounds: Type.Optional(Type.Number({ minimum: 1, maximum: 5 })),
  perToolTimeoutMs: Type.Optional(Type.Number({ minimum: 1000, maximum: 10000 })),
  lookbackHours: Type.Optional(Type.Number({ minimum: 1 })),
  retentionHours: Type.Optional(Type.Number({ minimum: 1 })),
  timeBucketMinutes: Type.Optional(Type.Number({ minimum: 1 })),
  providers: Type.Optional(
    Type.Object({
      anthropic: Type.Optional(
        Type.Object({
          apiKey: Type.String(),
          model: Type.Optional(Type.String()),
          baseUrl: Type.Optional(Type.String()),
        }),
      ),
      openai: Type.Optional(
        Type.Object({
          apiKey: Type.String(),
          model: Type.Optional(Type.String()),
          baseUrl: Type.Optional(Type.String()),
        }),
      ),
    }),
  ),
  routing: Type.Optional(
    Type.Object({
      default: Type.Object({
        provider: TProviderName,
        model: Type.String(),
      }),
      overrides: Type.Optional(Type.Array(TTriageRoutingRule)),
    }),
  ),
  autoResolve: Type.Optional(
    Type.Object({
      minConfidence: Type.Optional(Type.Number({ minimum: 0, maximum: 1 })),
      allowedTypes: Type.Optional(Type.Array(Type.String())),
      cooldownMinutes: Type.Optional(Type.Number({ minimum: 1 })),
      maxAutoResolvesPerHour: Type.Optional(Type.Number({ minimum: 1 })),
    }),
  ),
  circuitBreaker: Type.Optional(
    Type.Object({
      failureThreshold: Type.Optional(Type.Number({ minimum: 1 })),
      windowMinutes: Type.Optional(Type.Number({ minimum: 1 })),
    }),
  ),
});

export type TriageMode = Static<typeof TTriageMode>;
export type TriageConfig = Static<typeof TTriageConfigSchema>;

export type AlertFingerprint = string;

export type TriageContext = {
  report: {
    severity: string;
    type: string;
    ids: string[];
    timestamp: number;
    reason: string;
    env: string;
  };
  prompt: string;
  logger: Logger;
};

export type TriageResult = {
  verdict: 'actionable' | 'duplicate' | 'transient' | 'unknown';
  rca: string;
  confidence: number;
  steps: string[];
  autoResolveRecommendation: boolean;
  reasoning: string;
};

export type TriageRoute = {
  provider: Static<typeof TProviderName>;
  model: string;
};

export type TriageProvider = {
  name: Static<typeof TProviderName>;
  analyze: (context: TriageContext, model: string, timeoutMs: number) => Promise<TriageResult>;
  analyzeWithTools?: AnalyzeWithToolsFn;
};

export type AutoResolvePolicyDecision = {
  shouldAutoResolve: boolean;
  reasonCode: string;
};

export type TriageProcessingRecord = {
  fingerprint: string;
  reportType: string;
  severity: string;
  env: string;
  network: string;
  ids: string[];
  reason: string;
  triageMode: TriageMode;
  triageResult?: TriageResult;
  providerUsed?: string;
  modelUsed?: string;
  triageLatencyMs?: number;
  autoResolveAttempted?: boolean;
  autoResolveSucceeded?: boolean;
  autoResolveReasonCode?: string;
  toolCallsMade?: number;
  toolNamesUsed?: string[];
  expiresAt: Date;
};

export type TriagePersistenceStore = {
  tryReserve: (record: TriageProcessingRecord) => Promise<boolean>;
  finalize: (record: TriageProcessingRecord) => Promise<void>;
  setAutoResolveOutcome?: (fingerprint: string, succeeded: boolean, reasonCode?: string) => Promise<void>;
  hasProcessed?: (fingerprint: string) => Promise<boolean>;
  pruneExpired?: () => Promise<number>;
};

export const DEFAULT_TRIAGE_CONFIG: Required<
  Pick<
    TriageConfig,
    'mode' | 'timeoutMs' | 'maxToolRounds' | 'perToolTimeoutMs' | 'lookbackHours' | 'retentionHours' | 'timeBucketMinutes'
  >
> = {
  mode: 'disabled',
  timeoutMs: 30000,
  maxToolRounds: 3,
  perToolTimeoutMs: 5000,
  lookbackHours: 6,
  retentionHours: 24,
  timeBucketMinutes: 30,
};
