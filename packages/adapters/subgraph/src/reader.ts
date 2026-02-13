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
import { QueryResponse, SubgraphQueryMetaParams, SubgraphConfig } from './lib';
import { GraphReader } from './graph';
import { EnvioReader } from './envio';

/**
 * Interface for subgraph readers (both Goldsky and Envio)
 */
export interface ISubgraphReader {
  query<T>(domain: string, queries: string[]): Promise<QueryResponse<T> | undefined>;
  getLatestBlockNumber(domains: string[]): Promise<Map<string, number>>;
  getOriginIntentById(domain: string, intentId: string): Promise<OriginIntent | undefined>;
  getDestinationIntentById(domain: string, intentId: string): Promise<DestinationIntent | undefined>;
  getHubIntentById(domain: string, intentId: string): Promise<HubIntent | undefined>;
  getHubInvoiceById(domain: string, intentId: string): Promise<HubInvoice | undefined>;
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
 * Composite SubgraphReader that combines GraphReader (Goldsky) and EnvioReader
 * Calls both readers in parallel and merges results
 */
export class SubgraphReader implements ISubgraphReader {
  private graphReader: GraphReader;
  private envioReader: EnvioReader;
  private static instance: SubgraphReader | undefined;

  private constructor(config: SubgraphConfig) {
    this.graphReader = GraphReader.create(config);
    this.envioReader = EnvioReader.create(config);
  }

  public static create(config: SubgraphConfig): SubgraphReader {
    if (SubgraphReader.instance) {
      return SubgraphReader.instance;
    }

    const instance = new SubgraphReader(config);
    SubgraphReader.instance = instance;
    return instance;
  }

  /**
   * Make a direct GraphQL query to the subgraph
   * Returns result from GraphReader (Goldsky) as a primary source
   */
  public async query<T>(domain: string, queries: string[]): Promise<QueryResponse<T> | undefined> {
    // GraphReader is primary for direct queries
    return this.graphReader.query<T>(domain, queries);
  }

