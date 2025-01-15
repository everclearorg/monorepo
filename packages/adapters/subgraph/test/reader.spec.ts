import { SinonStub, stub } from 'sinon';
import { expect, mkAddress, mkBytes32, mkHash, TIntentStatus } from '@chimera-monorepo/utils';
import { SubgraphQueryMetaParams, SubgraphReader } from '../src';

import * as Helpers from '../src/lib/helpers';
import * as parser from '../src/lib/helpers/parse';
import { DomainInvalid, RuntimeError } from '../src/lib/errors';
import {
  createDepositorEventEntity,
  createMeta,
  createSpokeAddIntentEventEntity,
  createSpokeFillIntentEventEntity,
  createTokensEntity,
  createIntentSettlementEventEntity,
  createHubAddIntentEventEntity,
} from './mock';
import {
  DepositEnqueuedEventEntity,
  DepositProcessedEventEntity,
  DepositQueueEntity,
  MessageEntity,
  MessageType,
  SettlementMessageEntity,
  SettlementMessageType,
  SettlementQueueEntity,
  SpokeQueueEntity,
} from '../src/lib/operations/entities';
import { createHubIntent, createHubInvoice } from '@chimera-monorepo/database/test/mock';

describe('SubgraphReader', () => {
  const domain = '1337';
  const domains = [domain];
  const subgraphs = Object.fromEntries(
    domains.map((domain) => [domain, { endpoints: [`http://localhost:${domain}/graphql`], timeout: 1 }]),
  );
  let execute: SinonStub;
  let reader: SubgraphReader;

  beforeEach(() => {
    execute = stub();
    stub(Helpers, 'getHelpers').returns({
      execute,
      parser,
    });

    reader = SubgraphReader.create({ subgraphs });
  });

  describe('#create', () => {
    it('should create a new instance', () => {
      expect(reader).to.be.instanceOf(SubgraphReader);
    });
  });

  describe('#query', () => {
    it('should throw if the domain is not configured', async () => {
      await expect(reader.query('1339', ['query'])).to.be.rejectedWith(DomainInvalid);
    });

    it('should handle errors', async () => {
      execute.rejects(new Error('error'));
      await expect(reader.query(domain, ['query'])).to.be.rejectedWith(RuntimeError);
    });

    it('should work', async () => {
      const data = 'data';
      execute.resolves(data);
      const result = await reader.query(domain, ['query']);
      expect(result).to.be.deep.eq({ data, domain });
    });
  });

  describe('#getLatestBlockNumber', () => {
    beforeEach(() => {
      execute.resolves(createMeta());
    });

    it('should work', async () => {
      const result = await reader.getLatestBlockNumber(domains);
      expect(result.get(domain)).to.be.eq(123);
      expect([...result.keys()]).to.be.deep.eq(domains);
    });

    it('should gracefully handle errors', async () => {
      execute.rejects(new Error('error'));
      const result = await reader.getLatestBlockNumber(domains);
      expect(result.get(domain)).to.be.undefined;
      expect([...result.keys()]).to.be.deep.eq([]);
    });
  });

  describe('#getOriginIntentById', () => {
    const intent = createSpokeAddIntentEventEntity();

    beforeEach(async () => {
      execute.resolves({ ...createMeta(), intentAddEvents: [intent] });
    });

    it('should work', async () => {
      const result = await reader.getOriginIntentById('1337', intent.id);
      expect(result).to.be.deep.eq(parser.originIntent(intent));
    });

    it('should handle null cases', async () => {
      execute.resolves(undefined);
      const result = await reader.getOriginIntentById('1337', intent.id);
      expect(result).to.be.undefined;
    });
  });

  describe('#getOriginIntentsByNonce', () => {
    const intent = createSpokeAddIntentEventEntity();

    beforeEach(async () => {
      execute.resolves({ ...createMeta(), intentAddEvents: [intent] });
    });

    it('should work', async () => {
      const queryMetaParams: Map<string, SubgraphQueryMetaParams> = new Map();
      queryMetaParams.set('1337', {
        maxBlockNumber: 100,
        latestNonce: 0,
      });
      const result = await reader.getOriginIntentsByNonce(queryMetaParams);
      expect(result[0]).to.be.deep.eq(parser.originIntent(intent));
    });
  });

  describe('#getDestinationIntentById', () => {
    const intent = createSpokeFillIntentEventEntity();

    beforeEach(async () => {
      execute.resolves({ ...createMeta(), intentFilledEvents: [intent] });
    });

    it('should work', async () => {
      const result = await reader.getDestinationIntentById('1337', intent.id);
      expect(result).to.be.deep.eq(parser.destinationIntent('1337', intent));
    });

    it('should handle null cases', async () => {
      execute.resolves({ ...createMeta(), intentFilledEvents: [] });
      const result = await reader.getDestinationIntentById('1337', intent.id);
      expect(result).to.be.undefined;
    });
  });

  describe('#getHubIntentById', () => {
    const intent = createHubAddIntentEventEntity();

    beforeEach(async () => {
      execute.resolves({
        ...createMeta(),
        hubIntents: [{ addEvent: intent, id: intent.id, status: TIntentStatus.Added }],
      });
    });

    it('should work', async () => {
      const result = await reader.getHubIntentById('1337', intent.id);
      expect(result).to.be.deep.eq(parser.hubIntentFromAdded('1337', intent));
    });

    it('should handle null cases', async () => {
      execute.resolves({ ...createMeta(), hubIntents: [] });
      const result = await reader.getHubIntentById('1337', intent.id);
      expect(result).to.be.undefined;
    });
  });

  describe('#getDepositorEvents', () => {
    const event = createDepositorEventEntity();

    beforeEach(() => {
      execute.resolves({ ...createMeta(), depositorEvents: [event] });
    });

    it('should work', async () => {
      const ret = await reader.getDepositorEvents(domain, 1);
      expect(ret).to.be.deep.eq([parser.depositorEvents(event)]);
    });
  });

  describe('#getTokens', () => {
    const tokens = createTokensEntity();

    beforeEach(() => {
      execute.resolves({ ...createMeta(), tokens: [tokens] });
    });

    it('should work', async () => {
      const result = await reader.getTokens(domain);
      const expectedT = [parser.token(tokens)];
      const expectedA = tokens.assets.map((a) => parser.asset(tokens.id, a));
      expect(result).to.be.deep.eq([expectedT, expectedA]);
    });
  });

  describe('#getSpokeQueues', () => {
    const queue: SpokeQueueEntity = {
      id: mkBytes32('0x1'),
      type: 'FILL',
      lastProcessed: Math.floor(Date.now() / 1000),
      size: 10,
      first: 1,
      last: 11,
    };

    beforeEach(() => {
      execute.resolves({ ...createMeta(), queues: [queue] });
    });

    it('should work', async () => {
      const ret = await reader.getSpokeQueues(domain);
      expect(ret).to.be.deep.eq([parser.spokeQueue(domain, queue)]);
    });

    it('should handle null cases', async () => {
      execute.resolves({ ...createMeta(), queues: undefined });
      const ret = await reader.getSpokeQueues(domain);
      expect(ret).to.be.deep.eq([]);
    });
  });

  describe('#getSettlementQueues', () => {
    const queue: SettlementQueueEntity = {
      id: mkBytes32('0x1'),
      domain: '1337',
      lastProcessed: Math.floor(Date.now() / 1000),
      size: 10,
      first: 1,
      last: 11,
    };

    beforeEach(() => {
      execute.resolves({ ...createMeta(), settlementQueues: [queue] });
    });

    it('should work', async () => {
      const ret = await reader.getSettlementQueues(domain);
      expect(ret).to.be.deep.eq([parser.settlementQueue(queue)]);
    });

    it('should handle null cases', async () => {
      execute.resolves({ ...createMeta(), settlementQueues: undefined });
      const ret = await reader.getSettlementQueues(domain);
      expect(ret).to.be.deep.eq([]);
    });
  });

  describe('#getDepositQueues', () => {
    const queue: DepositQueueEntity = {
      id: mkBytes32('0x1'),
      domain: '1337',
      lastProcessed: Math.floor(Date.now() / 1000),
      size: 10,
      first: 1,
      last: 11,
      epoch: 12321,
      tickerHash: mkBytes32('0x1'),
    };
    queue.id = `${queue.epoch}-${queue.domain}-${queue.tickerHash}`;

    beforeEach(() => {
      execute.resolves({ ...createMeta(), depositQueues: [queue] });
    });

    it('should work', async () => {
      const ret = await reader.getDepositQueues(domain, queue.epoch - 1);
      expect(ret).to.be.deep.eq([parser.depositQueue(queue)]);
    });

    it('should handle null cases', async () => {
      execute.resolves({ ...createMeta(), depositQueues: undefined });
      const ret = await reader.getDepositQueues(domain, queue.epoch - 1);
      expect(ret).to.be.deep.eq([]);
    });
  });

  describe('#getDepositsEnqueuedByNonce', () => {
    const entity: DepositEnqueuedEventEntity = {
      id: mkBytes32('0x1'),
      deposit: {
        id: mkBytes32('0x1'),
        amount: '1000',
        epoch: 12321,
        domain: '1337',
        tickerHash: mkBytes32('0x16546'),
      },
      intent: {
        ...createHubIntent(),
      },
      timestamp: Math.floor(Date.now() / 1000),
      txOrigin: mkAddress('0x1'),
      txNonce: 1,
      transactionHash: mkHash('0x2'),
      blockNumber: 123,
      gasLimit: '10000',
      gasPrice: '100000',
    };

    beforeEach(() => {
      execute.resolves({ ...createMeta(), depositEnqueuedEvents: [entity] });
    });

    it('should work', async () => {
      const ret = await reader.getDepositsEnqueuedByNonce(domain, 0, 100_000);
      expect(ret).to.be.deep.eq([parser.hubDepositFromEnqueued(entity)]);
    });

    it('should handle null cases', async () => {
      execute.resolves({ ...createMeta(), depositEnqueuedEvents: undefined });
      const ret = await reader.getDepositsEnqueuedByNonce(domain, 0, 100_000);
      expect(ret).to.be.deep.eq([]);
    });
  });

  describe('#getDepositsProcessedByNonce', () => {
    const entity: DepositProcessedEventEntity = {
      id: mkBytes32('0x1'),
      deposit: {
        id: mkBytes32('0x1'),
        amount: '1000',
        epoch: 12321,
        domain: '1337',
        tickerHash: mkBytes32('0x16546'),
        enqueuedEvent: {
          timestamp: Math.floor(Date.now() / 1000),
          txNonce: 1,
        },
      },
      intent: {
        ...createHubIntent(),
      },
      timestamp: Math.floor(Date.now() / 1000),
      txOrigin: mkAddress('0x1'),
      txNonce: 1,
      transactionHash: mkHash('0x2'),
      blockNumber: 123,
      gasLimit: '10000',
      gasPrice: '100000',
    };

    beforeEach(() => {
      execute.resolves({ ...createMeta(), depositProcessedEvents: [entity] });
    });

    it('should work', async () => {
      const ret = await reader.getDepositsProcessedByNonce(domain, 0, 100_000);
      expect(ret).to.be.deep.eq([parser.hubDepositFromProcessed(entity)]);
    });

    it('should handle null cases', async () => {
      execute.resolves({ ...createMeta(), depositProcessedEvents: undefined });
      const ret = await reader.getDepositsProcessedByNonce(domain, 0, 100_000);
      expect(ret).to.be.deep.eq([]);
    });
  });

  describe('#getSpokeMessages', () => {
    const message: MessageEntity = {
      id: mkBytes32('0x1'),
      type: MessageType.FILL,
      quote: '1000',
      firstIdx: 1,
      lastIdx: 10,
      intentIds: [mkBytes32('0x1')],
      transactionHash: mkHash('0x2'),
      timestamp: Math.floor(Date.now() / 1000),
      blockNumber: 123,
      txOrigin: mkAddress('0x1'),
      txNonce: 1,
      gasLimit: '10000',
      gasPrice: '100000',
    };

    beforeEach(() => {
      execute.resolves({ ...createMeta(), messages: [message] });
    });

    it('should work', async () => {
      const ret = await reader.getSpokeMessages(domain, 0);
      expect(ret).to.be.deep.eq([parser.spokeMessage(domain, message)]);
    });

    it('should handle null cases', async () => {
      execute.resolves({ ...createMeta(), messages: undefined });
      const ret = await reader.getSpokeMessages(domain, 0);
      expect(ret).to.be.deep.eq([]);
    });
  });

  describe('#getHubMessages', () => {
    const message: SettlementMessageEntity = {
      type: SettlementMessageType.SETTLED,
      id: mkBytes32('0x1'),
      quote: '1000',
      domain,
      intentIds: [mkBytes32('0x1')],

      transactionHash: mkHash('0x2'),
      timestamp: Math.floor(Date.now() / 1000),
      blockNumber: 123,
      txOrigin: mkAddress('0x1'),
      txNonce: 1,
      gasLimit: '10000',
      gasPrice: '100000',
    };

    beforeEach(() => {
      execute.resolves({ ...createMeta(), settlementMessages: [message] });
    });

    it('should work', async () => {
      const ret = await reader.getHubMessages(domain, 0);
      expect(ret).to.be.deep.eq([parser.settlementMessage(domain, message)]);
    });

    it('should handle null cases', async () => {
      execute.resolves({ ...createMeta(), settlementMessages: undefined });
      const ret = await reader.getHubMessages(domain, 0);
      expect(ret).to.be.deep.eq([]);
    });
  });

  describe('#getSettlementIntentsByNonce', () => {
    const intent = createIntentSettlementEventEntity();

    beforeEach(async () => {
      execute.resolves({ ...createMeta(), intentSettleEvents: [intent] });
    });

    it('should work', async () => {
      const queryMetaParams: Map<string, SubgraphQueryMetaParams> = new Map();
      queryMetaParams.set('1337', {
        maxBlockNumber: 100,
        latestNonce: 0,
      });
      const result = await reader.getSettlementIntentsByNonce(queryMetaParams);
      expect(result[0]).to.be.deep.eq(parser.settlementIntent('1337', intent));
    });
  });
});
