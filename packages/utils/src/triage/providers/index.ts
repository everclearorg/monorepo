import { TriageConfig, TriageProvider, TriageResult, TriageContext } from '../types';
import { AnalyzeWithToolsArgs } from '../tools/types';
import { AnthropicTriageProvider } from './anthropic';
import { OpenAITriageProvider } from './openai';
import { CircuitBreaker, withRetry } from './base';

const breakerCache = new Map<string, CircuitBreaker>();

const getProviderBreaker = (
  provider: 'anthropic' | 'openai',
  failureThreshold: number,
  windowMinutes: number,
): CircuitBreaker => {
  const key = `${provider}:${failureThreshold}:${windowMinutes}`;
  const existing = breakerCache.get(key);
  if (existing) {
    return existing;
  }
  const created = new CircuitBreaker(failureThreshold, windowMinutes * 60_000);
  breakerCache.set(key, created);
  return created;
};

class WrappedProvider implements TriageProvider {
  constructor(
    public readonly name: 'anthropic' | 'openai',
    private readonly delegate: TriageProvider,
    private readonly breaker: CircuitBreaker,
  ) {}

  public async analyze(context: TriageContext, model: string, timeoutMs: number): Promise<TriageResult> {
    if (!this.breaker.canExecute()) {
      throw new Error(`Circuit breaker open for ${this.name}`);
    }
    try {
      const result = await withRetry(() => this.delegate.analyze(context, model, timeoutMs), 2, 300);
      this.breaker.recordSuccess();
      return result;
    } catch (e) {
      this.breaker.recordFailure();
      throw e;
    }
  }

  public async analyzeWithTools(args: AnalyzeWithToolsArgs): Promise<TriageResult> {
    if (!this.breaker.canExecute()) {
      throw new Error(`Circuit breaker open for ${this.name}`);
    }
    if (!this.delegate.analyzeWithTools) {
      return this.analyze(args.context, args.model, args.timeoutMs);
    }
    try {
      const result = await withRetry(() => this.delegate.analyzeWithTools!(args), 2, 300);
      this.breaker.recordSuccess();
      return result;
    } catch (e) {
      this.breaker.recordFailure();
      throw e;
    }
  }
}

export const createTriageProviders = (config?: TriageConfig): Partial<Record<'anthropic' | 'openai', TriageProvider>> => {
  const failureThreshold = config?.circuitBreaker?.failureThreshold ?? 3;
  const windowMinutes = config?.circuitBreaker?.windowMinutes ?? 5;

  const providers: Partial<Record<'anthropic' | 'openai', TriageProvider>> = {};
  if (config?.providers?.anthropic?.apiKey) {
    const breaker = getProviderBreaker('anthropic', failureThreshold, windowMinutes);
    providers.anthropic = new WrappedProvider(
      'anthropic',
      new AnthropicTriageProvider(config.providers.anthropic),
      breaker,
    );
  }
  if (config?.providers?.openai?.apiKey) {
    const breaker = getProviderBreaker('openai', failureThreshold, windowMinutes);
    providers.openai = new WrappedProvider('openai', new OpenAITriageProvider(config.providers.openai), breaker);
  }
  return providers;
};

export * from './anthropic';
export * from './openai';
export * from './base';
