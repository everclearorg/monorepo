import {
  DestinationIntent,
  HubIntent,
  HyperlaneStatus,
  OriginIntent,
  TIntentStatus,
  TMessageType,
  Token,
  expect,
  mkBytes32,
} from '@chimera-monorepo/utils';

import {
  asset,
  destinationIntent,
  hubIntentFromAdded,
  hubIntentFromFilled,
  originIntent,
  settlementMessage,
  token,
  hubIntentFromSettleEnqueued,
  StringToNumber,
} from '../../src/lib/helpers/parse';
import {
  createAssetEntity,
  createHubAddIntentEventEntity,
  createHubFillIntentEventEntity,
  createSettlementEnqueuedEventEntity,
  createSettlementMessageEntity,
  createSpokeAddIntentEventEntity,
  createSpokeFillIntentEventEntity,
  createTokenEntity,
} from '../mock';
import { SettlementMessageType } from '../../src/lib/operations/entities';

describe('Subgraph Adapter - parse', () => {
  const domain = '1337';

  describe('#originIntent', () => {
    const entity = createSpokeAddIntentEventEntity();
    const expected: OriginIntent = {
      id: entity.intent.id,
      queueIdx: entity.intent.queueIdx,
      messageId: undefined,
      status: TIntentStatus.Added,
      receiver: entity.intent.receiver,
      inputAsset: entity.intent.inputAsset,
      outputAsset: entity.intent.outputAsset,
      amount: entity.intent.amount,
      maxFee: entity.intent.maxFee,
      destinations: entity.intent.destinations,
      origin: domain,
      nonce: entity.intent.nonce,
      data: entity.intent.data,
      initiator: entity.txOrigin,
      ttl: +entity.intent.ttl,

      transactionHash: entity.transactionHash,
      timestamp: +entity.timestamp,
      blockNumber: +entity.blockNumber,
      gasLimit: entity.gasLimit,
      gasPrice: entity.gasPrice,
      txOrigin: entity.txOrigin,
      txNonce: +entity.txNonce,
    };

    it('should work for added intents', async () => {
      const parsed = originIntent(entity);
      expect(parsed).to.be.deep.eq(expected);
    });

    it('should work for dispatched intents', async () => {
      const messageId = mkBytes32('0xmessage');
      const parsed = originIntent({
        ...entity,
        intent: { ...entity.intent, message: { id: messageId } as any },
      });
      expect(parsed).to.be.deep.eq({ ...expected, messageId, status: TIntentStatus.Dispatched });
    });
  });

  describe('#destinationIntent', () => {
    const entity = createSpokeFillIntentEventEntity();
    const expected: DestinationIntent = {
      id: entity.intent.id,
      queueIdx: entity.intent.queueIdx,
      messageId: undefined,
      status: TIntentStatus.Added,
      receiver: entity.intent.receiver,
      inputAsset: entity.intent.inputAsset,
      outputAsset: entity.intent.outputAsset,
      amount: entity.intent.amount,
      destination: entity.intent.destinations[0],
      destinations: entity.intent.destinations,
      origin: domain,
      solver: entity.solver,
      fee: entity.fee,
      initiator: entity.intent.initiator,
      nonce: entity.intent.nonce,
      data: entity.intent.data,
      maxFee: entity.intent.maxFee,
      ttl: entity.intent.ttl,
      returnData: undefined,

      transactionHash: entity.transactionHash,
      timestamp: +entity.timestamp,
      blockNumber: +entity.blockNumber,
      gasLimit: entity.gasLimit,
      gasPrice: entity.gasPrice,
      txOrigin: entity.txOrigin,
      txNonce: +entity.txNonce,
    };

    it('should work for added intents', async () => {
      const parsed = destinationIntent(expected.destination, entity);
      expect(parsed).to.be.deep.eq(expected);
    });

    it('should work for dispatched intents', async () => {
      const messageId = mkBytes32('0xmessage');
      const parsed = destinationIntent(expected.destination, {
        ...entity,
        intent: { ...entity.intent, message: { id: messageId } as any },
      });
      expect(parsed).to.be.deep.eq({ ...expected, messageId, status: TIntentStatus.Dispatched });
    });
  });

  describe('#hubIntentFromAdded', () => {
    const event = createHubAddIntentEventEntity({
      status: TIntentStatus.Settled,
      intent: {
        id: mkBytes32('0x1'),
        status: TIntentStatus.Settled,
        queueIdx: mkBytes32('0x12'),
        queue: { id: mkBytes32('0xqueue') } as any,
        settlement: { id: mkBytes32('0xsettlement') } as any,
      } as any,
    });

    const expected: HubIntent = {
      addedTimestamp: +event.timestamp,
      addedTxNonce: +event.txNonce,
      id: event.intent.id,
      domain,
      status: TIntentStatus.Settled,
      queueIdx: event.intent.settlement?.queueIdx,
      messageId: event.intent.settlement?.id ?? undefined,
      settlementAmount: event.intent.settlement?.amount ?? undefined,
      settlementDomain: event.intent.settlement?.domain ?? undefined,
      settlementEpoch: event.intent.settlement?.entryEpoch ?? undefined,
      updateVirtualBalance: event.intent.settlement?.updateVirtualBalance ?? undefined,
    };

    it('should work', async () => {
      const parsed = hubIntentFromAdded(domain, {
        ...event,
        status: TIntentStatus.Added,
        intent: { ...event.intent, settlement: undefined, status: TIntentStatus.Added },
      });
      expect(parsed).to.be.deep.eq({
        ...expected,
        status: TIntentStatus.Added,
        messageId: undefined,
        settlementDomain: undefined,
        settlementAmount: undefined,
        settlementEpoch: undefined,
      });
    });
  });

  describe('#hubIntentFromFilled', () => {
    const event = createHubFillIntentEventEntity({
      status: TIntentStatus.Settled,
      intent: {
        id: mkBytes32('0x1'),
        status: TIntentStatus.Settled,
        queueNode: mkBytes32('0x12'),
        queue: { id: mkBytes32('0xqueue') } as any,
        settlement: { id: mkBytes32('0xsettlement') } as any,
      } as any,
    });

    const expected: HubIntent = {
      filledTimestamp: +event.timestamp,
      filledTxNonce: +event.txNonce,
      id: event.intent.id,
      domain,
      status: TIntentStatus.Settled,
      queueIdx: event.intent.settlement?.queueIdx,
      messageId: event.intent.message?.id ?? undefined,
      settlementDomain: undefined,
      settlementAmount: undefined,
      settlementEpoch: undefined,
      updateVirtualBalance: event.intent.settlement?.updateVirtualBalance ?? undefined,
    };

    it('should work', async () => {
      const parsed = hubIntentFromFilled(domain, event);
      expect(parsed).to.be.deep.eq(expected);
    });

    it('should work if topline and intent status differ', async () => {
      const parsed = hubIntentFromFilled(domain, {
        ...event,
        status: TIntentStatus.Settled,
        intent: { ...event.intent, settlement: undefined, status: TIntentStatus.Filled },
      });
      expect(parsed).to.be.deep.eq({
        ...expected,
        status: TIntentStatus.Filled,
        messageId: undefined,
      });
    });
  });

  describe('#hubIntentFromSettleEnqueued', () => {
    const event = createSettlementEnqueuedEventEntity();
    it('should work for the settled intent', () => {
      const settledIntent = hubIntentFromSettleEnqueued(domain, {
        ...event,
        intent: { ...event.intent, status: TIntentStatus.Settled },
      });

      expect(settledIntent).to.be.deep.eq({
        settlementEnqueuedTimestamp: StringToNumber(event.timestamp),
        settlementEnqueuedTxNonce: StringToNumber(event.txNonce),
        settlementEnqueuedBlockNumber: StringToNumber(event.blockNumber),
        id: event.intent.id,
        domain,
        status: TIntentStatus.Settled,
        queueIdx: event.intent.settlement?.queueIdx,
        messageId: event.intent.message?.id ?? undefined,
        settlementDomain: event.intent.settlement?.domain ?? undefined,
        settlementAmount: event.intent.settlement?.amount ?? undefined,
        settlementEpoch: event.intent.settlement?.entryEpoch ?? undefined,
        updateVirtualBalance: event.intent.settlement?.updateVirtualBalance ?? undefined,
      });
    });
    it('should work for the dispatched intent', () => {});
  });

  describe('#settlementMessage', () => {
    const entity = createSettlementMessageEntity();
    const expected = {
      id: entity.id,
      domain: domain,
      originDomain: domain,
      destinationDomain: entity.domain,
      type: TMessageType.Settlement,
      quote: entity.quote,
      first: 0,
      last: 0,
      intentIds: entity.intentIds,
      settlementDomain: entity.domain,
      settlementType: SettlementMessageType.SETTLED,
      status: HyperlaneStatus.none,

      txOrigin: entity.txOrigin,
      transactionHash: entity.transactionHash,
      timestamp: +entity.timestamp,
      blockNumber: +entity.blockNumber,
      txNonce: +entity.txNonce,
      gasPrice: entity.gasPrice,
      gasLimit: entity.gasLimit,
    };

    it('should work', async () => {
      const parsed = settlementMessage(domain, entity);
      expect(parsed).to.be.deep.eq(expected);
    });
  });

  describe('#token', () => {
    const entity = createTokenEntity();
    const expected: Token = {
      id: entity.id,
      feeAmounts: entity.feeAmounts,
      feeRecipients: entity.feeRecipients,
      maxDiscountBps: +entity.maxDiscountBps,
      discountPerEpoch: +entity.discountPerEpoch,
      prioritizedStrategy: entity.prioritizedStrategy,
    };

    it('should work', async () => {
      const parsed = token(entity);
      expect(parsed).to.be.deep.eq(expected);
    });
  });

  describe('#asset', () => {
    const entity = createAssetEntity();
    const tokenId = mkBytes32('0xdai');
    const expected = {
      id: `${entity.domain}-${tokenId}`,
      token: tokenId,
      domain: entity.domain,
      adopted: entity.adopted,
      approval: entity.approval,
      strategy: entity.strategy,
    };

    it('should work', async () => {
      const parsed = asset(tokenId, entity);
      expect(parsed).to.be.deep.eq(expected);
    });
  });
});
