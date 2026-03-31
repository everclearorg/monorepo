import { SinonStub, stub, restore } from 'sinon';
import { expect, mkAddress, mkBytes32 } from '@chimera-monorepo/utils';
import { EnvioReader } from '../../src/envio';
import { SubgraphQueryMetaParams } from '../../src';
import * as Helpers from '../../src/lib/helpers';
import * as parser from '../../src/lib/helpers/parse';
import { RuntimeError } from '../../src/lib/errors';
import { EnvioIntentEntity } from '../../src/lib/helpers/parse';

describe('EnvioReader', () => {
  const envioConfig = {
    url: 'https://envio.example.com/graphql',
    apiKey: 'test-key',
    timeout: 10,
  };

  const config = {
    subgraphs: {},
    envio: envioConfig,
  };

  let executeEnvioQuery: SinonStub;
  let reader: EnvioReader;

  beforeEach(() => {
    restore();
    (EnvioReader as any).instance = undefined;

    executeEnvioQuery = stub();
    stub(Helpers, 'getHelpers').returns({
      execute: stub(),
      parser,
      executeEnvioQuery,
    });

    reader = EnvioReader.create(config);
  });

  // ============================================================================
  // Test data factories
  // ============================================================================

  const createEnvioFillEntity = (overrides: Partial<any> = {}): any => {
    const now = Math.floor(Date.now() / 1000);
    return {
      id: '1',
      intentId: mkBytes32('0x1'),
      solver: mkAddress('0x3'),
      totalFeeDBPS: '100',
      queueIdx: '1',
      initiator: mkAddress('0x1'),
      receiver: mkAddress('0x2'),
      inputAsset: mkAddress('0xa'),
      outputAsset: mkAddress('0xb'),
      maxFee: 100,
      origin: 1337,
      nonce: '1',
      timestamp: now.toString(),
      ttl: '1000',
      originAmount: '1000000000',
      fillAmount: '950000000',
      destinations: [1338],
      data: '0x',
      chainId: 1338,
      blockNumber: '200',
      blockTimestamp: now.toString(),
      transactionHash: mkBytes32('0x2'),
      ...overrides,
    };
  };

  const createEnvioIntentEntity = (overrides: Partial<EnvioIntentEntity> = {}): EnvioIntentEntity => {
    const now = Math.floor(Date.now() / 1000);
    return {
      id: '1',
      intentId: mkBytes32('0x1'),
      status: 'ADDED',
      initiator: mkAddress('0x1'),
      receiver: mkAddress('0x2'),
      inputAsset: mkAddress('0xa'),
      outputAsset: mkAddress('0xb'),
      originAmount: '1000000000',
      amountOutMin: '50',
      maxFee: 100,
      ttl: '1000',
      origin: 1337,
      destinations: [1338],
      nonce: '1',
      blockTimestamp: now.toString(),
      blockNumber: '123',
      transactionHash: mkBytes32('0x1'),
      data: '0x',
      tokenFee: undefined,
      nativeFee: undefined,
      fills: [],
      receiveBlockNumber: undefined,
      isFastPath: true,
      queueIdx: '1',
      chainId: 1337,
      sender: mkAddress('0x1'),
      timestamp: now.toString(),
      ...overrides,
    };
  };

  const createEnvioHubIntentEntity = (overrides: Partial<any> = {}): any => ({
    id: mkBytes32('0x1'),
    status: 'ADDED',
    settlementId: null,
    messageId: null,
    addEventTransactionHash: mkBytes32('0xa'),
    addEventTimestamp: '1000',
    addEventBlockNumber: '100',
    addEventTxNonce: '5',
    fillEventTransactionHash: null,
    fillEventTimestamp: null,
    fillEventBlockNumber: null,
    fillEventTxNonce: null,
    ...overrides,
  });

  const createEnvioHubSettlementEntity = (overrides: Partial<any> = {}): any => ({
    id: mkBytes32('0x1'),
    intentId: mkBytes32('0x1'),
    queueIdx: '10',
    amount: '1000000',
    asset: mkAddress('0xa'),
    updateVirtualBalance: false,
    recipient: mkAddress('0x2'),
    domain: 1338,
    entryEpoch: '5',
    enqueuedTransactionHash: mkBytes32('0xb'),
    enqueuedTimestamp: '2000',
    enqueuedBlockNumber: '200',
    enqueuedTxOrigin: mkAddress('0x1'),
    enqueuedTxNonce: '10',
    ...overrides,
  });

  const createEnvioInvoiceEntity = (overrides: Partial<any> = {}): any => ({
    id: mkBytes32('0xf'),
    intentId: mkBytes32('0x1'),
    tickerHash: mkBytes32('0xabc'),
    amount: '500000',
    owner: mkAddress('0x5'),
    entryEpoch: '3',
    transactionHash: mkBytes32('0xc'),
    timestamp: '1500',
    blockNumber: '150',
    txOrigin: mkAddress('0x1'),
    txNonce: '7',
    ...overrides,
  });

  const createEnvioDepositEntity = (overrides: Partial<any> = {}): any => ({
    id: mkBytes32('0x1'),
    intentId: mkBytes32('0x1'),
    epoch: '5',
    domain: 1338,
    amount: '1000000',
    tickerHash: mkBytes32('0xabc'),
    enqueuedTransactionHash: mkBytes32('0xa'),
    enqueuedTimestamp: '1000',
    enqueuedBlockNumber: '100',
    enqueuedTxNonce: '5',
    processedTransactionHash: null,
    processedTimestamp: null,
    processedBlockNumber: null,
    processedTxNonce: null,
    ...overrides,
  });

  // ============================================================================
  // Core infrastructure
  // ============================================================================

  describe('#create', () => {
    it('should create a new instance', () => {
      expect(reader).to.be.instanceOf(EnvioReader);
    });
  });

  describe('#queryEnvio', () => {
    it('should throw if envio config is missing', async () => {
      (EnvioReader as any).instance = undefined;
      const readerWithoutConfig = EnvioReader.create({ subgraphs: {} });
      await expect(readerWithoutConfig.queryEnvio('query')).to.be.rejectedWith('Envio configuration is missing');
    });

    it('should execute query successfully', async () => {
      const data = { Intent: [createEnvioIntentEntity()] };
      executeEnvioQuery.resolves(data);

      const result = await reader.queryEnvio('query', {});
      expect(result).to.be.deep.eq(data);
    });

    it('should handle errors', async () => {
      executeEnvioQuery.rejects(new Error('query error'));
      await expect(reader.queryEnvio('query')).to.be.rejectedWith(RuntimeError);
    });
  });

  describe('#query', () => {
    it('should return undefined for empty queries', async () => {
      const result = await reader.query('1337', []);
      expect(result).to.be.undefined;
    });

    it('should execute first query', async () => {
      const data = { Intent: [createEnvioIntentEntity()] };
      executeEnvioQuery.resolves(data);

      const result = await reader.query('1337', ['query']);
      expect(result).to.be.deep.eq({ data, domain: '1337' });
    });
  });

  // ============================================================================
  // Block number
  // ============================================================================

  describe('#getLatestBlockNumber', () => {
    it('should return block numbers for domains', async () => {
      executeEnvioQuery.resolves({
        chain_metadata: [
          { chain_id: 1337, latest_processed_block: 100 },
          { chain_id: 1338, latest_processed_block: 200 },
        ],
      });

      const result = await reader.getLatestBlockNumber(['1337', '1338']);
      expect(result.get('1337')).to.be.eq(100);
      expect(result.get('1338')).to.be.eq(200);
    });

    it('should handle errors gracefully', async () => {
      executeEnvioQuery.rejects(new Error('error'));

      const result = await reader.getLatestBlockNumber(['1337']);
      expect(result.get('1337')).to.be.undefined;
      expect(result.size).to.be.eq(0);
    });
  });

  // ============================================================================
  // Single entity by ID — Spoke intents
  // ============================================================================

  describe('#getOriginIntentById', () => {
    it('should return origin intent', async () => {
      const intent = createEnvioIntentEntity({ intentId: mkBytes32('0x1'), origin: 1337 });
      executeEnvioQuery.resolves({ Intent: [intent] });

      const result = await reader.getOriginIntentById('1337', mkBytes32('0x1'));
      expect(result).to.not.be.undefined;
      expect(result?.id).to.be.eq(mkBytes32('0x1'));
      expect(result?.origin).to.be.eq('1337');
    });

    it('should return undefined if intent not found', async () => {
      executeEnvioQuery.resolves({ Intent: [] });
      const result = await reader.getOriginIntentById('1337', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });

    it('should filter by origin domain', async () => {
      const intent = createEnvioIntentEntity({ intentId: mkBytes32('0x1'), origin: 1338 });
      executeEnvioQuery.resolves({ Intent: [intent] });
      const result = await reader.getOriginIntentById('1337', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getDestinationIntentById', () => {
    it('should return destination intent', async () => {
      const intent = createEnvioIntentEntity({
        intentId: mkBytes32('0x1'),
        status: 'FILLED',
        destinations: [1338],
        fills: [createEnvioFillEntity()],
      });
      executeEnvioQuery.resolves({ Intent: [intent] });

      const result = await reader.getDestinationIntentById('1338', mkBytes32('0x1'));
      expect(result).to.not.be.undefined;
      expect(result?.id).to.be.eq(mkBytes32('0x1'));
      expect(result?.destination).to.be.eq('1338');
    });

    it('should return undefined if intent not found', async () => {
      executeEnvioQuery.resolves({ Intent: [] });
      const result = await reader.getDestinationIntentById('1338', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });

    it('should return undefined if destination domain not in destinations', async () => {
      const intent = createEnvioIntentEntity({
        intentId: mkBytes32('0x1'),
        status: 'FILLED',
        destinations: [1337],
      });
      executeEnvioQuery.resolves({ Intent: [intent] });
      const result = await reader.getDestinationIntentById('1338', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  // ============================================================================
  // Single entity by ID — Hub entities
  // ============================================================================

  describe('#getHubIntentById', () => {
    it('should return hub intent from Envio', async () => {
      const hubIntent = createEnvioHubIntentEntity();
      const settlement = createEnvioHubSettlementEntity();
      executeEnvioQuery.resolves({ HubIntent: [hubIntent], HubSettlement: [settlement] });

      const result = await reader.getHubIntentById('25327', mkBytes32('0x1'));
      expect(result).to.not.be.undefined;
      expect(result?.id).to.be.eq(mkBytes32('0x1'));
      expect(result?.domain).to.be.eq('25327');
      expect(result?.addedTimestamp).to.be.eq(1000);
      expect(result?.settlementDomain).to.be.eq('1338');
    });

    it('should return hub intent without settlement', async () => {
      const hubIntent = createEnvioHubIntentEntity();
      executeEnvioQuery.resolves({ HubIntent: [hubIntent], HubSettlement: [] });

      const result = await reader.getHubIntentById('25327', mkBytes32('0x1'));
      expect(result).to.not.be.undefined;
      expect(result?.settlementDomain).to.be.undefined;
    });

    it('should return undefined if not found', async () => {
      executeEnvioQuery.resolves({ HubIntent: [], HubSettlement: [] });
      const result = await reader.getHubIntentById('25327', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getHubInvoiceById', () => {
    it('should return hub invoice from Envio', async () => {
      const invoice = createEnvioInvoiceEntity();
      const hubIntent = createEnvioHubIntentEntity();
      executeEnvioQuery.resolves({ Invoice: [invoice], HubIntent: [hubIntent] });

      const result = await reader.getHubInvoiceById('25327', mkBytes32('0x1'));
      expect(result).to.not.be.undefined;
      expect(result?.intentId).to.be.eq(mkBytes32('0x1'));
      expect(result?.tickerHash).to.be.eq(mkBytes32('0xabc'));
      expect(result?.entryEpoch).to.be.eq(3);
    });

    it('should return undefined if not found', async () => {
      executeEnvioQuery.resolves({ Invoice: [], HubIntent: [] });
      const result = await reader.getHubInvoiceById('25327', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getSettlementIntentById', () => {
    it('should return settlement intent from Envio', async () => {
      const entity = {
        id: mkBytes32('0x1'),
        status: 'SETTLED',
        recipient: mkAddress('0x2'),
        asset: mkAddress('0xa'),
        amount: '1000000',
        settlementTransactionHash: mkBytes32('0xb'),
        settlementTimestamp: '2000',
        settlementBlockNumber: '200',
        settlementTxOrigin: mkAddress('0x1'),
        settlementTxNonce: '10',
        settlementGasPrice: '1000',
        settlementGasLimit: '21000',
      };
      executeEnvioQuery.resolves({ SettlementIntent: [entity] });

      const result = await reader.getSettlementIntentById('1338', mkBytes32('0x1'));
      expect(result).to.not.be.undefined;
      expect(result?.intentId).to.be.eq(mkBytes32('0x1'));
      expect(result?.domain).to.be.eq('1338');
      expect(result?.amount).to.be.eq('1000000');
    });

    it('should return undefined if not found', async () => {
      executeEnvioQuery.resolves({ SettlementIntent: [] });
      const result = await reader.getSettlementIntentById('1338', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getHubDepositEnqueuedById', () => {
    it('should return enqueued deposit from Envio', async () => {
      const deposit = createEnvioDepositEntity();
      const hubIntent = createEnvioHubIntentEntity();
      executeEnvioQuery.resolves({ Deposit: [deposit], HubIntent: [hubIntent] });

      const result = await reader.getHubDepositEnqueuedById('25327', mkBytes32('0x1'));
      expect(result).to.not.be.undefined;
      expect(result?.intentId).to.be.eq(mkBytes32('0x1'));
      expect(result?.enqueuedTimestamp).to.be.eq(1000);
    });

    it('should return undefined if deposit has no enqueued timestamp', async () => {
      const deposit = createEnvioDepositEntity({ enqueuedTimestamp: null });
      executeEnvioQuery.resolves({ Deposit: [deposit], HubIntent: [] });

      const result = await reader.getHubDepositEnqueuedById('25327', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });

    it('should return undefined if not found', async () => {
      executeEnvioQuery.resolves({ Deposit: [], HubIntent: [] });
      const result = await reader.getHubDepositEnqueuedById('25327', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getHubDepositProcessedById', () => {
    it('should return processed deposit from Envio', async () => {
      const deposit = createEnvioDepositEntity({
        processedTransactionHash: mkBytes32('0xc'),
        processedTimestamp: '3000',
        processedBlockNumber: '300',
        processedTxNonce: '15',
      });
      const hubIntent = createEnvioHubIntentEntity();
      executeEnvioQuery.resolves({ Deposit: [deposit], HubIntent: [hubIntent] });

      const result = await reader.getHubDepositProcessedById('25327', mkBytes32('0x1'));
      expect(result).to.not.be.undefined;
      expect(result?.processedTimestamp).to.be.eq(3000);
    });

    it('should return undefined if deposit has no processed timestamp', async () => {
      const deposit = createEnvioDepositEntity();
      executeEnvioQuery.resolves({ Deposit: [deposit], HubIntent: [] });

      const result = await reader.getHubDepositProcessedById('25327', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  // ============================================================================
  // Spoke entity lists
  // ============================================================================

  describe('#getDepositorEvents', () => {
    it('should return depositor events from Envio', async () => {
      const event = {
        id: '1',
        depositor: mkAddress('0x1'),
        eventType: 'DEPOSIT',
        asset: mkAddress('0xa'),
        amount: '1000000',
        balance: '5000000',
        txOrigin: mkAddress('0x1'),
        transactionHash: mkBytes32('0xa'),
        timestamp: '1000',
        blockNumber: '100',
        txNonce: '5',
        gasPrice: '1000',
        gasLimit: '21000',
        chainId: 1337,
      };
      executeEnvioQuery.resolves({ DepositorEvent: [event] });

      const result = await reader.getDepositorEvents('1337', 50);
      expect(result.length).to.be.eq(1);
      expect(result[0].depositor).to.be.eq(mkAddress('0x1'));
      expect(result[0].type).to.be.eq('DEPOSIT');
    });

    it('should return empty when no events', async () => {
      executeEnvioQuery.resolves({ DepositorEvent: [] });
      const result = await reader.getDepositorEvents('1337', 0);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getTokens', () => {
    it('should return tokens and assets from Envio', async () => {
      const token = {
        id: mkBytes32('0xabc'),
        feeRecipients: [mkAddress('0x5')],
        feeAmounts: ['100'],
        maxDiscountBps: '500',
        discountPerEpoch: '10',
        prioritizedStrategy: 'DEFAULT',
      };
      const asset = {
        id: `${mkBytes32('0xabc')}-1338`,
        tickerHash: mkBytes32('0xabc'),
        domain: 1338,
        adopted: mkAddress('0xa'),
        approval: true,
        strategy: 'DEFAULT',
      };
      executeEnvioQuery.resolves({ Token: [token], HubAsset: [asset] });

      const [tokens, assets] = await reader.getTokens('25327');
      expect(tokens.length).to.be.eq(1);
      expect(tokens[0].id).to.be.eq(mkBytes32('0xabc'));
      expect(assets.length).to.be.eq(1);
      expect(assets[0].domain).to.be.eq('1338');
    });
  });

  describe('#getSpokeQueues', () => {
    it('should return queues for domain', async () => {
      const queue = {
        id: '1337-INTENT',
        queueType: 'INTENT',
        lastProcessed: '5',
        size: '10',
        first: '1',
        last: '10',
        chainId: 1337,
      };
      executeEnvioQuery.resolves({ Queue: [queue] });

      const result = await reader.getSpokeQueues('1337');
      expect(result.length).to.be.eq(1);
      expect(result[0].domain).to.be.eq('1337');
      expect(result[0].type).to.be.eq('INTENT');
    });
  });

  describe('#getSettlementQueues', () => {
    it('should return settlement queues', async () => {
      const queue = { id: '1338', domain: 1338, lastProcessed: '3', size: '5', first: '1', last: '5' };
      executeEnvioQuery.resolves({ SettlementQueue: [queue] });

      const result = await reader.getSettlementQueues('25327');
      expect(result.length).to.be.eq(1);
      expect(result[0].domain).to.be.eq('1338');
    });
  });

  describe('#getDepositQueues', () => {
    it('should return deposit queues', async () => {
      const queue = {
        id: '5-1338-ticker',
        epoch: '5',
        domain: 1338,
        tickerHash: mkBytes32('0xabc'),
        lastProcessed: null,
        size: '3',
        first: '1',
        last: '3',
        blockNumber: '200',
      };
      executeEnvioQuery.resolves({ DepositQueue: [queue] });

      const result = await reader.getDepositQueues('25327', 100);
      expect(result.length).to.be.eq(1);
      expect(result[0].epoch).to.be.eq(5);
    });
  });

  describe('#getDepositsEnqueuedByNonce', () => {
    it('should return enqueued deposits', async () => {
      const deposit = createEnvioDepositEntity();
      executeEnvioQuery.resolves({ Deposit: [deposit] });

      const result = await reader.getDepositsEnqueuedByNonce('25327', 50, 500);
      expect(result.length).to.be.eq(1);
      expect(result[0].enqueuedTimestamp).to.be.eq(1000);
    });
  });

  describe('#getDepositsProcessedByNonce', () => {
    it('should return processed deposits', async () => {
      const deposit = createEnvioDepositEntity({
        processedTimestamp: '3000',
        processedBlockNumber: '300',
        processedTxNonce: '15',
      });
      executeEnvioQuery.resolves({ Deposit: [deposit] });

      const result = await reader.getDepositsProcessedByNonce('25327', 50, 500);
      expect(result.length).to.be.eq(1);
      expect(result[0].processedTimestamp).to.be.eq(3000);
    });
  });

  describe('#getSpokeMessages', () => {
    it('should return messages for domain', async () => {
      const message = {
        id: mkBytes32('0xm1'),
        messageType: 'INTENT',
        quote: '1000',
        firstIdx: '0',
        lastIdx: '5',
        intentIds: [mkBytes32('0x1')],
        txOrigin: mkAddress('0x1'),
        transactionHash: mkBytes32('0xa'),
        timestamp: '1000',
        blockNumber: '100',
        txNonce: '5',
        gasPrice: '1000',
        gasLimit: '21000',
        chainId: 1337,
      };
      executeEnvioQuery.resolves({ Message: [message] });

      const result = await reader.getSpokeMessages('1337', 50);
      expect(result.length).to.be.eq(1);
      expect(result[0].id).to.be.eq(mkBytes32('0xm1'));
      expect(result[0].domain).to.be.eq('1337');
    });
  });

  describe('#getHubMessages', () => {
    it('should return settlement messages', async () => {
      const message = {
        id: mkBytes32('0xm2'),
        quote: '2000',
        domain: 1338,
        intentIds: [mkBytes32('0x1')],
        messageType: 'SETTLED',
        txOrigin: mkAddress('0x1'),
        transactionHash: mkBytes32('0xb'),
        timestamp: '2000',
        blockNumber: '200',
        txNonce: '10',
        gasPrice: '1000',
        gasLimit: '21000',
      };
      executeEnvioQuery.resolves({ SettlementMessage: [message] });

      const result = await reader.getHubMessages('25327', 50);
      expect(result.length).to.be.eq(1);
      expect(result[0].settlementDomain).to.be.eq('1338');
    });
  });

  // ============================================================================
  // Meta
  // ============================================================================

  describe('#getHubMeta', () => {
    it('should return hub meta with domain entities', async () => {
      const meta = {
        id: 'HUB_META',
        domain: 25327,
        paused: false,
        owner: mkAddress('0x1'),
        proposedOwner: null,
        proposedOwnershipTimestamp: null,
        gateway: mkAddress('0x2'),
        watchtower: mkAddress('0x3'),
        mailbox: mkAddress('0x4'),
        securityModule: mkAddress('0x5'),
        acceptanceDelay: '3600',
        minSolverSupportedDomains: 3,
        epochLength: '7200',
        expiryTimeBuffer: '600',
        supportedDomains: [1337, 1338],
      };
      const domains = [
        { id: '1337', domain: 1337, blockGasLimit: '30000000' },
        { id: '1338', domain: 1338, blockGasLimit: '15000000' },
      ];
      executeEnvioQuery.resolves({ HubMeta: [meta], Domain: domains });

      const result = await reader.getHubMeta('25327');
      expect(result).to.not.be.undefined;
      expect(result?.paused).to.be.false;
      expect(result?.supportedDomains).to.have.length(2);
    });

    it('should return undefined if not found', async () => {
      executeEnvioQuery.resolves({ HubMeta: [], Domain: [] });
      const result = await reader.getHubMeta('25327');
      expect(result).to.be.undefined;
    });
  });

  describe('#getSpokeMeta', () => {
    it('should return spoke meta', async () => {
      const meta = {
        id: '1337',
        domain: 1337,
        paused: false,
        gateway: mkAddress('0x1'),
        lighthouse: mkAddress('0x2'),
        messageReceiver: mkAddress('0x3'),
        watchtower: mkAddress('0x4'),
        messageGasLimit: '500000',
        feeAdapter: mkAddress('0x5'),
        fillSigner: mkAddress('0x6'),
      };
      executeEnvioQuery.resolves({ SpokeMeta: [meta] });

      const result = await reader.getSpokeMeta('1337');
      expect(result).to.not.be.undefined;
      expect(result?.domain).to.be.eq('1337');
      expect(result?.paused).to.be.false;
    });

    it('should return undefined if not found', async () => {
      executeEnvioQuery.resolves({ SpokeMeta: [] });
      const result = await reader.getSpokeMeta('1337');
      expect(result).to.be.undefined;
    });
  });

  // ============================================================================
  // Audit trail stubs (intentionally empty)
  // ============================================================================

  describe('audit trail stubs', () => {
    it('getHubMetaUpdates should return empty array', async () => {
      const result = await reader.getHubMetaUpdates('25327', 0);
      expect(result).to.be.deep.eq([]);
    });

    it('getSpokeMetaUpdates should return empty array', async () => {
      const result = await reader.getSpokeMetaUpdates('1337', 0);
      expect(result).to.be.deep.eq([]);
    });

    it('getHubTokenUpdates should return empty array', async () => {
      const result = await reader.getHubTokenUpdates('25327', 0);
      expect(result).to.be.deep.eq([]);
    });

    it('getHubAssetUpdates should return empty array', async () => {
      const result = await reader.getHubAssetUpdates('25327', 0);
      expect(result).to.be.deep.eq([]);
    });
  });

  // ============================================================================
  // Batch queries by nonce
  // ============================================================================

  describe('#getOriginIntentsByNonce', () => {
    it('should return origin intents', async () => {
      const intent1 = createEnvioIntentEntity({ intentId: mkBytes32('0x1'), origin: 1337, blockNumber: '100' });
      const intent2 = createEnvioIntentEntity({ intentId: mkBytes32('0x2'), origin: 1337, blockNumber: '101' });

      executeEnvioQuery.resolves({ Intent: [intent1, intent2] });

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getOriginIntentsByNonce(queryParams);
      expect(result.length).to.be.eq(2);
      expect(result[0].id).to.be.eq(mkBytes32('0x1'));
      expect(result[1].id).to.be.eq(mkBytes32('0x2'));
    });

    it('should filter by origin domains', async () => {
      const intent1 = createEnvioIntentEntity({ intentId: mkBytes32('0x1'), origin: 1337 });
      const intent2 = createEnvioIntentEntity({ intentId: mkBytes32('0x2'), origin: 1338 });

      executeEnvioQuery.resolves({ Intent: [intent1, intent2] });

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getOriginIntentsByNonce(queryParams);
      expect(result.length).to.be.eq(1);
      expect(result[0].id).to.be.eq(mkBytes32('0x1'));
    });

    it('should handle errors gracefully', async () => {
      executeEnvioQuery.rejects(new Error('error'));

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getOriginIntentsByNonce(queryParams);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getSettlementIntentsByNonce', () => {
    it('should return settlement intents from Envio', async () => {
      const entity = {
        id: mkBytes32('0x1'),
        status: 'SETTLED',
        recipient: mkAddress('0x2'),
        asset: mkAddress('0xa'),
        amount: '1000000',
        settlementTransactionHash: mkBytes32('0xb'),
        settlementTimestamp: '2000',
        settlementBlockNumber: '200',
        settlementTxOrigin: mkAddress('0x1'),
        settlementTxNonce: '10',
        settlementGasPrice: '1000',
        settlementGasLimit: '21000',
      };
      executeEnvioQuery.resolves({ SettlementIntent: [entity] });

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1338', { latestNonce: 50, maxBlockNumber: 500 }],
      ]);

      const result = await reader.getSettlementIntentsByNonce(queryParams);
      expect(result.length).to.be.eq(1);
      expect(result[0].intentId).to.be.eq(mkBytes32('0x1'));
    });

    it('should handle errors gracefully', async () => {
      executeEnvioQuery.rejects(new Error('error'));
      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1338', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);
      const result = await reader.getSettlementIntentsByNonce(queryParams);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getDestinationIntentsByNonce', () => {
    it('should return destination intents', async () => {
      const intent1 = createEnvioIntentEntity({
        intentId: mkBytes32('0x1'),
        status: 'FILLED',
        destinations: [1338],
        fills: [createEnvioFillEntity({ fillAmount: '950000000' })],
      });
      const intent2 = createEnvioIntentEntity({
        intentId: mkBytes32('0x2'),
        status: 'FILLED',
        destinations: [1338],
        fills: [createEnvioFillEntity({ fillAmount: '900000000', transactionHash: mkBytes32('0x3') })],
      });

      executeEnvioQuery.resolves({ Intent: [intent1, intent2] });

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1338', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getDestinationIntentsByNonce(queryParams);
      expect(result.length).to.be.eq(2);
      expect(result[0].id).to.be.eq(mkBytes32('0x1'));
      expect(result[1].id).to.be.eq(mkBytes32('0x2'));
    });

    it('should handle errors gracefully', async () => {
      executeEnvioQuery.rejects(new Error('error'));
      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1338', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getDestinationIntentsByNonce(queryParams);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getHubIntentsByNonce', () => {
    it('should return three arrays from parallel queries', async () => {
      const addedIntent = createEnvioHubIntentEntity({ addEventBlockNumber: '110' });
      const filledIntent = createEnvioHubIntentEntity({
        id: mkBytes32('0x2'),
        fillEventTimestamp: '2000',
        fillEventBlockNumber: '210',
        fillEventTxNonce: '8',
      });
      const settlement = createEnvioHubSettlementEntity({ id: mkBytes32('0x3') });

      executeEnvioQuery
        .onFirstCall()
        .resolves({ HubIntent: [addedIntent] })
        .onSecondCall()
        .resolves({ HubIntent: [filledIntent] })
        .onThirdCall()
        .resolves({ HubSettlement: [settlement] });

      const [added, filled, enqueued] = await reader.getHubIntentsByNonce('25327', 50, 50, 50, 500);
      expect(added.length).to.be.eq(1);
      expect(filled.length).to.be.eq(1);
      expect(enqueued.length).to.be.eq(1);
    });

    it('should return empty arrays when no results', async () => {
      executeEnvioQuery.resolves({ HubIntent: [], HubSettlement: [] });

      const [added, filled, enqueued] = await reader.getHubIntentsByNonce('25327', 0, 0, 0, 1000);
      expect(added).to.be.deep.eq([]);
      expect(filled).to.be.deep.eq([]);
      expect(enqueued).to.be.deep.eq([]);
    });
  });

  describe('#getHubInvoicesByNonce', () => {
    it('should return invoices and intents', async () => {
      const invoice = createEnvioInvoiceEntity();
      executeEnvioQuery.resolves({ Invoice: [invoice] });

      const [invoices, intents] = await reader.getHubInvoicesByNonce('25327', 50, 500);
      expect(invoices.length).to.be.eq(1);
      expect(invoices[0].intentId).to.be.eq(mkBytes32('0x1'));
      expect(intents.length).to.be.eq(1);
      expect(intents[0].id).to.be.eq(mkBytes32('0x1'));
    });

    it('should return empty arrays when no results', async () => {
      executeEnvioQuery.resolves({ Invoice: [] });
      const [invoices, intents] = await reader.getHubInvoicesByNonce('25327', 0, 1000);
      expect(invoices).to.be.deep.eq([]);
      expect(intents).to.be.deep.eq([]);
    });
  });

  describe('#getOrdersByNonce', () => {
    it('should return orders from Envio', async () => {
      const order = {
        id: mkBytes32('0xord1'),
        initiator: mkAddress('0x1'),
        intentIds: [mkBytes32('0x1')],
        tokenFee: '100',
        nativeFee: '50',
        transactionHash: mkBytes32('0xa'),
        timestamp: '1000',
        blockNumber: '100',
        txOrigin: mkAddress('0x1'),
        txNonce: '5',
        gasPrice: '1000',
        gasLimit: '21000',
        chainId: 1337,
      };
      executeEnvioQuery.resolves({ Order: [order] });

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 500 }],
      ]);

      const result = await reader.getOrdersByNonce(queryParams);
      expect(result.length).to.be.eq(1);
      expect(result[0].id).to.be.eq(mkBytes32('0xord1'));
      expect(result[0].domain).to.be.eq('1337');
    });

    it('should handle errors gracefully', async () => {
      executeEnvioQuery.rejects(new Error('error'));
      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 500 }],
      ]);
      const result = await reader.getOrdersByNonce(queryParams);
      expect(result).to.be.deep.eq([]);
    });
  });

  // ============================================================================
  // Envio-specific helpers
  // ============================================================================

  describe('#getEnvioOriginIntentById', () => {
    it('should return origin intent', async () => {
      const intent = createEnvioIntentEntity({ intentId: mkBytes32('0x1'), origin: 1337 });
      executeEnvioQuery.resolves({ Intent: [intent] });

      const result = await (reader as any).getEnvioOriginIntentById(mkBytes32('0x1'), '1337');
      expect(result).to.not.be.undefined;
      expect(result?.id).to.be.eq(mkBytes32('0x1'));
    });
  });

  describe('#getEnvioDestinationIntentById', () => {
    it('should return destination intent', async () => {
      const intent = createEnvioIntentEntity({
        intentId: mkBytes32('0x1'),
        status: 'FILLED',
        destinations: [1338],
        fills: [createEnvioFillEntity()],
      });
      executeEnvioQuery.resolves({ Intent: [intent] });

      const result = await (reader as any).getEnvioDestinationIntentById(mkBytes32('0x1'), '1338');
      expect(result).to.not.be.undefined;
      expect(result?.id).to.be.eq(mkBytes32('0x1'));
      expect(result?.destination).to.be.eq('1338');
    });
  });
});
