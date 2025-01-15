/* eslint-disable @typescript-eslint/no-unused-vars */
// TODO: Remove this lint disable
import { QueryResponse, SubgraphQueryMetaParams, isFulfilled } from './lib/types/subgraph';
import {
  OriginIntent,
  DestinationIntent,
  Queue,
  Message,
  jsonifyError,
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
} from '@chimera-monorepo/utils';
import { SubgraphConfig } from './lib/entities';
import { getHelpers } from './lib/helpers';
import { DomainInvalid, RuntimeError } from './lib/errors';

import {
  getBlockNumberQuery,
  getDestinationIntentFilledQuery,
  getOriginIntentAddedQuery,
  getSpokeQueueQuery,
  getSpokeMessagesQuery,
  getSettlementMessagesQuery,
  getTokensQuery,
  getHubIntentAddedQuery,
  getHubIntentFilledQuery,
  getSettlementEnqueuedQuery,
  getOriginIntentByIdQuery,
  getDestinationIntentsByIdsQuery,
  getDepositorEventsQuery,
  getSettlementQueuesQuery,
  getInvoiceEnqueuedQuery,
  getDepositsEnqueuedQuery,
  getDepositsProcessedQuery,
  getDepositQueuesQuery,
  getHubIntentByIdQuery,
  getSettlementIntentEventQuery,
  getInvoiceEnqueuedByIntentId,
} from './lib';

import {
  MetaEntity,
  SettlementQueueEntity,
  SpokeAddIntentEventEntity,
  SpokeFillIntentEventEntity,
  SpokeQueueEntity,
  MessageEntity,
  SettlementMessageEntity,
  TokensEntity,
  HubAddIntentEventEntity,
  HubFillIntentEventEntity,
  SettlementEnqueuedEventEntity,
  InvoiceEnqueuedEventEntity,
  DepositorEventEntity,
  DepositEnqueuedEventEntity,
  DepositProcessedEventEntity,
  DepositQueueEntity,
  IntentStatus,
  IntentSettlementEventEntity,
} from './lib/operations/entities';

let context: { config: SubgraphConfig };
export const getContext = () => context;

export class SubgraphReader {
  private static instance: SubgraphReader | undefined;

  private constructor(config: SubgraphConfig) {
    context = { config };
  }

  public static create(config: SubgraphConfig): SubgraphReader {
    if (SubgraphReader.instance) {
      return SubgraphReader.instance;
    }

    const instance = new SubgraphReader(config);
    return instance;
  }

  /**
   * Make a direct GraphQL query to the subgraph of the given domain.
   *
   * @param query - The GraphQL query string you want to send.
   * @returns Query result (any).
   */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  public async query<T>(domain: string, queries: string[]): Promise<QueryResponse<T> | undefined> {
    const { execute } = getHelpers();
    const { config } = getContext();
    const subgraphConfig = config.subgraphs[domain];
    const { endpoints, timeout } = subgraphConfig ?? {};
    if (!endpoints?.length || !timeout) {
      throw new DomainInvalid(domain);
    }
    try {
      const ret = await execute<T>(domain, queries, endpoints, timeout);
      return { data: ret, domain } as QueryResponse<T>;
    } catch (e: unknown) {
      console.error(jsonifyError(e as Error));
      throw new RuntimeError(e);
    }
  }

  public async getLatestBlockNumber(domains: string[]): Promise<Map<string, number>> {
    const response = await Promise.allSettled(
      domains.map((domain: string) => {
        return this.query<{ _meta: MetaEntity }>(domain, [getBlockNumberQuery()]);
      }),
    );

    const result: Map<string, number> = new Map();
    for (let i = 0; i < domains.length; i++) {
      if (response[i].status === 'fulfilled') {
        const data = (response[i] as PromiseFulfilledResult<QueryResponse<{ _meta: MetaEntity }>>).value;
        result.set(data.domain, data.data._meta.block.number);
      }
    }

    return result;
  }

  public async getOriginIntentById(domain: string, intentId: string): Promise<OriginIntent | undefined> {
    const { parser } = getHelpers();
    const response = await this.query<{
      intentAddEvents: SpokeAddIntentEventEntity[];
      _meta: MetaEntity;
    }>(domain, [getOriginIntentByIdQuery(intentId)]);

    return (response?.data?.intentAddEvents || []).length
      ? parser.originIntent(response!.data.intentAddEvents[0])
      : undefined;
  }

  public async getDestinationIntentById(domain: string, intentId: string): Promise<DestinationIntent | undefined> {
    const { parser } = getHelpers();
    const response = await this.query<{
      intentFilledEvents: SpokeFillIntentEventEntity[];
      _meta: MetaEntity;
    }>(domain, [getDestinationIntentsByIdsQuery([intentId])]);

    return response?.data?.intentFilledEvents?.length
      ? parser.destinationIntent(domain, response!.data.intentFilledEvents[0])
      : undefined;
  }

