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
  Logger,
} from '@chimera-monorepo/utils';
import { getHelpers } from '../lib/helpers';
import { RuntimeError } from '../lib/errors';
import {
  EnvioIntentEntity,
  EnvioHubIntentEntity,
  EnvioHubSettlementEntity,
  EnvioInvoiceEntity,
  EnvioSettlementIntentEntity,
  EnvioDepositEntity,
  EnvioDepositorEventEntity,
  EnvioTokenEntity,
  EnvioHubAssetEntity,
  EnvioQueueEntity,
  EnvioSettlementQueueEntity,
  EnvioDepositQueueEntity,
  EnvioMessageEntity,
  EnvioSettlementMessageEntity,
  EnvioHubMetaEntity,
  EnvioDomainEntity,
  EnvioSpokeMetaEntity,
  EnvioOrderEntity,
} from '../lib/helpers/parse';
import { ISubgraphReader } from '../reader';
import {
  getEnvioIntentByIdQuery,
  getEnvioIntentsQuery,
  getEnvioHubIntentByIdQuery,
  getEnvioHubIntentsAddedQuery,
  getEnvioHubIntentsFilledQuery,
  getEnvioHubSettlementsQuery,
  getEnvioInvoiceByIntentIdQuery,
  getEnvioInvoicesQuery,
  getEnvioSettlementIntentByIdQuery,
  getEnvioSettlementIntentsQuery,
  getEnvioDepositByIntentIdQuery,
  getEnvioDepositsQuery,
  getEnvioDepositQueuesQuery,
  getEnvioDepositorEventsQuery,
  getEnvioTokensQuery,
  getEnvioSpokeQueuesQuery,
  getEnvioSettlementQueuesQuery,
  getEnvioSpokeMessagesQuery,
  getEnvioSettlementMessagesQuery,
  getEnvioHubMetaQuery,
  getEnvioSpokeMetaQuery,
  getEnvioOrdersQuery,
  getEnvioChainMetadataQuery,
  QueryResponse,
  SubgraphConfig,
  SubgraphQueryMetaParams,
} from '../lib';

let context: { config: SubgraphConfig };
export const getContext = () => context;

const logger = new Logger({ name: 'EnvioReader', level: process.env.LOG_LEVEL ?? 'info' });

/**
 * EnvioReader - Reader for Envio HyperIndex
 *
 * Unlike Goldsky subgraphs which are domain-specific, Envio provides a single
 * subgraph per environment (mainnet-staging, mainnet-prod) that covers all domains.
 *
 * Envio now tracks both spoke and hub contracts with full subgraph parity.
 * Only 4 audit-trail methods remain as stubs (getHubMetaUpdates, getSpokeMetaUpdates,
 * getHubTokenUpdates, getHubAssetUpdates) since Envio doesn't have immutable
 * update-log entities.
 */
