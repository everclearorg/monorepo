/* eslint-disable @typescript-eslint/no-unused-vars */
import {
  Asset,
  DepositorEvent,
  DepositQueue,
  DestinationIntent,
  HubDeposit,
  HubIntent,
  HubInvoice,
  HubMessage,
  HubMeta,
  jsonifyError,
  Message,
  Order,
  OriginIntent,
  ProtocolUpdateLog,
  Queue,
  SettlementIntent,
  SpokeMeta,
  TIntentStatus,
  Token,
  HubTokenUpdateLog,
  HubAssetUpdateLog,
} from '@chimera-monorepo/utils';
import { getHelpers } from '../lib/helpers';
import { RuntimeError } from '../lib/errors';
import { EnvioIntentEntity } from '../lib/helpers/parse';
import { ISubgraphReader } from '../reader';
import {
  getEnvioIntentByIdQuery,
  getEnvioIntentsQuery,
  QueryResponse,
  SubgraphConfig,
  SubgraphQueryMetaParams,
} from '../lib';

let context: { config: SubgraphConfig };
export const getContext = () => context;

/**
 * EnvioReader - Reader for Envio HyperIndex
 *
 * Unlike Goldsky subgraphs which are domain-specific, Envio provides a single
 * subgraph per environment (mainnet-staging, mainnet-prod) that covers all domains.
 *
 * Note: Envio only tracks spoke contracts (IntentAdded/IntentFilled events),
 * so hub-specific methods return empty arrays or throw errors.
 */
export class EnvioReader implements ISubgraphReader {
  private static instance: EnvioReader | undefined;

  private constructor(config: SubgraphConfig) {
    context = { config };
  }

  public static create(config: SubgraphConfig): EnvioReader {
    if (EnvioReader.instance) {
      return EnvioReader.instance;
    }

    EnvioReader.instance = new EnvioReader(config);
    return EnvioReader.instance;
  }

  /**
   * Query Envio HyperIndex (multichain, environment-specific subgraph)
   * Unlike Goldsky subgraphs which are domain-specific, Envio provides a single
   * subgraph per environment (mainnet-staging, mainnet-prod) that covers all domains.
   *
   * @param query - GraphQL query string
   * @param variables - Optional query variables
   * @returns Query result
   */
  public async queryEnvio<T = Record<string, unknown>>(
    query: string,
    variables?: Record<string, unknown>,
  ): Promise<T | undefined> {
    const { executeEnvioQuery } = getHelpers();
    const { config } = getContext();

    if (!config.envio?.url) {
      throw new Error('Envio configuration is missing. Please provide envio.url in SubgraphConfig.');
    }

    try {
      return await executeEnvioQuery<T>(config, query, variables);
    } catch (e: unknown) {
      console.error(jsonifyError(e as Error));
      throw new RuntimeError(e as Record<string, unknown>);
    }
  }

  /**
   * Make a direct GraphQL query to the subgraph of the given domain.
   * For Envio, the domain is ignored as it's multichain.
   *
   * @param domain - Domain (ignored for Envio, kept for interface compatibility)
   * @param queries - The GraphQL query strings you want to send
   * @returns Query result
   */
  public async query<T>(domain: string, queries: string[]): Promise<QueryResponse<T> | undefined> {
    // Envio is multichain, so we combine queries and execute against Envio
    // For now, we'll execute the first query (Envio doesn't support batching like Goldsky)
    if (queries.length === 0) {
      return undefined;
    }

    try {
      const result = await this.queryEnvio<T>(queries[0]);
      return { data: result as T, domain } as QueryResponse<T>;
    } catch (e: unknown) {
      console.error(jsonifyError(e as Error));
      throw new RuntimeError(e as Record<string, unknown>);
    }
  }

  public async getLatestBlockNumber(domains: string[]): Promise<Map<string, number>> {
    const result: Map<string, number> = new Map();

    for (const domain of domains) {
      try {
        const blockNumber = await this.getEnvioLatestBlockNumber(domain);
        if (blockNumber !== undefined) {
          result.set(domain, blockNumber);
        }
      } catch (e: unknown) {
        console.error(jsonifyError(e as Error), { domain });
      }
    }

    return result;
  }