  public async getHubIntentById(domain: string, intentId: string): Promise<HubIntent | undefined> {
    const { parser } = getHelpers();
    const response = await this.query<{
      hubIntents: {
        id: string;
        status: IntentStatus;
        addEvent: HubAddIntentEventEntity;
      }[];
      _meta: MetaEntity;
    }>(domain, [getHubIntentByIdQuery(intentId)]);

    return response!.data.hubIntents.length
      ? parser.hubIntentFromAdded(domain, response!.data.hubIntents[0].addEvent)
      : undefined;
  }

  public async getHubInvoiceById(domain: string, intentId: string): Promise<HubInvoice | undefined> {
    const { parser } = getHelpers();
    const response = await this.query<{
      invoiceEnqueuedEvents: InvoiceEnqueuedEventEntity[];
      _meta: MetaEntity;
    }>(domain, [getInvoiceEnqueuedByIntentId(intentId)]);

    return response!.data.invoiceEnqueuedEvents.length
      ? parser.hubInvoiceFromInvoiceEnqueued(domain, response!.data.invoiceEnqueuedEvents[0])
      : undefined;
  }

  public async getDepositorEvents(domain: string, latestNonce: number): Promise<DepositorEvent[]> {
    const { parser } = getHelpers();
    const response = await this.query<{ depositorEvents: DepositorEventEntity[]; _meta: MetaEntity }>(domain, [
      getDepositorEventsQuery(latestNonce),
    ]);
    return response!.data.depositorEvents.map(parser.depositorEvents);
  }

  public async getTokens(hubDomain: string): Promise<[Token[], Asset[]]> {
    const { parser } = getHelpers();
    const response = await this.query<{ tokens: TokensEntity[]; _meta: MetaEntity }>(hubDomain, [getTokensQuery()]);

    const tokens = response!.data.tokens.map((t) => parser.token(t));
    const assets = response!.data.tokens.flatMap((t) =>
      t.assets.flatMap((a) => {
        return parser.asset(t.id, a);
      }),
    );

    return [tokens, assets];
  }

  public async getSpokeQueues(domain: string): Promise<Queue[]> {
    const { parser } = getHelpers();
    const response = await this.query<{ queues: SpokeQueueEntity[]; _meta: MetaEntity }>(domain, [
      getSpokeQueueQuery(),
    ]);

    const queues = (response?.data.queues ?? []).map((e) => parser.spokeQueue(domain, e));
    return queues;
  }

  public async getSettlementQueues(hubDomain: string): Promise<Queue[]> {
    const { parser } = getHelpers();
    const response = await this.query<{ settlementQueues: SettlementQueueEntity[]; _meta: MetaEntity }>(hubDomain, [
      getSettlementQueuesQuery(),
    ]);

    const queues = (response?.data.settlementQueues ?? []).map((e) => parser.settlementQueue(e));
    return queues;
  }

  public async getDepositQueues(hubDomain: string, fromEpoch: number): Promise<DepositQueue[]> {
    const { parser } = getHelpers();
    const response = await this.query<{ depositQueues: DepositQueueEntity[]; _meta: MetaEntity }>(hubDomain, [
      getDepositQueuesQuery(fromEpoch),
    ]);

    const queues = (response?.data.depositQueues ?? []).map((e) => parser.depositQueue(e));
    return queues;
  }

  public async getDepositsEnqueuedByNonce(
    hubDomain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    const { parser } = getHelpers();
    const response = await this.query<{ depositEnqueuedEvents: DepositEnqueuedEventEntity[]; _meta: MetaEntity }>(
      hubDomain,
      [getDepositsEnqueuedQuery(enqueuedLatestNonce, maxBlockNumber)],
    );

    const queues = (response?.data.depositEnqueuedEvents ?? []).map((e) => parser.hubDepositFromEnqueued(e));
    return queues;
  }

