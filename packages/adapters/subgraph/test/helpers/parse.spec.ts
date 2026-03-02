import {
  DestinationIntent,
  HubAssetUpdateLog,
  HubIntent,
  HubMeta,
  HubTokenUpdateLog,
  HyperlaneStatus,
  OriginIntent,
  Order,
  ProtocolUpdateLog,
  SpokeMeta,
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
  protocolUpdateLog,
  hubTokenUpdateLog,
  hubAssetUpdateLog,
  hubMeta,
  spokeMeta,
  order,
  envioToOriginIntent,
  envioToDestinationIntent,
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
import {
  MetaUpdateEntity,
  SettlementMessageType,
  FeesEntity,
  OrderEntity,
  HubTokenUpdateEntity,
  HubAssetUpdateEntity,
  HubMetaEntity,
  SpokeMetaEntity,
} from '../../src/lib/operations/entities';

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
      amountOutMin: entity.intent.amountOutMin,
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

      tokenFee: undefined,
      nativeFee: undefined,
      feeAdapterInitiator: undefined,
      orderId: undefined,
      isSwap: undefined, // Will be computed by cartographer, not from subgraph
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
      expect(parsed).to.be.deep.eq({ ...expected, messageId, status: TIntentStatus.Dispatched, isSwap: undefined });
    });

    it('should include fee information when present', async () => {
      const fees: FeesEntity = {
        id: mkBytes32('0xfees'),
        intent: { id: entity.intent.id },
        initiator: mkBytes32('0xfeeInitiator'),
        tokenFee: '1000',
        nativeFee: '2000',
        transactionHash: entity.transactionHash,
        timestamp: +entity.timestamp,
        gasPrice: entity.gasPrice,
        gasLimit: entity.gasLimit,
        blockNumber: +entity.blockNumber,
        txOrigin: entity.txOrigin,
        txNonce: +entity.txNonce,
      };
      const parsed = originIntent({
        ...entity,
        intent: { ...entity.intent, fees },
      });
      expect(parsed).to.be.deep.eq({
        ...expected,
        tokenFee: fees.tokenFee,
        nativeFee: fees.nativeFee,
        feeAdapterInitiator: fees.initiator,
        isSwap: undefined,
      });
    });

    it('should include order information when present', async () => {
      const order: OrderEntity = {
        id: mkBytes32('0xorder'),
        initiator: mkBytes32('0xorderInitiator'),
        intents: [{ id: entity.intent.id }],
        tokenFee: '4000',
        nativeFee: '3000',
        transactionHash: entity.transactionHash,
        timestamp: +entity.timestamp,
        gasPrice: entity.gasPrice,
        gasLimit: entity.gasLimit,
        blockNumber: +entity.blockNumber,
        txOrigin: entity.txOrigin,
        txNonce: +entity.txNonce,
      };
      const parsed = originIntent({
        ...entity,
        intent: { ...entity.intent, order },
      });
      expect(parsed).to.be.deep.eq({
        ...expected,
        orderId: order.id,
        isSwap: undefined,
      });
    });

    it('should handle both fees and order information together', async () => {
      const fees: FeesEntity = {
        id: mkBytes32('0xfees'),
        intent: { id: entity.intent.id },
        initiator: mkBytes32('0xfeeInitiator'),
        tokenFee: '1000',
        nativeFee: '2000',
        transactionHash: entity.transactionHash,
        timestamp: +entity.timestamp,
        gasPrice: entity.gasPrice,
        gasLimit: entity.gasLimit,
        blockNumber: +entity.blockNumber,
        txOrigin: entity.txOrigin,
        txNonce: +entity.txNonce,
      };
      const order: OrderEntity = {
        id: mkBytes32('0xorder'),
        initiator: mkBytes32('0xorderInitiator'),
        intents: [{ id: entity.intent.id }],
        tokenFee: '4000',
        nativeFee: '3000',
        transactionHash: entity.transactionHash,
        timestamp: +entity.timestamp,
        gasPrice: entity.gasPrice,
        gasLimit: entity.gasLimit,
        blockNumber: +entity.blockNumber,
        txOrigin: entity.txOrigin,
        txNonce: +entity.txNonce,
      };
      const parsed = originIntent({
        ...entity,
        intent: { ...entity.intent, fees, order },
      });
      expect(parsed).to.be.deep.eq({
        ...expected,
        tokenFee: fees.tokenFee,
        nativeFee: fees.nativeFee,
        feeAdapterInitiator: fees.initiator,
        orderId: order.id,
        isSwap: undefined,
      });
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
      fee: '0',
      amountOut: entity.amountOut,
      initiator: entity.intent.initiator,
      nonce: entity.intent.nonce,
      data: entity.intent.data,
      amountOutMin: entity.intent.amountOutMin,
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
    it('should work for the dispatched intent', () => { });
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
  describe('#protocolUpdateLog', () => {
    it('should parse GATEWAY_UPDATED with valueBytes to address', () => {
      const entity: MetaUpdateEntity = {
        id: '0xlog1',
        kind: 'GATEWAY_UPDATED',
        key: 'gateway',
        valueBytes: '0x0000000000000000000000001234567890123456789012345678901234567890',
        transactionHash: '0xabc',
        timestamp: '1000',
        blockNumber: '200',
        txOrigin: '0xorigin',
        txNonce: '5',
      };

      const result = protocolUpdateLog(domain, entity);

      const expected: ProtocolUpdateLog = {
        id: entity.id,
        domain,
        chainId: domain,
        event: 'GATEWAY_UPDATED',
        key: 'gateway',
        updated: '0x1234567890123456789012345678901234567890',
        transactionHash: entity.transactionHash,
        timestamp: 1000,
        blockNumber: 200,
        txOrigin: entity.txOrigin,
        txNonce: 5,
      };
      expect(result).to.deep.equal(expected);
    });

    it('should parse PAUSED with updated "True"', () => {
      const entity: MetaUpdateEntity = {
        id: '0xlog2',
        kind: 'PAUSED',
        key: 'paused',
        valueBigInt: '1',
        transactionHash: '0xdef',
        timestamp: '2000',
        blockNumber: '300',
        txOrigin: '0xorigin2',
        txNonce: '6',
      };

      const result = protocolUpdateLog(domain, entity);

      expect(result.event).to.equal('PAUSED');
      expect(result.key).to.equal('paused');
      expect(result.updated).to.equal('True');
      expect(result.timestamp).to.equal(2000);
      expect(result.blockNumber).to.equal(300);
      expect(result.txNonce).to.equal(6);
    });

    it('should use valueBigInt for chainId on HUB_CHAIN_GATEWAY_ADDED', () => {
      const entity: MetaUpdateEntity = {
        id: '0xlog3',
        kind: 'HUB_CHAIN_GATEWAY_ADDED',
        key: 'chainGateway',
        valueBytes: '0xgateway',
        valueBigInt: '1338',
        transactionHash: '0xghi',
        timestamp: '3000',
        blockNumber: '400',
        txOrigin: '0xorigin3',
        txNonce: '7',
      };

      const result = protocolUpdateLog(domain, entity);

      expect(result.chainId).to.equal('1338');
      expect(result.event).to.equal('HUB_CHAIN_GATEWAY_ADDED');
    });

    it('should parse LIGHTHOUSE_UPDATED using bytes32 address', () => {
      const entity: MetaUpdateEntity = {
        id: '0xlog4',
        kind: 'LIGHTHOUSE_UPDATED',
        key: 'lighthouse',
        valueBytes: '0x000000000000000000000000abcdefabcdefabcdefabcdefabcdefabcdefabcd',
        transactionHash: '0xjkl',
        timestamp: '4000',
        blockNumber: '500',
        txOrigin: '0xorigin4',
        txNonce: '8',
      };

      const result = protocolUpdateLog(domain, entity);

      expect(result.event).to.equal('LIGHTHOUSE_UPDATED');
      expect(result.key).to.equal('lighthouse');
      expect(result.updated).to.equal('0xabcdefabcdefabcdefabcdefabcdefabcdefabcd');
    });

    it('should parse MESSAGE_GAS_LIMIT_UPDATED using valueBigInt', () => {
      const entity: MetaUpdateEntity = {
        id: '0xlog5',
        kind: 'MESSAGE_GAS_LIMIT_UPDATED',
        key: 'messageGasLimit',
        valueBigInt: '12345',
        transactionHash: '0xmn0',
        timestamp: '5000',
        blockNumber: '600',
        txOrigin: '0xorigin5',
        txNonce: '9',
      };

      const result = protocolUpdateLog(domain, entity);

      expect(result.updated).to.equal('12345');
      expect(result.event).to.equal('MESSAGE_GAS_LIMIT_UPDATED');
    });

    it('should parse SPOKE_GATEWAY_MAILBOX_UPDATED using bytes32 address', () => {
      const entity: MetaUpdateEntity = {
        id: '0xlog6',
        kind: 'SPOKE_GATEWAY_MAILBOX_UPDATED',
        key: 'mailbox',
        valueBytes: '0x0000000000000000000000001111111111111111111111111111111111111111',
        transactionHash: '0xmailbox',
        timestamp: '6000',
        blockNumber: '700',
        txOrigin: '0xorigin6',
        txNonce: '10',
      };

      const result = protocolUpdateLog(domain, entity);

      expect(result.event).to.equal('SPOKE_GATEWAY_MAILBOX_UPDATED');
      expect(result.key).to.equal('mailbox');
      expect(result.updated).to.equal('0x1111111111111111111111111111111111111111');
      expect(result.timestamp).to.equal(6000);
      expect(result.blockNumber).to.equal(700);
      expect(result.txNonce).to.equal(10);
    });

    it('should parse SPOKE_GATEWAY_SECURITY_MODULE_UPDATED using bytes32 address', () => {
      const entity: MetaUpdateEntity = {
        id: '0xlog7',
        kind: 'SPOKE_GATEWAY_SECURITY_MODULE_UPDATED',
        key: 'securityModule',
        valueBytes: '0x0000000000000000000000002222222222222222222222222222222222222222',
        transactionHash: '0xsecurity',
        timestamp: '7000',
        blockNumber: '800',
        txOrigin: '0xorigin7',
        txNonce: '11',
      };

      const result = protocolUpdateLog(domain, entity);

      expect(result.event).to.equal('SPOKE_GATEWAY_SECURITY_MODULE_UPDATED');
      expect(result.key).to.equal('securityModule');
      expect(result.updated).to.equal('0x2222222222222222222222222222222222222222');
      expect(result.timestamp).to.equal(7000);
      expect(result.blockNumber).to.equal(800);
      expect(result.txNonce).to.equal(11);
    });
  });

  describe('#envioToOriginIntent', () => {
    it('should parse FILLED intent to settled origin intent', () => {
      const entity: any = {
        intentId: '0xintent',
        queueIdx: '1',
        status: 'FILLED',
        receiver: '0xreceiver',
        inputAsset: '0xinput',
        outputAsset: '0xoutput',
        originAmount: '100',
        amountOutMin: '90',
        destinations: [1338],
        origin: 1337,
        nonce: '5',
        data: '0x',
        ttl: '1000',
        transactionHash: '0xtx',
        timestamp: '1700000000',
        blockNumber: '123',
        sender: '0xsender',
        tokenFee: '1',
        nativeFee: '2',
        initiator: '0xinitiator',
      };

      const result = envioToOriginIntent(entity, '1339');

      expect(result.status).to.equal(TIntentStatus.Settled);
      expect(result.origin).to.equal('1339');
      expect(result.id).to.equal('0xintent');
      expect(result.queueIdx).to.equal(1);
      expect(result.amount).to.equal('100');
      expect(result.tokenFee).to.equal('1');
      expect(result.nativeFee).to.equal('2');
    });

    it('should default origin domain from entity when not provided', () => {
      const entity: any = {
        intentId: '0xintent',
        queueIdx: '1',
        status: 'ADDED',
        receiver: '0xreceiver',
        inputAsset: '0xinput',
        outputAsset: '0xoutput',
        originAmount: '100',
        amountOutMin: '90',
        destinations: [1338],
        origin: 1337,
        nonce: '5',
        data: '0x',
        ttl: '1000',
        transactionHash: '0xtx',
        timestamp: '1700000000',
        blockNumber: '123',
        sender: '0xsender',
        initiator: '0xinitiator',
      };

      const result = envioToOriginIntent(entity);

      expect(result.status).to.equal(TIntentStatus.Added);
      expect(result.origin).to.equal('1337');
    });
  });

  describe('#envioToDestinationIntent', () => {
    it('should return undefined when there are no fills', () => {
      const entity: any = {
        intentId: '0xintent',
        queueIdx: '1',
        status: 'FILLED',
        receiver: '0xreceiver',
        inputAsset: '0xinput',
        outputAsset: '0xoutput',
        originAmount: '100',
        amountOutMin: '90',
        destinations: [1338],
        origin: 1337,
        nonce: '5',
        data: '0x',
        ttl: '1000',
        fills: [],
      };

      const result = envioToDestinationIntent(entity, '1338');
      expect(result).to.be.undefined;
    });

    it('should return undefined when no fill matches destination domain', () => {
      const entity: any = {
        intentId: '0xintent',
        queueIdx: '1',
        status: 'FILLED',
        receiver: '0xreceiver',
        inputAsset: '0xinput',
        outputAsset: '0xoutput',
        originAmount: '100',
        amountOutMin: '90',
        destinations: [1338],
        origin: 1337,
        nonce: '5',
        data: '0x',
        ttl: '1000',
        fills: [
          {
            chainId: 9999,
          },
        ],
      };

      const result = envioToDestinationIntent(entity, '1338');
      expect(result).to.be.undefined;
    });

    it('should parse fill into destination intent when matching destination domain', () => {
      const entity: any = {
        intentId: '0xintent',
        queueIdx: '1',
        status: 'FILLED',
        receiver: '0xreceiver',
        inputAsset: '0xinput',
        outputAsset: '0xoutput',
        originAmount: '100',
        amountOutMin: '90',
        destinations: [1338],
        origin: 1337,
        nonce: '5',
        data: '0x',
        ttl: '1000',
        initiator: '0xinitiator',
        fills: [
          {
            chainId: 1338,
            fillAmount: '80',
            transactionHash: '0xfill',
            timestamp: '1700000100',
            blockNumber: '124',
            nonce: '6',
            solver: '0xsolver',
          },
        ],
      };

      const result = envioToDestinationIntent(entity, '1338');
      expect(result).to.not.be.undefined;
      expect(result!.id).to.equal('0xintent');
      expect(result!.destination).to.equal('1338');
      expect(result!.amountOut).to.equal('80');
      expect(result!.transactionHash).to.equal('0xfill');
    });
  });

  describe('#hubTokenUpdateLog', () => {
    it('should apply defaults when optional fields are missing', () => {
      const entity: HubTokenUpdateEntity = {
        id: mkBytes32('0xhubTokenUpdate'),
        token: { id: mkBytes32('0xticker') },
        kind: 'TOKEN_CONFIGS_SET',
        transactionHash: mkBytes32('0xtx'),
        timestamp: '10',
        blockNumber: '20',
        txOrigin: mkBytes32('0xorigin'),
        txNonce: '3',
      };

      const parsed = hubTokenUpdateLog(domain, entity);
      const expected: HubTokenUpdateLog = {
        id: entity.id,
        domain,
        tickerHash: entity.token.id,
        kind: entity.kind,
        feeRecipients: [],
        feeAmounts: [],
        maxDiscountBps: 0,
        discountPerEpoch: 0,
        prioritizedStrategy: 'DEFAULT',
        transactionHash: entity.transactionHash,
        timestamp: 10,
        blockNumber: 20,
        txOrigin: entity.txOrigin,
        txNonce: 3,
      };
      expect(parsed).to.deep.equal(expected);
    });

    it('should parse all fields when present', () => {
      const entity: HubTokenUpdateEntity = {
        id: mkBytes32('0xhubTokenUpdate2'),
        token: { id: mkBytes32('0xticker2') },
        kind: 'MAX_DISCOUNT_SET',
        feeRecipients: [mkBytes32('0xfeeRecipient1')],
        feeAmounts: ['1', '2'],
        maxDiscountBps: '123',
        discountPerEpoch: '7',
        prioritizedStrategy: 'FAST',
        transactionHash: mkBytes32('0xtx2'),
        timestamp: '11',
        blockNumber: '21',
        txOrigin: mkBytes32('0xorigin2'),
        txNonce: '4',
      };

      const parsed = hubTokenUpdateLog(domain, entity);
      expect(parsed.feeRecipients).to.deep.equal(entity.feeRecipients);
      expect(parsed.feeAmounts).to.deep.equal(entity.feeAmounts);
      expect(parsed.maxDiscountBps).to.equal(123);
      expect(parsed.discountPerEpoch).to.equal(7);
      expect(parsed.prioritizedStrategy).to.equal('FAST');
    });
  });

  describe('#hubAssetUpdateLog', () => {
    it('should apply defaults for nullable fields', () => {
      const entity: HubAssetUpdateEntity = {
        id: mkBytes32('0xhubAssetUpdate'),
        asset: { id: mkBytes32('0xasset') },
        token: null,
        tickerHash: null,
        domain: null,
        kind: 'ASSET_CONFIG_SET',
        assetHash: null,
        adopted: null,
        approval: null,
        strategy: null,
        transactionHash: mkBytes32('0xtx'),
        timestamp: '12',
        blockNumber: '22',
        txOrigin: mkBytes32('0xorigin'),
        txNonce: '5',
      };

      const parsed = hubAssetUpdateLog(domain, entity);
      const expected: HubAssetUpdateLog = {
        id: entity.id,
        domain,
        tickerHash: '',
        tokenId: undefined,
        assetId: entity.asset.id,
        assetDomain: '',
        kind: entity.kind,
        assetHash: '',
        adopted: '',
        approval: false,
        strategy: '',
        transactionHash: entity.transactionHash,
        timestamp: 12,
        blockNumber: 22,
        txOrigin: entity.txOrigin,
        txNonce: 5,
      };
      expect(parsed).to.deep.equal(expected);
    });

    it('should parse fields when present', () => {
      const entity: HubAssetUpdateEntity = {
        id: mkBytes32('0xhubAssetUpdate2'),
        asset: { id: mkBytes32('0xasset2') },
        token: { id: mkBytes32('0xticker2') },
        tickerHash: mkBytes32('0xticker2'),
        domain: '1338',
        kind: 'ASSET_CONFIG_SET',
        assetHash: mkBytes32('0xhash'),
        adopted: mkBytes32('0xadopted'),
        approval: true,
        strategy: 'DEFAULT',
        transactionHash: mkBytes32('0xtx2'),
        timestamp: '13',
        blockNumber: '23',
        txOrigin: mkBytes32('0xorigin2'),
        txNonce: '6',
      };

      const parsed = hubAssetUpdateLog(domain, entity);
      expect(parsed.tokenId).to.equal(entity.token!.id);
      expect(parsed.tickerHash).to.equal(entity.tickerHash);
      expect(parsed.assetDomain).to.equal(entity.domain);
      expect(parsed.approval).to.equal(true);
    });
  });

  describe('#hubMeta', () => {
    it('should map arrays when present', () => {
      const entity: HubMetaEntity = {
        id: mkBytes32('0xhubMeta'),
        domain,
        paused: false,
        owner: mkBytes32('0xowner'),
        proposedOwner: mkBytes32('0xproposed'),
        proposedOwnershipTimestamp: '0',
        gateway: mkBytes32('0xgateway'),
        watchtower: mkBytes32('0xwatchtower'),
        manager: mkBytes32('0xmanager'),
        settler: mkBytes32('0xsettler'),
        minSolverSupportedDomains: '1',
        expiryTimeBuffer: '2',
        discountPerEpoch: '3',
        epochLength: '4',
        mailbox: mkBytes32('0xmailbox'),
        securityModule: mkBytes32('0xsec'),
        supportedDomains: [{ domain: '1338', blockGasLimit: '123' }],
        chainGateways: [{ chainId: '1338', gateway: mkBytes32('0xgw') }],
        acceptanceDelay: '5',
      };

      const parsed = hubMeta(entity);
      const expected: HubMeta = {
        id: entity.id,
        domain: entity.domain,
        paused: entity.paused,
        owner: entity.owner,
        proposedOwner: entity.proposedOwner,
        proposedOwnershipTimestamp: entity.proposedOwnershipTimestamp,
        gateway: entity.gateway,
        watchtower: entity.watchtower,
        manager: entity.manager,
        settler: entity.settler,
        minSolverSupportedDomains: entity.minSolverSupportedDomains,
        expiryTimeBuffer: entity.expiryTimeBuffer,
        discountPerEpoch: entity.discountPerEpoch,
        epochLength: entity.epochLength,
        mailbox: entity.mailbox,
        securityModule: entity.securityModule,
        acceptanceDelay: entity.acceptanceDelay,
        supportedDomains: [{ domain: '1338', blockGasLimit: '123' }],
        chainGateways: [{ chainId: '1338', gateway: mkBytes32('0xgw') }],
      };
      expect(parsed).to.deep.equal(expected);
    });

    it('should allow supportedDomains/chainGateways to be missing', () => {
      const entity = {
        id: mkBytes32('0xhubMeta2'),
        domain,
      } as any as HubMetaEntity;

      const parsed = hubMeta(entity);
      expect(parsed.supportedDomains).to.equal(undefined);
      expect(parsed.chainGateways).to.equal(undefined);
    });
  });

  describe('#spokeMeta', () => {
    it('should map moduleForStrategies when present', () => {
      const entity: SpokeMetaEntity = {
        id: mkBytes32('0xspokeMeta'),
        domain,
        paused: false,
        gateway: mkBytes32('0xgateway'),
        lighthouse: mkBytes32('0xlighthouse'),
        messageReceiver: mkBytes32('0xreceiver'),
        watchtower: mkBytes32('0xwatchtower'),
        messageGasLimit: '1000',
        feeAdapter: mkBytes32('0xfeeAdapter'),
        feeAdapterRecipient: mkBytes32('0xfeeRecipient'),
        fillSigner: mkBytes32('0xfillSigner'),
        feeSigner: mkBytes32('0xfeeSigner'),
        mailbox: mkBytes32('0xmailbox'),
        securityModule: mkBytes32('0xsec'),
        moduleForStrategies: [{ strategy: 'DEFAULT', module: mkBytes32('0xmodule') }],
      };

      const parsed = spokeMeta(entity);
      const expected: SpokeMeta = {
        id: entity.id,
        domain: entity.domain,
        paused: entity.paused,
        gateway: entity.gateway,
        lighthouse: entity.lighthouse,
        messageReceiver: entity.messageReceiver,
        watchtower: entity.watchtower,
        messageGasLimit: entity.messageGasLimit,
        feeAdapter: entity.feeAdapter,
        feeAdapterRecipient: entity.feeAdapterRecipient,
        fillSigner: entity.fillSigner,
        feeSigner: entity.feeSigner,
        mailbox: entity.mailbox,
        securityModule: entity.securityModule,
        moduleForStrategies: [{ strategy: 'DEFAULT', module: mkBytes32('0xmodule') }],
      };
      expect(parsed).to.deep.equal(expected);
    });

    it('should allow moduleForStrategies to be missing', () => {
      const entity = {
        id: mkBytes32('0xspokeMeta2'),
        domain,
      } as any as SpokeMetaEntity;

      const parsed = spokeMeta(entity);
      expect(parsed.moduleForStrategies).to.equal(undefined);
    });
  });

  describe('#order', () => {
    it('should parse order entity', () => {
      const entity: OrderEntity = {
        id: mkBytes32('0xorder'),
        initiator: mkBytes32('0xinitiator'),
        intents: [{ id: mkBytes32('0xintent1') }, { id: mkBytes32('0xintent2') }],
        tokenFee: '10',
        nativeFee: '20',
        transactionHash: mkBytes32('0xtx'),
        timestamp: 1,
        gasPrice: '2',
        gasLimit: '3',
        blockNumber: 100,
        txOrigin: mkBytes32('0xorigin'),
        txNonce: 7,
      };

      const parsed = order(domain, entity);
      const expected: Order & { domain: string } = {
        domain,
        id: entity.id,
        autoId: 7,
        intentIds: [mkBytes32('0xintent1'), mkBytes32('0xintent2')],
        tokenFee: entity.tokenFee,
        nativeFee: entity.nativeFee,
        initiator: entity.initiator,
        transactionHash: entity.transactionHash,
        blockNumber: 100,
        gasLimit: entity.gasLimit,
        gasPrice: entity.gasPrice,
        txOrigin: entity.txOrigin,
        txNonce: 7,
        timestamp: 1,
      };
      expect(parsed).to.deep.equal(expected);
    });
  });
});