export class EnvioReader implements ISubgraphReader {
  public readonly readerType = 'envio';
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
      logger.error('Envio query error', undefined, undefined, jsonifyError(e as Error));
      throw new RuntimeError(e as Record<string, unknown>);
    }
  }

  /**
   * Make a direct GraphQL query to the subgraph of the given domain.
   * For Envio, the domain is ignored as it's multichain.
   */
  public async query<T>(domain: string, queries: string[]): Promise<QueryResponse<T> | undefined> {
    if (queries.length === 0) {
      return undefined;
    }

    try {
      const result = await this.queryEnvio<T>(queries[0]);
      return { data: result as T, domain } as QueryResponse<T>;
    } catch (e: unknown) {
      logger.error('Envio query error', undefined, undefined, jsonifyError(e as Error));
      throw new RuntimeError(e as Record<string, unknown>);
    }
  }

  // ============================================================================
  // ISubgraphReader — Block number
  // ============================================================================

  public async getLatestBlockNumber(domains: string[]): Promise<Map<string, number>> {
    const result: Map<string, number> = new Map();

    try {
      const data = await this.queryEnvio<{
        chain_metadata: { chain_id: number; latest_processed_block: number }[];
      }>(getEnvioChainMetadataQuery());

      if (data?.chain_metadata) {
        const domainSet = new Set(domains);
        for (const chain of data.chain_metadata) {
          const domainStr = chain.chain_id.toString();
          if (domainSet.has(domainStr) && chain.latest_processed_block > 0) {
            result.set(domainStr, chain.latest_processed_block);
          }
        }
      }
    } catch (e: unknown) {
      logger.error('Envio query error', undefined, undefined, jsonifyError(e as Error));
    }

    return result;
  }

  // ============================================================================
  // ISubgraphReader — Single entity by ID
  // ============================================================================

  public async getOriginIntentById(domain: string, intentId: string): Promise<OriginIntent | undefined> {
    return this.getEnvioOriginIntentById(intentId, domain);
  }

  public async getDestinationIntentById(domain: string, intentId: string): Promise<DestinationIntent | undefined> {
    return this.getEnvioDestinationIntentById(intentId, domain);
  }

  public async getHubIntentById(domain: string, intentId: string): Promise<HubIntent | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{
      HubIntent: EnvioHubIntentEntity[];
      HubSettlement: EnvioHubSettlementEntity[];
    }>(getEnvioHubIntentByIdQuery(), { intentId: intentId.toLowerCase() });

    if (!result?.HubIntent || result.HubIntent.length === 0) {
      return undefined;
    }

    const settlement = result.HubSettlement?.[0];
    return parser.envioToHubIntent(result.HubIntent[0], settlement, domain);
  }

  public async getHubInvoiceById(domain: string, intentId: string): Promise<HubInvoice | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{
      Invoice: EnvioInvoiceEntity[];
      HubIntent: EnvioHubIntentEntity[];
    }>(getEnvioInvoiceByIntentIdQuery(), { intentId: intentId.toLowerCase() });

    if (!result?.Invoice || result.Invoice.length === 0) {
      return undefined;
    }

    return parser.envioToHubInvoice(result.Invoice[0]);
  }

  public async getSettlementIntentById(domain: string, intentId: string): Promise<SettlementIntent | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{
      SettlementIntent: EnvioSettlementIntentEntity[];
    }>(getEnvioSettlementIntentByIdQuery(), { intentId: intentId.toLowerCase() });

    if (!result?.SettlementIntent || result.SettlementIntent.length === 0) {
      return undefined;
    }

    return parser.envioToSettlementIntent(result.SettlementIntent[0], domain);
  }

  public async getHubDepositEnqueuedById(
    domain: string,
    intentId: string,
  ): Promise<(HubDeposit & { status: TIntentStatus }) | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{
      Deposit: EnvioDepositEntity[];
      HubIntent: EnvioHubIntentEntity[];
    }>(getEnvioDepositByIntentIdQuery(), { intentId: intentId.toLowerCase() });

    if (!result?.Deposit || result.Deposit.length === 0) {
      return undefined;
    }

    const deposit = result.Deposit[0];
    if (!deposit.enqueuedTimestamp) {
      return undefined;
    }

    const hubIntent = result.HubIntent?.[0];
    return parser.envioToHubDepositFromEnqueued(deposit, hubIntent);
  }

  public async getHubDepositProcessedById(
    domain: string,
    intentId: string,
  ): Promise<(HubDeposit & { status: TIntentStatus }) | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{
      Deposit: EnvioDepositEntity[];
      HubIntent: EnvioHubIntentEntity[];
    }>(getEnvioDepositByIntentIdQuery(), { intentId: intentId.toLowerCase() });

    if (!result?.Deposit || result.Deposit.length === 0) {
      return undefined;
    }

    const deposit = result.Deposit[0];
    if (!deposit.processedTimestamp) {
      return undefined;
    }

    const hubIntent = result.HubIntent?.[0];
    return parser.envioToHubDepositFromProcessed(deposit, hubIntent);
  }

  // ============================================================================
  // ISubgraphReader — Spoke entity lists
  // ============================================================================

  public async getDepositorEvents(domain: string, latestNonce: number): Promise<DepositorEvent[]> {
    const { parser } = getHelpers();
    const where: Record<string, unknown> = {
      chainId: { _eq: parseInt(domain, 10) },
      blockNumber: { _gt: latestNonce.toString() },
    };

    const result = await this.queryEnvio<{ DepositorEvent: EnvioDepositorEventEntity[] }>(
      getEnvioDepositorEventsQuery(),
      { where, limit: 200, offset: 0 },
    );

    return (result?.DepositorEvent ?? []).map(parser.envioToDepositorEvent);
  }

  public async getTokens(_hubDomain: string): Promise<[Token[], Asset[]]> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{
      Token: EnvioTokenEntity[];
      HubAsset: EnvioHubAssetEntity[];
    }>(getEnvioTokensQuery());

    const tokens = (result?.Token ?? []).map(parser.envioToToken);
    const assets = (result?.HubAsset ?? []).map(parser.envioToAsset);
    return [tokens, assets];
  }

  public async getSpokeQueues(domain: string): Promise<Queue[]> {
    const { parser } = getHelpers();
    const where = { chainId: { _eq: parseInt(domain, 10) } };

    const result = await this.queryEnvio<{ Queue: EnvioQueueEntity[] }>(getEnvioSpokeQueuesQuery(), { where });

    return (result?.Queue ?? []).map(parser.envioToSpokeQueue);
  }

  public async getSettlementQueues(_hubDomain: string): Promise<Queue[]> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{ SettlementQueue: EnvioSettlementQueueEntity[] }>(
      getEnvioSettlementQueuesQuery(),
    );

    return (result?.SettlementQueue ?? []).map(parser.envioToSettlementQueue);
  }

  public async getDepositQueues(_hubDomain: string, fromBlock: number): Promise<DepositQueue[]> {
    const { parser } = getHelpers();
    const where: Record<string, unknown> = {
      blockNumber: { _gte: fromBlock.toString() },
    };

    const result = await this.queryEnvio<{ DepositQueue: EnvioDepositQueueEntity[] }>(getEnvioDepositQueuesQuery(), {
      where,
      limit: 200,
      offset: 0,
    });

    return (result?.DepositQueue ?? []).map(parser.envioToDepositQueue);
  }

  public async getDepositsEnqueuedByNonce(
    _hubDomain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    const { parser } = getHelpers();
    const where: Record<string, unknown> = {
      enqueuedBlockNumber: {
        _gt: enqueuedLatestNonce.toString(),
        _lte: maxBlockNumber.toString(),
      },
      enqueuedTimestamp: { _is_null: false },
    };

    const result = await this.queryEnvio<{ Deposit: EnvioDepositEntity[] }>(getEnvioDepositsQuery(), {
      where,
      limit: 200,
      offset: 0,
      orderBy: [{ enqueuedBlockNumber: 'asc' }],
    });

    const deposits = result?.Deposit ?? [];
    const hubIntentMap = await this.fetchHubIntentsByDepositIds(deposits);

    return deposits.map((d) => parser.envioToHubDepositFromEnqueued(d, hubIntentMap.get(d.intentId)));
  }

  public async getDepositsProcessedByNonce(
    _hubDomain: string,
    processedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    const { parser } = getHelpers();
    const where: Record<string, unknown> = {
      processedBlockNumber: {
        _gt: processedLatestNonce.toString(),
        _lte: maxBlockNumber.toString(),
      },
      processedTimestamp: { _is_null: false },
    };

    const result = await this.queryEnvio<{ Deposit: EnvioDepositEntity[] }>(getEnvioDepositsQuery(), {
      where,
      limit: 200,
      offset: 0,
      orderBy: [{ processedBlockNumber: 'asc' }],
    });

    const deposits = result?.Deposit ?? [];
    const hubIntentMap = await this.fetchHubIntentsByDepositIds(deposits);

    return deposits.map((d) => parser.envioToHubDepositFromProcessed(d, hubIntentMap.get(d.intentId)));
  }

  public async getSpokeMessages(domain: string, latestNonce: number): Promise<Message[]> {
    const { parser } = getHelpers();
    const where: Record<string, unknown> = {
      chainId: { _eq: parseInt(domain, 10) },
      blockNumber: { _gt: latestNonce.toString() },
    };

    const result = await this.queryEnvio<{ Message: EnvioMessageEntity[] }>(getEnvioSpokeMessagesQuery(), {
      where,
      limit: 200,
      offset: 0,
    });

    return (result?.Message ?? []).map(parser.envioToSpokeMessage);
  }

  public async getHubMessages(domain: string, latestNonce: number): Promise<HubMessage[]> {
    const { parser } = getHelpers();
    const where: Record<string, unknown> = {
      blockNumber: { _gt: latestNonce.toString() },
    };

    const result = await this.queryEnvio<{ SettlementMessage: EnvioSettlementMessageEntity[] }>(
      getEnvioSettlementMessagesQuery(),
      { where, limit: 200, offset: 0 },
    );

    return (result?.SettlementMessage ?? []).map((e) => parser.envioToSettlementMessage(e, domain));
  }

  // ============================================================================
  // ISubgraphReader — Meta
  // ============================================================================

  public async getHubMeta(_domain: string): Promise<HubMeta | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{
      HubMeta: EnvioHubMetaEntity[];
      Domain: EnvioDomainEntity[];
    }>(getEnvioHubMetaQuery());

    if (!result?.HubMeta || result.HubMeta.length === 0) {
      return undefined;
    }

    return parser.envioToHubMeta(result.HubMeta[0], result.Domain ?? []);
  }

  public async getSpokeMeta(domain: string): Promise<SpokeMeta | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{ SpokeMeta: EnvioSpokeMetaEntity[] }>(getEnvioSpokeMetaQuery(), {
      chainId: domain,
    });

    if (!result?.SpokeMeta || result.SpokeMeta.length === 0) {
      return undefined;
    }

    return parser.envioToSpokeMeta(result.SpokeMeta[0]);
  }

  // Audit trail methods — stay as stubs (Envio doesn't have immutable update-log entities)
  public async getHubMetaUpdates(_domain: string, _fromBlock: number): Promise<ProtocolUpdateLog[]> {
    return [];
  }

  public async getSpokeMetaUpdates(_domain: string, _fromBlock: number): Promise<ProtocolUpdateLog[]> {
    return [];
  }

  public async getHubTokenUpdates(_domain: string, _fromBlock: number): Promise<HubTokenUpdateLog[]> {
    return [];
  }

  public async getHubAssetUpdates(_domain: string, _fromBlock: number): Promise<HubAssetUpdateLog[]> {
    return [];
  }

  // ============================================================================
  // ISubgraphReader — Batch queries by nonce
  // ============================================================================

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
        logger.error('Envio query error', undefined, undefined, jsonifyError(e as Error), { domain });
      }
    }

    return allIntents;
  }

  public async getSettlementIntentsByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<SettlementIntent[]> {
    const { parser } = getHelpers();
    const allIntents: SettlementIntent[] = [];

    for (const [domain, params] of queryParams.entries()) {
      try {
        const where: Record<string, unknown> = {
          settlementBlockNumber: {
            _gt: params.latestNonce.toString(),
            ...(params.maxBlockNumber ? { _lte: params.maxBlockNumber.toString() } : {}),
          },
        };

        const result = await this.queryEnvio<{ SettlementIntent: EnvioSettlementIntentEntity[] }>(
          getEnvioSettlementIntentsQuery(),
          { where, limit: params.limit || 200, offset: 0 },
        );

        const intents = (result?.SettlementIntent ?? []).map((e) => parser.envioToSettlementIntent(e, domain));
        allIntents.push(...intents);
      } catch (e: unknown) {
        logger.error('Envio query error', undefined, undefined, jsonifyError(e as Error), { domain });
      }
    }

    return allIntents;
  }

  public async getDestinationIntentsByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<DestinationIntent[]> {
    const allIntents: DestinationIntent[] = [];

    for (const [domain, params] of queryParams.entries()) {
      try {
        const intents = await this.getEnvioDestinationIntentsByNonce(
          [domain],
          params.latestNonce,
          params.maxBlockNumber,
          params.limit || 200,
        );
        allIntents.push(...intents);
      } catch (e: unknown) {
        logger.error('Envio query error', undefined, undefined, jsonifyError(e as Error), { domain });
      }
    }

    return allIntents;
  }

  public async getHubIntentsByNonce(
    domain: string,
    addedLatestNonce: number,
    filledLatestNonce: number,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubIntent[], HubIntent[], HubIntent[]]> {
    const { parser } = getHelpers();

    const maxBlock = maxBlockNumber.toString();

    // Query added intents
    const addedWhere: Record<string, unknown> = {
      addEventBlockNumber: { _gt: addedLatestNonce.toString(), _lte: maxBlock },
      addEventTimestamp: { _is_null: false },
    };

    // Query filled intents
    const filledWhere: Record<string, unknown> = {
      fillEventBlockNumber: { _gt: filledLatestNonce.toString(), _lte: maxBlock },
      fillEventTimestamp: { _is_null: false },
    };

    // Query settlement-enqueued settlements
    const enqueuedWhere: Record<string, unknown> = {
      enqueuedBlockNumber: { _gt: enqueuedLatestNonce.toString(), _lte: maxBlock },
    };

    const [addedResult, filledResult, enqueuedResult] = await Promise.all([
      this.queryEnvio<{ HubIntent: EnvioHubIntentEntity[] }>(getEnvioHubIntentsAddedQuery(), {
        where: addedWhere,
        limit: 200,
        offset: 0,
      }),
      this.queryEnvio<{ HubIntent: EnvioHubIntentEntity[] }>(getEnvioHubIntentsFilledQuery(), {
        where: filledWhere,
        limit: 200,
        offset: 0,
      }),
      this.queryEnvio<{ HubSettlement: EnvioHubSettlementEntity[] }>(getEnvioHubSettlementsQuery(), {
        where: enqueuedWhere,
        limit: 200,
        offset: 0,
      }),
    ]);

    const added = (addedResult?.HubIntent ?? []).map((e) => parser.envioToHubIntent(e, undefined, domain));
    const filled = (filledResult?.HubIntent ?? []).map((e) => parser.envioToHubIntent(e, undefined, domain));
    const enqueued = (enqueuedResult?.HubSettlement ?? []).map((e) =>
      parser.envioToHubIntentFromSettlement(e, undefined, domain),
    );

    return [added, filled, enqueued];
  }

  public async getHubInvoicesByNonce(
    domain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubInvoice[], HubIntent[]]> {
    const { parser } = getHelpers();

    const where: Record<string, unknown> = {
      blockNumber: {
        _gt: enqueuedLatestNonce.toString(),
        _lte: maxBlockNumber.toString(),
      },
    };

    const result = await this.queryEnvio<{ Invoice: EnvioInvoiceEntity[] }>(getEnvioInvoicesQuery(), {
      where,
      limit: 200,
      offset: 0,
    });

    const invoiceEntities = result?.Invoice ?? [];

    // Fetch existing HubIntents to preserve their status
    const intentIds = invoiceEntities.map((e) => e.intentId);
    const hubIntentMap = new Map<string, EnvioHubIntentEntity>();
    if (intentIds.length > 0) {
      const hubIntentResult = await this.queryEnvio<{ HubIntent: EnvioHubIntentEntity[] }>(
        getEnvioHubIntentsAddedQuery(),
        { where: { id: { _in: intentIds } }, limit: 200, offset: 0 },
      );
      for (const entity of hubIntentResult?.HubIntent ?? []) {
        hubIntentMap.set(entity.id, entity);
      }
    }

    const invoices = invoiceEntities.map(parser.envioToHubInvoice);
    const intents = invoiceEntities.map((e) =>
      parser.envioToHubIntentFromInvoice(e, hubIntentMap.get(e.intentId) ?? undefined, domain),
    );

    return [invoices, intents];
  }

  public async getOrdersByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<(Order & { domain: string })[]> {
    const { parser } = getHelpers();
    const allOrders: (Order & { domain: string })[] = [];

    for (const [domain, params] of queryParams.entries()) {
      try {
        const where: Record<string, unknown> = {
          chainId: { _eq: parseInt(domain, 10) },
          blockNumber: {
            _gt: params.latestNonce.toString(),
            ...(params.maxBlockNumber ? { _lte: params.maxBlockNumber.toString() } : {}),
          },
        };

        const result = await this.queryEnvio<{ Order: EnvioOrderEntity[] }>(getEnvioOrdersQuery(), {
          where,
          limit: params.limit || 200,
          offset: 0,
        });

        const orders = (result?.Order ?? []).map(parser.envioToOrder);
        allOrders.push(...orders);
      } catch (e: unknown) {
        logger.error('Envio query error', undefined, undefined, jsonifyError(e as Error), { domain });
      }
    }

    return allOrders;
  }

  // ============================================================================
  // ENVIO-SPECIFIC METHODS (not part of ISubgraphReader interface)
  // ============================================================================

  public async getEnvioOriginIntentById(intentId: string, originDomain?: string): Promise<OriginIntent | undefined> {
    const { parser } = getHelpers();
    const result = await this.queryEnvio<{ Intent: EnvioIntentEntity[] }>(getEnvioIntentByIdQuery(), { intentId });

    if (!result?.Intent || result.Intent.length === 0) {
      return undefined;
    }

    const envioIntent = result.Intent[0];
    if (originDomain && envioIntent.origin.toString() !== originDomain) {
      return undefined;
    }

    return parser.envioToOriginIntent(envioIntent, originDomain);
  }

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
    if (!envioIntent.destinations.includes(parseInt(destinationDomain, 10))) {
      return undefined;
    }

    return parser.envioToDestinationIntent(envioIntent, destinationDomain);
  }

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

    if (destinationDomains.length > 0) {
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
      if (!intent.fills || intent.fills.length === 0) {
        continue;
      }

      const domainsToCheck = destinationDomains.length > 0 ? destinationDomains : intent.destinations.map(String);

      for (const destDomain of domainsToCheck) {
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

  private async fetchHubIntentsByDepositIds(
    deposits: EnvioDepositEntity[],
  ): Promise<Map<string, EnvioHubIntentEntity>> {
    const intentIds = deposits.map((d) => d.intentId);
    const map = new Map<string, EnvioHubIntentEntity>();
    if (intentIds.length === 0) return map;

    const result = await this.queryEnvio<{ HubIntent: EnvioHubIntentEntity[] }>(getEnvioHubIntentsAddedQuery(), {
      where: { id: { _in: intentIds } },
      limit: 200,
      offset: 0,
    });
    for (const entity of result?.HubIntent ?? []) {
      map.set(entity.id, entity);
    }
    return map;
  }
}