  /**
   * Get the latest block number for given domains
   * Merges results from both readers, preferring higher block numbers
   */
  public async getLatestBlockNumber(domains: string[]): Promise<Map<string, number>> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getLatestBlockNumber(domains).catch(() => new Map<string, number>()),
      this.envioReader.getLatestBlockNumber(domains).catch(() => new Map<string, number>()),
    ]);

    const result = new Map<string, number>();
    for (const domain of domains) {
      const graphBlock = graphResults.get(domain);
      const envioBlock = envioResults.get(domain);
      // Prefer higher block number
      const maxBlock = Math.max(graphBlock ?? 0, envioBlock ?? 0);
      if (maxBlock > 0) {
        result.set(domain, maxBlock);
      }
    }

    return result;
  }

  /**
   * Get origin intent by ID
   * Tries GraphReader first, falls back to EnvioReader
   */
  public async getOriginIntentById(domain: string, intentId: string): Promise<OriginIntent | undefined> {
    const [graphResult, envioResult] = await Promise.all([
      this.graphReader.getOriginIntentById(domain, intentId).catch(() => undefined),
      this.envioReader.getOriginIntentById(domain, intentId).catch(() => undefined),
    ]);

    return graphResult ?? envioResult;
  }

  /**
   * Get destination intent by ID
   * Tries GraphReader first, falls back to EnvioReader
   */
  public async getDestinationIntentById(domain: string, intentId: string): Promise<DestinationIntent | undefined> {
    const [graphResult, envioResult] = await Promise.all([
      this.graphReader.getDestinationIntentById(domain, intentId).catch(() => undefined),
      this.envioReader.getDestinationIntentById(domain, intentId).catch(() => undefined),
    ]);

    return graphResult ?? envioResult;
  }

  /**
   * Get hub intent by ID
   * Tries GraphReader first, falls back to EnvioReader
   */
  public async getHubIntentById(domain: string, intentId: string): Promise<HubIntent | undefined> {
    const [graphResult, envioResult] = await Promise.all([
      this.graphReader.getHubIntentById(domain, intentId).catch(() => undefined),
      this.envioReader.getHubIntentById(domain, intentId).catch(() => undefined),
    ]);

    return graphResult ?? envioResult;
  }

  /**
   * Get hub invoice by ID
   * Tries GraphReader first, falls back to EnvioReader
   */
  public async getHubInvoiceById(domain: string, intentId: string): Promise<HubInvoice | undefined> {
    const [graphResult, envioResult] = await Promise.all([
      this.graphReader.getHubInvoiceById(domain, intentId).catch(() => undefined),
      this.envioReader.getHubInvoiceById(domain, intentId).catch(() => undefined),
    ]);

    return graphResult ?? envioResult;
  }

  /**
   * Get depositor events
   * Merges results from both readers
   */
  public async getDepositorEvents(domain: string, latestNonce: number): Promise<DepositorEvent[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getDepositorEvents(domain, latestNonce).catch(() => []),
      this.envioReader.getDepositorEvents(domain, latestNonce).catch(() => []),
    ]);

    // Merge results, deduplicate by event ID if needed
    return [...graphResults, ...envioResults];
  }

  /**
   * Get tokens and assets
   * Merges results from both readers
   */
  public async getTokens(hubDomain: string): Promise<[Token[], Asset[]]> {
    const [graphResult, envioResult] = await Promise.all([
      this.graphReader.getTokens(hubDomain).catch(() => [[], []] as [Token[], Asset[]]),
      this.envioReader.getTokens(hubDomain).catch(() => [[], []] as [Token[], Asset[]]),
    ]);

    // Merge tokens and assets, deduplicate by ID
    const tokenMap = new Map<string, Token>();
    const assetMap = new Map<string, Asset>();

    for (const token of [...graphResult[0], ...envioResult[0]]) {
      if (!tokenMap.has(token.id)) {
        tokenMap.set(token.id, token);
      }
    }

    for (const asset of [...graphResult[1], ...envioResult[1]]) {
      if (!assetMap.has(asset.id)) {
        assetMap.set(asset.id, asset);
      }
    }

    return [Array.from(tokenMap.values()), Array.from(assetMap.values())];
  }

  /**
   * Get spoke queues
   * Merges results from both readers
   */
  public async getSpokeQueues(domain: string): Promise<Queue[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getSpokeQueues(domain).catch(() => []),
      this.envioReader.getSpokeQueues(domain).catch(() => []),
    ]);

    // Merge results, deduplicate by queue ID
    const queueMap = new Map<string, Queue>();
    for (const queue of [...graphResults, ...envioResults]) {
      if (!queueMap.has(queue.id)) {
        queueMap.set(queue.id, queue);
      }
    }

    return Array.from(queueMap.values());
  }

  /**
   * Get settlement queues
   * Merges results from both readers
   */
  public async getSettlementQueues(hubDomain: string): Promise<Queue[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getSettlementQueues(hubDomain).catch(() => []),
      this.envioReader.getSettlementQueues(hubDomain).catch(() => []),
    ]);

    // Merge results, deduplicate by queue ID
    const queueMap = new Map<string, Queue>();
    for (const queue of [...graphResults, ...envioResults]) {
      if (!queueMap.has(queue.id)) {
        queueMap.set(queue.id, queue);
      }
    }

    return Array.from(queueMap.values());
  }

  /**
   * Get deposit queues
   * Merges results from both readers
   */
  public async getDepositQueues(hubDomain: string, fromBlock: number): Promise<DepositQueue[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getDepositQueues(hubDomain, fromBlock).catch(() => []),
      this.envioReader.getDepositQueues(hubDomain, fromBlock).catch(() => []),
    ]);

    // Merge results, deduplicate by queue ID
    const queueMap = new Map<string, DepositQueue>();
    for (const queue of [...graphResults, ...envioResults]) {
      if (!queueMap.has(queue.id)) {
        queueMap.set(queue.id, queue);
      }
    }

    return Array.from(queueMap.values());
  }

  /**
   * Get deposits enqueued by nonce
   * Merges results from both readers
   */
  public async getDepositsEnqueuedByNonce(
    hubDomain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getDepositsEnqueuedByNonce(hubDomain, enqueuedLatestNonce, maxBlockNumber).catch(() => []),
      this.envioReader.getDepositsEnqueuedByNonce(hubDomain, enqueuedLatestNonce, maxBlockNumber).catch(() => []),
    ]);

    // Merge results, deduplicate by deposit ID
    const depositMap = new Map<string, HubDeposit & { status: TIntentStatus }>();
    for (const deposit of [...graphResults, ...envioResults]) {
      if (!depositMap.has(deposit.id)) {
        depositMap.set(deposit.id, deposit);
      }
    }

    return Array.from(depositMap.values());
  }

  /**
   * Get deposits processed by nonce
   * Merges results from both readers
   */
  public async getDepositsProcessedByNonce(
    hubDomain: string,
    processedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getDepositsProcessedByNonce(hubDomain, processedLatestNonce, maxBlockNumber).catch(() => []),
      this.envioReader.getDepositsProcessedByNonce(hubDomain, processedLatestNonce, maxBlockNumber).catch(() => []),
    ]);

    // Merge results, deduplicate by deposit ID
    const depositMap = new Map<string, HubDeposit & { status: TIntentStatus }>();
    for (const deposit of [...graphResults, ...envioResults]) {
      if (!depositMap.has(deposit.id)) {
        depositMap.set(deposit.id, deposit);
      }
    }

    return Array.from(depositMap.values());
  }

  /**
   * Get spoke messages
   * Merges results from both readers
   */
  public async getSpokeMessages(domain: string, latestNonce: number): Promise<Message[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getSpokeMessages(domain, latestNonce).catch(() => []),
      this.envioReader.getSpokeMessages(domain, latestNonce).catch(() => []),
    ]);

    // Merge results, deduplicate by message ID
    const messageMap = new Map<string, Message>();
    for (const message of [...graphResults, ...envioResults]) {
      if (!messageMap.has(message.id)) {
        messageMap.set(message.id, message);
      }
    }

    return Array.from(messageMap.values());
  }

  /**
   * Get hub messages
   * Merges results from both readers
   */
  public async getHubMessages(domain: string, latestNonce: number): Promise<HubMessage[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getHubMessages(domain, latestNonce).catch(() => []),
      this.envioReader.getHubMessages(domain, latestNonce).catch(() => []),
    ]);

    // Merge results, deduplicate by message ID
    const messageMap = new Map<string, HubMessage>();
    for (const message of [...graphResults, ...envioResults]) {
      if (!messageMap.has(message.id)) {
        messageMap.set(message.id, message);
      }
    }

    return Array.from(messageMap.values());
  }

  /**
   * Get hub meta
   * Tries GraphReader first, falls back to EnvioReader
   */
  public async getHubMeta(domain: string): Promise<HubMeta | undefined> {
    const [graphResult, envioResult] = await Promise.all([
      this.graphReader.getHubMeta(domain).catch(() => undefined),
      this.envioReader.getHubMeta(domain).catch(() => undefined),
    ]);

    return graphResult ?? envioResult;
  }

  /**
   * Get spoke meta
   * Tries GraphReader first, falls back to EnvioReader
   */
  public async getSpokeMeta(domain: string): Promise<SpokeMeta | undefined> {
    const [graphResult, envioResult] = await Promise.all([
      this.graphReader.getSpokeMeta(domain).catch(() => undefined),
      this.envioReader.getSpokeMeta(domain).catch(() => undefined),
    ]);

    return graphResult ?? envioResult;
  }

  public async getHubMetaUpdates(domain: string, fromBlock: number): Promise<ProtocolUpdateLog[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getHubMetaUpdates(domain, fromBlock).catch(() => []),
      this.envioReader.getHubMetaUpdates(domain, fromBlock).catch(() => []),
    ]);

    const updateMap = new Map<string, ProtocolUpdateLog>();
    for (const update of [...graphResults, ...envioResults]) {
      if (!updateMap.has(update.id)) {
        updateMap.set(update.id, update);
      }
    }

    return Array.from(updateMap.values());
  }

  public async getSpokeMetaUpdates(domain: string, fromBlock: number): Promise<ProtocolUpdateLog[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getSpokeMetaUpdates(domain, fromBlock).catch(() => []),
      this.envioReader.getSpokeMetaUpdates(domain, fromBlock).catch(() => []),
    ]);

    const updateMap = new Map<string, ProtocolUpdateLog>();
    for (const update of [...graphResults, ...envioResults]) {
      if (!updateMap.has(update.id)) {
        updateMap.set(update.id, update);
      }
    }

    return Array.from(updateMap.values());
  }

  public async getHubTokenUpdates(domain: string, fromBlock: number): Promise<HubTokenUpdateLog[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getHubTokenUpdates(domain, fromBlock).catch(() => []),
      this.envioReader.getHubTokenUpdates(domain, fromBlock).catch(() => []),
    ]);

    const updateMap = new Map<string, HubTokenUpdateLog>();
    for (const update of [...graphResults, ...envioResults]) {
      if (!updateMap.has(update.id)) {
        updateMap.set(update.id, update);
      }
    }

    return Array.from(updateMap.values());
  }

  public async getHubAssetUpdates(domain: string, fromBlock: number): Promise<HubAssetUpdateLog[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getHubAssetUpdates(domain, fromBlock).catch(() => []),
      this.envioReader.getHubAssetUpdates(domain, fromBlock).catch(() => []),
    ]);

    const updateMap = new Map<string, HubAssetUpdateLog>();
    for (const update of [...graphResults, ...envioResults]) {
      if (!updateMap.has(update.id)) {
        updateMap.set(update.id, update);
      }
    }

    return Array.from(updateMap.values());
  }

  /**
   * Get origin intents by nonce
   * Merges results from both readers, deduplicates by intent ID
   */
  public async getOriginIntentsByNonce(queryParams: Map<string, SubgraphQueryMetaParams>): Promise<OriginIntent[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getOriginIntentsByNonce(queryParams).catch(() => []),
      this.envioReader.getOriginIntentsByNonce(queryParams).catch(() => []),
    ]);

    // Deduplicate by intent ID, prefer GraphReader results
    const intentMap = new Map<string, OriginIntent>();
    for (const intent of [...graphResults, ...envioResults]) {
      if (!intentMap.has(intent.id)) {
        intentMap.set(intent.id, intent);
      }
    }

    return Array.from(intentMap.values());
  }

  /**
   * Get settlement intents by nonce
   * Merges results from both readers
   */
  public async getSettlementIntentsByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<SettlementIntent[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getSettlementIntentsByNonce(queryParams).catch(() => []),
      this.envioReader.getSettlementIntentsByNonce(queryParams).catch(() => []),
    ]);

    // Merge results, deduplicate by intent ID
    const intentMap = new Map<string, SettlementIntent>();
    for (const intent of [...graphResults, ...envioResults]) {
      if (!intentMap.has(intent.intentId)) {
        intentMap.set(intent.intentId, intent);
      }
    }

    return Array.from(intentMap.values());
  }

  /**
   * Get destination intents by nonce
   * Merges results from both readers, deduplicates by intent ID
   */
  public async getDestinationIntentsByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<DestinationIntent[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getDestinationIntentsByNonce(queryParams).catch(() => []),
      this.envioReader.getDestinationIntentsByNonce(queryParams).catch(() => []),
    ]);

    // Deduplicate by intent ID, prefer GraphReader results
    const intentMap = new Map<string, DestinationIntent>();
    for (const intent of [...graphResults, ...envioResults]) {
      if (!intentMap.has(intent.id)) {
        intentMap.set(intent.id, intent);
      }
    }

    return Array.from(intentMap.values());
  }

  /**
   * Get hub intents by nonce
   * Merges results from both readers
   */
  public async getHubIntentsByNonce(
    domain: string,
    addedLatestNonce: number,
    filledLatestNonce: number,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubIntent[], HubIntent[], HubIntent[]]> {
    const [graphResult, envioResult] = await Promise.all([
      this.graphReader
        .getHubIntentsByNonce(domain, addedLatestNonce, filledLatestNonce, enqueuedLatestNonce, maxBlockNumber)
        .catch(() => [[], [], []] as [HubIntent[], HubIntent[], HubIntent[]]),
      this.envioReader
        .getHubIntentsByNonce(domain, addedLatestNonce, filledLatestNonce, enqueuedLatestNonce, maxBlockNumber)
        .catch(() => [[], [], []] as [HubIntent[], HubIntent[], HubIntent[]]),
    ]);

    // Merge each array, deduplicate by intent ID
    const mergeHubIntents = (arr1: HubIntent[], arr2: HubIntent[]): HubIntent[] => {
      const intentMap = new Map<string, HubIntent>();
      for (const intent of [...arr1, ...arr2]) {
        if (!intentMap.has(intent.id)) {
          intentMap.set(intent.id, intent);
        }
      }
      return Array.from(intentMap.values());
    };

    return [
      mergeHubIntents(graphResult[0], envioResult[0]),
      mergeHubIntents(graphResult[1], envioResult[1]),
      mergeHubIntents(graphResult[2], envioResult[2]),
    ];
  }

  /**
   * Get hub invoices by nonce
   * Merges results from both readers
   */
  public async getHubInvoicesByNonce(
    domain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubInvoice[], HubIntent[]]> {
    const [graphResult, envioResult] = await Promise.all([
      this.graphReader
        .getHubInvoicesByNonce(domain, enqueuedLatestNonce, maxBlockNumber)
        .catch(() => [[], []] as [HubInvoice[], HubIntent[]]),
      this.envioReader
        .getHubInvoicesByNonce(domain, enqueuedLatestNonce, maxBlockNumber)
        .catch(() => [[], []] as [HubInvoice[], HubIntent[]]),
    ]);

    // Merge invoices and intents, deduplicate by ID
    const invoiceMap = new Map<string, HubInvoice>();
    const intentMap = new Map<string, HubIntent>();

    for (const invoice of [...graphResult[0], ...envioResult[0]]) {
      if (!invoiceMap.has(invoice.id)) {
        invoiceMap.set(invoice.id, invoice);
      }
    }

    for (const intent of [...graphResult[1], ...envioResult[1]]) {
      if (!intentMap.has(intent.id)) {
        intentMap.set(intent.id, intent);
      }
    }

    return [Array.from(invoiceMap.values()), Array.from(intentMap.values())];
  }

  /**
   * Get orders by nonce
   * Merges results from both readers
   */
  public async getOrdersByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<(Order & { domain: string })[]> {
    const [graphResults, envioResults] = await Promise.all([
      this.graphReader.getOrdersByNonce(queryParams).catch(() => []),
      this.envioReader.getOrdersByNonce(queryParams).catch(() => []),
    ]);

    // Merge results, deduplicate by order ID
    const orderMap = new Map<string, Order & { domain: string }>();
    for (const order of [...graphResults, ...envioResults]) {
      if (!orderMap.has(order.id)) {
        orderMap.set(order.id, order);
      }
    }

    return Array.from(orderMap.values());
  }
}