  public async getDepositsProcessedByNonce(
    hubDomain: string,
    processedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<(HubDeposit & { status: TIntentStatus })[]> {
    const { parser } = getHelpers();
    const response = await this.query<{ depositProcessedEvents: DepositProcessedEventEntity[]; _meta: MetaEntity }>(
      hubDomain,
      [getDepositsProcessedQuery(processedLatestNonce, maxBlockNumber)],
    );

    const processedEvents = (response?.data.depositProcessedEvents ?? []).map((e) => parser.hubDepositFromProcessed(e));
    return processedEvents;
  }

  public async getSpokeMessages(domain: string, latestNonce: number): Promise<Message[]> {
    const { parser } = getHelpers();
    const response = await this.query<{ messages: MessageEntity[]; _meta: MetaEntity }>(domain, [
      getSpokeMessagesQuery(latestNonce),
    ]);

    return (response?.data.messages ?? []).map((e) => parser.spokeMessage(domain, e));
  }

  public async getHubMessages(domain: string, latestNonce: number): Promise<HubMessage[]> {
    const { parser } = getHelpers();
    const response = await this.query<{ settlementMessages: SettlementMessageEntity[]; _meta: MetaEntity }>(domain, [
      getSettlementMessagesQuery(latestNonce),
    ]);

    return (response?.data.settlementMessages ?? []).map((e) => parser.settlementMessage(domain, e));
  }

  public async getOriginIntentsByNonce(queryParams: Map<string, SubgraphQueryMetaParams>): Promise<OriginIntent[]> {
    const { parser } = getHelpers();
    const domains = queryParams.keys();
    const requests = [];
    for (const domain of domains) {
      const param = queryParams.get(domain);
      requests.push(
        this.query<{ intentAddEvents: SpokeAddIntentEventEntity[]; _meta: MetaEntity }>(domain, [
          getOriginIntentAddedQuery(param!.latestNonce, [], param!.maxBlockNumber, param!.orderDirection),
        ]),
      );
    }

    const response = (await Promise.allSettled(requests)).filter(isFulfilled).map((r) => r.value);
    return response.flatMap((data) => (data?.data?.intentAddEvents ?? []).map((e) => parser.originIntent(e)));
  }

  public async getSettlementIntentsByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<SettlementIntent[]> {
    const { parser } = getHelpers();
    const domains = queryParams.keys();
    const requests = [];
    for (const domain of domains) {
      const param = queryParams.get(domain);
      requests.push(
        this.query<{ intentSettleEvents: IntentSettlementEventEntity[]; _meta: MetaEntity }>(domain, [
          getSettlementIntentEventQuery(param!.latestNonce, param!.maxBlockNumber, param!.orderDirection),
        ]),
      );
    }

    const response = (await Promise.allSettled(requests)).filter(isFulfilled).map((r) => r.value);
    return response.flatMap((data) =>
      (data?.data?.intentSettleEvents ?? []).map((e) => parser.settlementIntent(data!.domain, e)),
    );
  }

  public async getDestinationIntentsByNonce(
    queryParams: Map<string, SubgraphQueryMetaParams>,
  ): Promise<DestinationIntent[]> {
    const { parser } = getHelpers();
    const domains = queryParams.keys();
    const requests = [];
    for (const domain of domains) {
      const param = queryParams.get(domain)!;
      requests.push(
        this.query<{ intentFillEvents: SpokeFillIntentEventEntity[]; _meta: MetaEntity }>(domain, [
          getDestinationIntentFilledQuery(param.latestNonce, [], param.maxBlockNumber, param.orderDirection),
        ]),
      );
    }

    const response = (await Promise.allSettled(requests)).filter(isFulfilled).map((r) => r.value);
    return response.flatMap((data, idx) =>
      (data?.data?.intentFillEvents ?? []).map((e) => parser.destinationIntent([...domains][idx], e)),
    );
  }

  public async getHubIntentsByNonce(
    domain: string,
    addedLatestNonce: number,
    filledLatestNonce: number,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubIntent[], HubIntent[], HubIntent[]]> {
    const { parser } = getHelpers();
    const response = await this.query<{
      intentAddEvents: HubAddIntentEventEntity[];
      intentFillEvents: HubFillIntentEventEntity[];
      settlementEnqueuedEvents: SettlementEnqueuedEventEntity[];
      _meta: MetaEntity;
    }>(domain, [
      getHubIntentAddedQuery(addedLatestNonce, maxBlockNumber),
      getHubIntentFilledQuery(filledLatestNonce, maxBlockNumber),
      getSettlementEnqueuedQuery(enqueuedLatestNonce, maxBlockNumber),
    ]);
    return [
      response!.data.intentAddEvents.map((e) => parser.hubIntentFromAdded(domain, e)),
      response!.data.intentFillEvents.map((e) => parser.hubIntentFromFilled(domain, e)),
      response!.data.settlementEnqueuedEvents.map((e) => parser.hubIntentFromSettleEnqueued(domain, e)),
    ];
  }

  public async getHubInvoicesByNonce(
    domain: string,
    enqueuedLatestNonce: number,
    maxBlockNumber: number,
  ): Promise<[HubInvoice[], HubIntent[]]> {
    const { parser } = getHelpers();
    const requests = await this.query<{ invoiceEnqueuedEvents: InvoiceEnqueuedEventEntity[]; _meta: MetaEntity }>(
      domain,
      [getInvoiceEnqueuedQuery(enqueuedLatestNonce, maxBlockNumber)],
    );

    return [
      requests!.data.invoiceEnqueuedEvents.map((e) => parser.hubInvoiceFromInvoiceEnqueued(domain, e)),
      requests!.data.invoiceEnqueuedEvents.map((e) => parser.hubIntentFromInvoiceEnqueued(domain, e)),
    ];
  }
}