  public async getOriginIntentById(domain: string, intentId: string): Promise<OriginIntent | undefined> {
    return this.getEnvioOriginIntentById(intentId, domain);
  }

  public async getDestinationIntentById(domain: string, intentId: string): Promise<DestinationIntent | undefined> {
    return this.getEnvioDestinationIntentById(intentId, domain);
  }

  public async getHubIntentById(_domain: string, _intentId: string): Promise<HubIntent | undefined> {
    // Envio only tracks spoke contracts, not hub contracts
    return undefined;
  }

  public async getHubInvoiceById(_domain: string, _intentId: string): Promise<HubInvoice | undefined> {
    // Envio only tracks spoke contracts, not hub contracts
    return undefined;
  }

  public async getSettlementIntentById(_domain: string, _intentId: string): Promise<SettlementIntent | undefined> {
    // Envio doesn't track settlement intents by ID
    return undefined;
  }

  public async getHubDepositEnqueuedById(
    _domain: string,
    _intentId: string,
  ): Promise<(HubDeposit & { status: TIntentStatus }) | undefined> {
    // Envio only tracks spoke contracts, not hub contracts
    return undefined;
  }

  public async getHubDepositProcessedById(
    _domain: string,
    _intentId: string,
  ): Promise<(HubDeposit & { status: TIntentStatus }) | undefined> {
    // Envio only tracks spoke contracts, not hub contracts
    return undefined;
  }

  public async getDepositorEvents(_domain: string, _latestNonce: number): Promise<DepositorEvent[]> {
    // Envio doesn't track depositor events
    return [];
  }

  public async getTokens(_hubDomain: string): Promise<[Token[], Asset[]]> {
    // Envio doesn't track tokens/assets
    return [[], []];
  }

  public async getSpokeQueues(_domain: string): Promise<Queue[]> {
    // Envio doesn't track queues
    return [];
  }

  public async getSettlementQueues(_hubDomain: string): Promise<Queue[]> {
    // Envio doesn't track settlement queues
    return [];
  }

  public async getDepositQueues(_hubDomain: string, _fromBlock: number): Promise<DepositQueue[]> {
    // Envio doesn't track deposit queues
    return [];
  }

  public async getDepositsEnqueuedByNonce(
    _hubDomain: string,
    _enqueuedLatestNonce: number,
    _maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    // Envio doesn't track deposits
    return [];
  }

  public async getDepositsProcessedByNonce(
    _hubDomain: string,
    _processedLatestNonce: number,
    _maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    // Envio doesn't track deposits
    return [];
  }

  public async getSpokeMessages(_domain: string, _latestNonce: number): Promise<Message[]> {
    // Envio doesn't track messages
    return [];
  }

  public async getHubMessages(_domain: string, _latestNonce: number): Promise<HubMessage[]> {
    // Envio doesn't track hub messages
    return [];
  }

  public async getHubMeta(_domain: string): Promise<HubMeta | undefined> {
    // Envio doesn't track hub meta
    return undefined;
  }

  public async getSpokeMeta(_domain: string): Promise<SpokeMeta | undefined> {
    // Envio doesn't track spoke meta
    return undefined;
  }

  public async getHubMetaUpdates(_domain: string, _fromBlock: number): Promise<ProtocolUpdateLog[]> {
    return [];
  }

  public async getSpokeMetaUpdates(_domain: string, _fromBlock: number): Promise<ProtocolUpdateLog[]> {
    return [];
  }

  public async getHubTokenUpdates(_domain: string, _fromBlock: number): Promise<HubTokenUpdateLog[]> {
    // Envio doesn't track hub token update logs
    return [];
  }

  public async getHubAssetUpdates(_domain: string, _fromBlock: number): Promise<HubAssetUpdateLog[]> {
    // Envio doesn't track hub asset update logs
    return [];
  }

  public async getOriginIntentsByNonce(queryParams: Map<string, SubgraphQueryMetaParams>): Promise<OriginIntent[]> {
    const allIntents: OriginIntent[] = [];

    for (const [domain, params] of queryParams.entries()) {
      try {
        const intents = await this.getEnvioOriginIntentsByNonce(
          [domain],
          params.latestNonce,
          params.maxBlockNumber,
          params.limit || 200,
        );
        allIntents.push(...intents);
      } catch (e: unknown) {
        console.error(jsonifyError(e as Error), { domain });
        // Continue with other domains
      }
    }

    return allIntents;
  }

