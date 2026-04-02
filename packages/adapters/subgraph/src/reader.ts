/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  OriginIntent,
  DestinationIntent,
  Queue,
  Message,
  Token,
  Asset,
  HubIntent,
  HubInvoice,
  DepositorEvent,
  HubMessage,
  HubDeposit,
  DepositQueue,
  SettlementIntent,
  TIntentStatus,
  Order,
  ProtocolUpdateLog,
  HubTokenUpdateLog,
  HubAssetUpdateLog,
  HubMeta,
  SpokeMeta,
} from '@chimera-monorepo/utils';
import { QueryResponse, SubgraphQueryMetaParams, SubgraphConfig, ReaderCheckpoints } from './lib';
import { GraphReader } from './graph';
import { EnvioReader } from './envio';

/**
 * Interface for subgraph readers (both Goldsky and Envio)
 */
export interface ISubgraphReader {
  readonly readerType: string;
  query<T>(domain: string, queries: string[]): Promise<QueryResponse<T> | undefined>;
  getLatestBlockNumber(domains: string[]): Promise<Map<string, number>>;
  getOriginIntentById(domain: string, intentId: string): Promise<OriginIntent | undefined>;
  getDestinationIntentById(domain: string, intentId: string): Promise<DestinationIntent | undefined>;
  getHubIntentById(domain: string, intentId: string): Promise<HubIntent | undefined>;
  getHubInvoiceById(domain: string, intentId: string): Promise<HubInvoice | undefined>;
  getSettlementIntentById(domain: string, intentId: string): Promise<SettlementIntent | undefined>;
  getHubDepositEnqueuedById(
    domain: string,
    intentId: string,
  ): Promise<(HubDeposit & { status: TIntentStatus }) | undefined>;
  getHubDepositProcessedById(
    domain: string,
    intentId: string,
  ): Promise<(HubDeposit & { status: TIntentStatus }) | undefined>;
  getDepositorEvents(domain: string, latestNonce: number): Promise<DepositorEvent[]>;
  getTokens(hubDomain: string): Promise<[Token[], Asset[]]>;
  getSpokeQueues(domain: string): Promise<Queue[]>;
  getSettlementQueues(hubDomain: string): Promise<Queue[]>;
  getDepositQueues(hubDomain: string, fromBlock: number): Promise<DepositQueue[]>;
  getDepositsEnqueuedByNonce(
    hubDomain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]>;
  getDepositsProcessedByNonce(
    hubDomain: string,
    processedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]>;
  getSpokeMessages(domain: string, latestNonce: number): Promise<Message[]>;
  getHubMessages(domain: string, latestNonce: number): Promise<HubMessage[]>;
  getHubMetaUpdates(domain: string, fromBlock: number): Promise<ProtocolUpdateLog[]>;
  getSpokeMetaUpdates(domain: string, fromBlock: number): Promise<ProtocolUpdateLog[]>;
  getHubTokenUpdates(domain: string, fromBlock: number): Promise<HubTokenUpdateLog[]>;
  getHubAssetUpdates(domain: string, fromBlock: number): Promise<HubAssetUpdateLog[]>;
  getHubMeta(domain: string): Promise<HubMeta | undefined>;
  getSpokeMeta(domain: string): Promise<SpokeMeta | undefined>;
  getOriginIntentsByNonce(queryParams: Map<string, SubgraphQueryMetaParams>): Promise<OriginIntent[]>;
  getSettlementIntentsByNonce(queryParams: Map<string, SubgraphQueryMetaParams>): Promise<SettlementIntent[]>;
  getDestinationIntentsByNonce(queryParams: Map<string, SubgraphQueryMetaParams>): Promise<DestinationIntent[]>;
  getHubIntentsByNonce(
    domain: string,
    addedLatestNonce: number,
    filledLatestNonce: number,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubIntent[], HubIntent[], HubIntent[]]>;
  getHubInvoicesByNonce(
    domain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubInvoice[], HubIntent[]]>;
  getOrdersByNonce(queryParams: Map<string, SubgraphQueryMetaParams>): Promise<(Order & { domain: string })[]>;
}

/**
 * Composite SubgraphReader that combines enabled readers (Goldsky, Envio).
 * Calls all enabled readers in parallel and merges results.
 */
export class SubgraphReader implements ISubgraphReader {
  public readonly readerType = 'composite';
  private readers: ISubgraphReader[];
  private static instance: SubgraphReader | undefined;