  public async getSettlementIntentsByNonce(
    _queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<SettlementIntent[]> {
    // Envio doesn't track settlement intents
    return [];
  }

  public async getDestinationIntentsByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<DestinationIntent[]> {
    const allIntents: DestinationIntent[] = [];

    for (const [domain, params] of queryParams.entries()) {
      try {
        // Envio doesn't track txNonce, so we use blockNumber filtering
        // latestNonce is ignored, we filter by maxBlockNumber only
        const intents = await this.getEnvioDestinationIntentsByNonce(
          [domain],
          undefined, // fromBlockNumber - not using latestNonce
          params.maxBlockNumber,
          params.limit || 200,
        );
        allIntents.push(...intents);
      } catch (e: unknown) {
        console.error(jsonifyError(e as Error), { domain });
        // Continue with other domains
      }
    }

    return allIntents;
  }

  public async getHubIntentsByNonce(
    _domain: string,
    _addedLatestNonce: number,
    _filledLatestNonce: number,
    _enqueuedLatestNonce: number,
    _maxBlockNumber: number,
  ): Promise<[HubIntent[], HubIntent[], HubIntent[]]> {
    // Envio doesn't track hub intents
    return [[], [], []];
  }

  public async getHubInvoicesByNonce(
    _domain: string,
    _enqueuedLatestNonce: number,
    _maxBlockNumber: number,
  ): Promise<[HubInvoice[], HubIntent[]]> {
    // Envio doesn't track hub invoices
    return [[], []];
  }

  public async getOrdersByNonce(
    _queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<(Order & { domain: string })[]> {
    // Envio doesn't track orders
    return [];
  }

  // ============================================================================
  // ENVIO-SPECIFIC METHODS (not part of ISubgraphReader interface)
  // ============================================================================

  /**
   * Get origin intent by ID from Envio HyperIndex
   * Equivalent to getOriginIntentById but queries multichain Envio subgraph
   */
  public async getEnvioOriginIntentById(intentId: string, originDomain?: string): Promise<OriginIntent | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{ Intent: EnvioIntentEntity[] }>(getEnvioIntentByIdQuery(), { intentId });

    if (!result?.Intent || result.Intent.length === 0) {
      return undefined;
    }

    const envioIntent = result.Intent[0];
    // Filter by origin domain if provided
    if (originDomain && envioIntent.origin.toString() !== originDomain) {
      return undefined;
    }

    return parser.envioToOriginIntent(envioIntent, originDomain);
  }

  /**
   * Get destination intent by ID from Envio HyperIndex
   * Equivalent to getDestinationIntentById but queries multichain Envio subgraph
   */
  public async getEnvioDestinationIntentById(
    intentId: string,
    destinationDomain: string,
  ): Promise<DestinationIntent | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{ Intent: EnvioIntentEntity[] }>(getEnvioIntentByIdQuery(), { intentId });

    if (!result?.Intent || result.Intent.length === 0) {
      return undefined;
    }

    const envioIntent = result.Intent[0];
    // Check if this intent has the destination domain
    if (!envioIntent.destinations.includes(parseInt(destinationDomain, 10))) {
      return undefined;
    }

    return parser.envioToDestinationIntent(envioIntent, destinationDomain);
  }

  /**
   * Get origin intents by nonce from Envio HyperIndex
   * Equivalent to getOriginIntentsByNonce but queries multichain Envio subgraph
   * Note: Envio doesn't use txNonce, so we use blockNumber/timestamp for filtering
   */
  public async getEnvioOriginIntentsByNonce(
    originDomains: string[],
    fromBlockNumber?: number,
    maxBlockNumber?: number,
    limit: number = 200,
  ): Promise<OriginIntent[]> {
    const { parser } = getHelpers();

    const where: Record<string, unknown> = {
      status: { _eq: 'ADDED' },
    };

    if (originDomains.length > 0) {
      where.origin = { _in: originDomains.map((d) => parseInt(d, 10)) };
    }

    if (fromBlockNumber) {
      where.blockNumber = { _gt: fromBlockNumber.toString() };
    }

    if (maxBlockNumber) {
      where.blockNumber = {
        ...(where.blockNumber as Record<string, unknown>),
        _lte: maxBlockNumber.toString(),
      };
    }

    const query = getEnvioIntentsQuery('blockNumber', 'asc');
    const result = await this.queryEnvio<{ Intent: EnvioIntentEntity[] }>(query, {
      where,
      limit,
      offset: 0,
      orderBy: [{ blockNumber: 'asc' }],
    });

    if (!result?.Intent) {
      return [];
    }

    return result.Intent.map((intent) => {
      const originDomain = intent.origin.toString();
      if (originDomains.length > 0 && !originDomains.includes(originDomain)) {
        return null;
      }
      return parser.envioToOriginIntent(intent, originDomain);
    }).filter((intent): intent is OriginIntent => intent !== null);
  }

  /**
   * Get destination intents by nonce from Envio HyperIndex
   * Equivalent to getDestinationIntentsByNonce but queries multichain Envio subgraph
   */
  public async getEnvioDestinationIntentsByNonce(
    destinationDomains: string[],
    fromBlockNumber?: number,
    maxBlockNumber?: number,
    limit: number = 200,
  ): Promise<DestinationIntent[]> {
    const { parser } = getHelpers();

    const where: Record<string, unknown> = {
      status: { _eq: 'FILLED' },
    };

    // Filter by destinations array - check if intent has the destination domain
    if (destinationDomains.length > 0) {
      // Use _has_keys_any for array contains check, or try _contains
      // Note: Hasura might use different syntax for array contains
      where.destinations = {
        _contains: destinationDomains.map((d) => parseInt(d, 10)),
      };
    }

    if (fromBlockNumber) {
      where.blockNumber = { _gt: fromBlockNumber.toString() };
    }

    if (maxBlockNumber) {
      where.blockNumber = {
        ...(where.blockNumber as Record<string, unknown>),
        _lte: maxBlockNumber.toString(),
      };
    }

    const query = getEnvioIntentsQuery('blockNumber', 'asc');
    const result = await this.queryEnvio<{ Intent: EnvioIntentEntity[] }>(query, {
      where,
      limit,
      offset: 0,
      orderBy: [{ blockNumber: 'asc' }],
    });

    if (!result?.Intent) {
      return [];
    }

    const destinationIntents: DestinationIntent[] = [];
    for (const intent of result.Intent) {
      // Only process intents that have fills
      if (!intent.fills || intent.fills.length === 0) {
        continue;
      }

      // If no specific destination domains, use all destinations from the intent
      const domainsToCheck = destinationDomains.length > 0 ? destinationDomains : intent.destinations.map(String);

      for (const destDomain of domainsToCheck) {
        // Check if this intent has a fill for this destination domain
        // The fill's chainId should match the destination domain
        const hasFillForDomain = intent.fills.some((fill) => fill.chainId.toString() === destDomain);

        if (hasFillForDomain) {
          const destIntent = parser.envioToDestinationIntent(intent, destDomain);
          if (destIntent) {
            destinationIntents.push(destIntent);
          }
        }
      }
    }

    return destinationIntents;
  }

  /**
   * Get the latest block number from Envio HyperIndex
   * Note: Envio is multichain, so this returns the latest block across all chains
   * or for a specific chain if a domain is provided
   */
  public async getEnvioLatestBlockNumber(domain?: string): Promise<number | undefined> {
    const where: Record<string, unknown> = {};

    if (domain) {
      where.origin = { _eq: parseInt(domain, 10) };
    }

    const query = getEnvioIntentsQuery('blockNumber', 'desc');
    const result = await this.queryEnvio<{ Intent: EnvioIntentEntity[] }>(query, {
      where,
      limit: 1,
      offset: 0,
      orderBy: [{ blockNumber: 'desc' }],
    });

    if (!result?.Intent || result.Intent.length === 0) {
      return undefined;
    }

    return parseInt(result.Intent[0].blockNumber, 10);
  }
}