  private constructor(config: SubgraphConfig) {
    this.readers = [];

    if (config.goldskyEnabled !== false) {
      this.readers.push(GraphReader.create(config));
    }

    if (config.envioEnabled !== false && config.envio?.url) {
      this.readers.push(EnvioReader.create(config));
    }
  }

  public static create(config: SubgraphConfig): SubgraphReader {
    if (SubgraphReader.instance) {
      return SubgraphReader.instance;
    }

    const instance = new SubgraphReader(config);
    SubgraphReader.instance = instance;
    return instance;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /** Call a method on all readers, returning first non-undefined result. */
  private async firstResult<T>(fn: (r: ISubgraphReader) => Promise<T | undefined>): Promise<T | undefined> {
    const results = await Promise.all(
      this.readers.map((r) => {
        try {
          const p = fn(r);
          return p && typeof (p as any).catch === 'function' ? p.catch(() => undefined) : p;
        } catch {
          return undefined;
        }
      }),
    );
    return results.find((r) => r !== undefined);
  }

  /** Call a method on all readers, merge flat arrays, deduplicate by key. */
  private async mergeArrays<T extends Record<string, unknown>>(
    fn: (r: ISubgraphReader) => Promise<T[]>,
    key: string,
  ): Promise<T[]> {
    const results = await Promise.all(
      this.readers.map((r) => {
        try {
          const p = fn(r);
          return p && typeof (p as any).catch === 'function' ? p.catch(() => [] as T[]) : p ?? [];
        } catch {
          return [] as T[];
        }
      }),
    );
    const map = new Map<unknown, T>();
    for (const arr of results) {
      for (const item of arr) {
        const k = item[key];
        if (!map.has(k)) {
          map.set(k, item);
        }
      }
    }
    return Array.from(map.values());
  }

  // ---------------------------------------------------------------------------
  // ISubgraphReader — direct query (propagates errors unlike firstResult)
  // ---------------------------------------------------------------------------

  public async query<T>(domain: string, queries: string[]): Promise<QueryResponse<T> | undefined> {
    if (this.readers.length === 0) return undefined;

    const settled = await Promise.allSettled(this.readers.map((r) => r.query<T>(domain, queries)));
    // Return first fulfilled non-undefined result
    for (const s of settled) {
      if (s.status === 'fulfilled' && s.value !== undefined) return s.value;
    }
    // If all rejected, throw the first error
    for (const s of settled) {
      if (s.status === 'rejected') throw s.reason;
    }
    return undefined;
  }

  // ---------------------------------------------------------------------------
  // ISubgraphReader — Block number
  // ---------------------------------------------------------------------------

  public async getLatestBlockNumber(domains: string[]): Promise<Map<string, number>> {
    const results = await Promise.all(
      this.readers.map((r) => r.getLatestBlockNumber(domains).catch(() => new Map<string, number>())),
    );

    const merged = new Map<string, number>();
    for (const domain of domains) {
      let max = 0;
      for (const res of results) {
        const block = res.get(domain) ?? 0;
        if (block > max) max = block;
      }
      if (max > 0) merged.set(domain, max);
    }
    return merged;
  }

  // ---------------------------------------------------------------------------
  // ISubgraphReader — Single entity by ID
  // ---------------------------------------------------------------------------

  public async getOriginIntentById(domain: string, intentId: string): Promise<OriginIntent | undefined> {
    return this.firstResult((r) => r.getOriginIntentById(domain, intentId));
  }

  public async getDestinationIntentById(domain: string, intentId: string): Promise<DestinationIntent | undefined> {
    return this.firstResult((r) => r.getDestinationIntentById(domain, intentId));
  }

  public async getHubIntentById(domain: string, intentId: string): Promise<HubIntent | undefined> {
    return this.firstResult((r) => r.getHubIntentById(domain, intentId));
  }

  public async getHubInvoiceById(domain: string, intentId: string): Promise<HubInvoice | undefined> {
    return this.firstResult((r) => r.getHubInvoiceById(domain, intentId));
  }

  public async getSettlementIntentById(domain: string, intentId: string): Promise<SettlementIntent | undefined> {
    return this.firstResult((r) => r.getSettlementIntentById(domain, intentId));
  }

  public async getHubDepositEnqueuedById(
    domain: string,
    intentId: string,
  ): Promise<(HubDeposit & { status: TIntentStatus }) | undefined> {
    return this.firstResult((r) => r.getHubDepositEnqueuedById(domain, intentId));
  }

  public async getHubDepositProcessedById(
    domain: string,
    intentId: string,
  ): Promise<(HubDeposit & { status: TIntentStatus }) | undefined> {
    return this.firstResult((r) => r.getHubDepositProcessedById(domain, intentId));
  }

  // ---------------------------------------------------------------------------
  // ISubgraphReader — Meta (single entity)
  // ---------------------------------------------------------------------------

  public async getHubMeta(domain: string): Promise<HubMeta | undefined> {
    return this.firstResult((r) => r.getHubMeta(domain));
  }

  public async getSpokeMeta(domain: string): Promise<SpokeMeta | undefined> {
    return this.firstResult((r) => r.getSpokeMeta(domain));
  }

  // ---------------------------------------------------------------------------
  // ISubgraphReader — Array results (merged + deduplicated)
  // ---------------------------------------------------------------------------

  public async getDepositorEvents(domain: string, latestNonce: number): Promise<DepositorEvent[]> {
    return this.mergeArrays((r) => r.getDepositorEvents(domain, latestNonce), 'id');
  }

  public async getDepositorEventsWithCheckpoints(
    domain: string,
    checkpoints: ReaderCheckpoints,
  ): Promise<[DepositorEvent[], ReaderCheckpoints]> {
    return this.mergeArraysWithCheckpoints(
      (r) => r.getDepositorEvents(domain, checkpoints[r.readerType] ?? checkpoints['default'] ?? 0),
      'id',
      (item) => item.txNonce ?? 0,
    );
  }

  public async getTokens(hubDomain: string): Promise<[Token[], Asset[]]> {
    const results = await Promise.all(
      this.readers.map((r) => r.getTokens(hubDomain).catch(() => [[], []] as [Token[], Asset[]])),
    );

    const tokenMap = new Map<string, Token>();
    const assetMap = new Map<string, Asset>();

    for (const [tokens, assets] of results) {
      for (const token of tokens) {
        if (!tokenMap.has(token.id)) tokenMap.set(token.id, token);
      }
      for (const asset of assets) {
        if (!assetMap.has(asset.id)) assetMap.set(asset.id, asset);
      }
    }

    return [Array.from(tokenMap.values()), Array.from(assetMap.values())];
  }

  public async getSpokeQueues(domain: string): Promise<Queue[]> {
    return this.mergeArrays((r) => r.getSpokeQueues(domain), 'id');
  }

  public async getSettlementQueues(hubDomain: string): Promise<Queue[]> {
    return this.mergeArrays((r) => r.getSettlementQueues(hubDomain), 'id');
  }

  public async getDepositQueues(hubDomain: string, fromBlock: number): Promise<DepositQueue[]> {
    return this.mergeArrays((r) => r.getDepositQueues(hubDomain, fromBlock), 'id');
  }

  public async getDepositsEnqueuedByNonce(
    hubDomain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    const [results] = await this.getDepositsEnqueuedByNonceWithCheckpoints(
      hubDomain,
      { default: enqueuedLatestNonce },
      maxBlockNumber,
    );
    return results;
  }

  public async getDepositsEnqueuedByNonceWithCheckpoints(
    hubDomain: string,
    checkpoints: ReaderCheckpoints,
    maxBlockNumber: number,
  ): Promise<[(HubDeposit & { status: TIntentStatus })[], ReaderCheckpoints]> {
    return this.mergeArraysWithCheckpoints(
      (r) =>
        r.getDepositsEnqueuedByNonce(
          hubDomain,
          checkpoints[r.readerType] ?? checkpoints['default'] ?? 0,
          maxBlockNumber,
        ),
      'id',
      (item) => item.enqueuedTxNonce ?? 0,
    );
  }

  public async getDepositsProcessedByNonce(
    hubDomain: string,
    processedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    const [results] = await this.getDepositsProcessedByNonceWithCheckpoints(
      hubDomain,
      { default: processedLatestNonce },
      maxBlockNumber,
    );
    return results;
  }

  public async getDepositsProcessedByNonceWithCheckpoints(
    hubDomain: string,
    checkpoints: ReaderCheckpoints,
    maxBlockNumber: number,
  ): Promise<[(HubDeposit & { status: TIntentStatus })[], ReaderCheckpoints]> {
    return this.mergeArraysWithCheckpoints(
      (r) =>
        r.getDepositsProcessedByNonce(
          hubDomain,
          checkpoints[r.readerType] ?? checkpoints['default'] ?? 0,
          maxBlockNumber,
        ),
      'id',
      (item) => item.processedTxNonce ?? 0,
    );
  }

  public async getSpokeMessages(domain: string, latestNonce: number): Promise<Message[]> {
    return this.mergeArrays((r) => r.getSpokeMessages(domain, latestNonce), 'id');
  }

  public async getSpokeMessagesWithCheckpoints(
    domain: string,
    checkpoints: ReaderCheckpoints,
  ): Promise<[Message[], ReaderCheckpoints]> {
    return this.mergeArraysWithCheckpoints(
      (r) => r.getSpokeMessages(domain, checkpoints[r.readerType] ?? checkpoints['default'] ?? 0),
      'id',
      (item) => item.txNonce ?? 0,
    );
  }

  public async getHubMessages(domain: string, latestNonce: number): Promise<HubMessage[]> {
    return this.mergeArrays((r) => r.getHubMessages(domain, latestNonce), 'id');
  }

  public async getHubMessagesWithCheckpoints(
    domain: string,
    checkpoints: ReaderCheckpoints,
  ): Promise<[HubMessage[], ReaderCheckpoints]> {
    return this.mergeArraysWithCheckpoints(
      (r) => r.getHubMessages(domain, checkpoints[r.readerType] ?? checkpoints['default'] ?? 0),
      'id',
      (item) => item.txNonce ?? 0,
    );
  }

  public async getHubMetaUpdates(domain: string, fromBlock: number): Promise<ProtocolUpdateLog[]> {
    return this.mergeArrays((r) => r.getHubMetaUpdates(domain, fromBlock), 'id');
  }

  public async getSpokeMetaUpdates(domain: string, fromBlock: number): Promise<ProtocolUpdateLog[]> {
    return this.mergeArrays((r) => r.getSpokeMetaUpdates(domain, fromBlock), 'id');
  }

  public async getHubTokenUpdates(domain: string, fromBlock: number): Promise<HubTokenUpdateLog[]> {
    return this.mergeArrays((r) => r.getHubTokenUpdates(domain, fromBlock), 'id');
  }

  public async getHubAssetUpdates(domain: string, fromBlock: number): Promise<HubAssetUpdateLog[]> {
    return this.mergeArrays((r) => r.getHubAssetUpdates(domain, fromBlock), 'id');
  }

  public async getOriginIntentsByNonce(queryParams: Map<string, SubgraphQueryMetaParams>): Promise<OriginIntent[]> {
    return this.mergeArrays((r) => r.getOriginIntentsByNonce(queryParams), 'id');
  }

  public async getOriginIntentsByNonceWithCheckpoints(
    queryParamsPerReader: Map<string, Map<string, SubgraphQueryMetaParams>>,
  ): Promise<[OriginIntent[], Map<string, ReaderCheckpoints>]> {
    return this.mergeMultiDomainWithCheckpoints(
      queryParamsPerReader,
      (r, params) => r.getOriginIntentsByNonce(params),
      'id',
      (item) => item.txNonce ?? 0,
      (item) => (item as any).origin?.toString() ?? '',
    );
  }

  public async getSettlementIntentsByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<SettlementIntent[]> {
    return this.mergeArrays((r) => r.getSettlementIntentsByNonce(queryParams), 'intentId');
  }

  public async getSettlementIntentsByNonceWithCheckpoints(
    queryParamsPerReader: Map<string, Map<string, SubgraphQueryMetaParams>>,
  ): Promise<[SettlementIntent[], Map<string, ReaderCheckpoints>]> {
    return this.mergeMultiDomainWithCheckpoints(
      queryParamsPerReader,
      (r, params) => r.getSettlementIntentsByNonce(params),
      'intentId',
      (item) => item.txNonce ?? 0,
      (item) => (item as any).domain ?? '',
    );
  }

  public async getDestinationIntentsByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<DestinationIntent[]> {
    return this.mergeArrays((r) => r.getDestinationIntentsByNonce(queryParams), 'id');
  }

  public async getDestinationIntentsByNonceWithCheckpoints(
    queryParamsPerReader: Map<string, Map<string, SubgraphQueryMetaParams>>,
  ): Promise<[DestinationIntent[], Map<string, ReaderCheckpoints>]> {
    return this.mergeMultiDomainWithCheckpoints(
      queryParamsPerReader,
      (r, params) => r.getDestinationIntentsByNonce(params),
      'id',
      (item) => item.txNonce ?? 0,
      (item) => item.destination,
    );
  }

  public async getOrdersByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<(Order & { domain: string })[]> {
    return this.mergeArrays((r) => r.getOrdersByNonce(queryParams), 'id');
  }

  public async getOrdersByNonceWithCheckpoints(
    queryParamsPerReader: Map<string, Map<string, SubgraphQueryMetaParams>>,
  ): Promise<[(Order & { domain: string })[], Map<string, ReaderCheckpoints>]> {
    return this.mergeMultiDomainWithCheckpoints(
      queryParamsPerReader,
      (r, params) => r.getOrdersByNonce(params),
      'id',
      (item) => item.txNonce ?? 0,
      (item) => item.domain,
    );
  }

  // ---------------------------------------------------------------------------
  // ISubgraphReader — Tuple results (merged per position)
  // ---------------------------------------------------------------------------

  public async getHubIntentsByNonce(
    domain: string,
    addedLatestNonce: number,
    filledLatestNonce: number,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubIntent[], HubIntent[], HubIntent[]]> {
    const [result] = await this.getHubIntentsByNonceWithCheckpoints(
      domain,
      { default: addedLatestNonce },
      { default: filledLatestNonce },
      { default: enqueuedLatestNonce },
      maxBlockNumber,
    );
    return result;
  }

  public async getHubIntentsByNonceWithCheckpoints(
    domain: string,
    addedCheckpoints: ReaderCheckpoints,
    filledCheckpoints: ReaderCheckpoints,
    enqueuedCheckpoints: ReaderCheckpoints,
    maxBlockNumber: number,
  ): Promise<[[HubIntent[], HubIntent[], HubIntent[]], ReaderCheckpoints, ReaderCheckpoints, ReaderCheckpoints]> {
    const empty: [HubIntent[], HubIntent[], HubIntent[]] = [[], [], []];
    const perReader = await Promise.all(
      this.readers.map(async (r) => {
        const addedNonce = addedCheckpoints[r.readerType] ?? addedCheckpoints['default'] ?? 0;
        const filledNonce = filledCheckpoints[r.readerType] ?? filledCheckpoints['default'] ?? 0;
        const enqueuedNonce = enqueuedCheckpoints[r.readerType] ?? enqueuedCheckpoints['default'] ?? 0;
        const result = await r
          .getHubIntentsByNonce(domain, addedNonce, filledNonce, enqueuedNonce, maxBlockNumber)
          .catch(() => empty);
        return { readerType: r.readerType, result };
      }),
    );

    const dedup = (arrays: HubIntent[][]): HubIntent[] => {
      const map = new Map<string, HubIntent>();
      for (const arr of arrays) {
        for (const item of arr) {
          if (!map.has(item.id)) map.set(item.id, item);
        }
      }
      return Array.from(map.values());
    };

    const addedCps: ReaderCheckpoints = {};
    const filledCps: ReaderCheckpoints = {};
    const enqueuedCps: ReaderCheckpoints = {};

    for (const { readerType, result } of perReader) {
      const [added, filled, enqueued] = result;
      addedCps[readerType] = Math.max(0, ...added.map((i) => i.addedTxNonce ?? 0));
      filledCps[readerType] = Math.max(0, ...filled.map((i) => i.filledTxNonce ?? 0));
      enqueuedCps[readerType] = Math.max(0, ...enqueued.map((i) => i.settlementEnqueuedTxNonce ?? 0));
    }

    return [
      [
        dedup(perReader.map((r) => r.result[0])),
        dedup(perReader.map((r) => r.result[1])),
        dedup(perReader.map((r) => r.result[2])),
      ],
      addedCps,
      filledCps,
      enqueuedCps,
    ];
  }

  public async getHubInvoicesByNonce(
    domain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubInvoice[], HubIntent[]]> {
    const [result] = await this.getHubInvoicesByNonceWithCheckpoints(
      domain,
      { default: enqueuedLatestNonce },
      maxBlockNumber,
    );
    return result;
  }

  public async getHubInvoicesByNonceWithCheckpoints(
    domain: string,
    checkpoints: ReaderCheckpoints,
    maxBlockNumber: number,
  ): Promise<[[HubInvoice[], HubIntent[]], ReaderCheckpoints]> {
    const empty: [HubInvoice[], HubIntent[]] = [[], []];
    const perReader = await Promise.all(
      this.readers.map(async (r) => {
        const nonce = checkpoints[r.readerType] ?? checkpoints['default'] ?? 0;
        const result = await r.getHubInvoicesByNonce(domain, nonce, maxBlockNumber).catch(() => empty);
        return { readerType: r.readerType, result };
      }),
    );

    const invoiceMap = new Map<string, HubInvoice>();
    const intentMap = new Map<string, HubIntent>();
    const newCheckpoints: ReaderCheckpoints = {};

    for (const { readerType, result } of perReader) {
      const [invoices, intents] = result;
      for (const invoice of invoices) {
        if (!invoiceMap.has(invoice.id)) invoiceMap.set(invoice.id, invoice);
      }
      for (const intent of intents) {
        if (!intentMap.has(intent.id)) intentMap.set(intent.id, intent);
      }
      newCheckpoints[readerType] = Math.max(0, ...invoices.map((i) => i.enqueuedTxNonce ?? 0));
    }

    return [[Array.from(invoiceMap.values()), Array.from(intentMap.values())], newCheckpoints];
  }

  // ---------------------------------------------------------------------------
  // Helpers — per-reader checkpoint tracking
  // ---------------------------------------------------------------------------

  /**
   * Call a method on all readers with per-reader checkpoints, merge results,
   * and return per-reader max checkpoint values.
   */
  private async mergeArraysWithCheckpoints<T extends Record<string, unknown>>(
    fn: (r: ISubgraphReader) => Promise<T[]>,
    key: string,
    getNonce: (item: T) => number,
  ): Promise<[T[], ReaderCheckpoints]> {
    const perReader = await Promise.all(
      this.readers.map(async (r) => {
        try {
          const p = fn(r);
          const items = p && typeof (p as any).catch === 'function' ? await p.catch(() => [] as T[]) : (await p) ?? [];
          return { readerType: r.readerType, items };
        } catch {
          return { readerType: r.readerType, items: [] as T[] };
        }
      }),
    );

    const map = new Map<unknown, T>();
    const newCheckpoints: ReaderCheckpoints = {};

    for (const { readerType, items } of perReader) {
      for (const item of items) {
        const k = item[key];
        if (!map.has(k)) {
          map.set(k, item);
        }
      }
      newCheckpoints[readerType] = items.length > 0 ? Math.max(0, ...items.map(getNonce)) : 0;
    }

    return [Array.from(map.values()), newCheckpoints];
  }

  /**
   * For multi-domain methods: each reader gets its own queryParams built from
   * per-reader checkpoints. Returns merged results + per-domain per-reader checkpoints.
   */
  private async mergeMultiDomainWithCheckpoints<T extends Record<string, unknown>>(
    queryParamsPerReader: Map<string, Map<string, SubgraphQueryMetaParams>>,
    fn: (r: ISubgraphReader, params: Map<string, SubgraphQueryMetaParams>) => Promise<T[]>,
    key: string,
    getNonce: (item: T) => number,
    getDomain: (item: T) => string,
  ): Promise<[T[], Map<string, ReaderCheckpoints>]> {
    const perReader = await Promise.all(
      this.readers.map(async (r) => {
        const params = queryParamsPerReader.get(r.readerType);
        if (!params || params.size === 0) return { readerType: r.readerType, items: [] as T[] };
        try {
          const items = await fn(r, params).catch(() => [] as T[]);
          return { readerType: r.readerType, items };
        } catch {
          return { readerType: r.readerType, items: [] as T[] };
        }
      }),
    );

    const map = new Map<unknown, T>();
    // domainCheckpoints: domain -> { readerType -> maxNonce }
    const domainCheckpoints = new Map<string, ReaderCheckpoints>();

    for (const { readerType, items } of perReader) {
      for (const item of items) {
        const k = item[key];
        if (!map.has(k)) map.set(k, item);

        const domain = getDomain(item);
        if (domain) {
          if (!domainCheckpoints.has(domain)) domainCheckpoints.set(domain, {});
          const dc = domainCheckpoints.get(domain)!;
          const nonce = getNonce(item);
          dc[readerType] = Math.max(dc[readerType] ?? 0, nonce);
        }
      }
    }

    return [Array.from(map.values()), domainCheckpoints];
  }

  /** Returns the reader types present in this composite reader. */
  public getReaderTypes(): string[] {
    return this.readers.map((r) => r.readerType);
  }
}
