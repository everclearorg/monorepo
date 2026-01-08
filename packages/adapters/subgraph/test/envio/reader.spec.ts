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
    // Restore any existing stubs to ensure a clean state
    restore();
    
    // Reset singleton instance to ensure clean state for each test
    (EnvioReader as any).instance = undefined;
    
    executeEnvioQuery = stub();
    stub(Helpers, 'getHelpers').returns({
      execute: stub(),
      parser,
      executeEnvioQuery,
    });

    reader = EnvioReader.create(config);
  });

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

  describe('#create', () => {
    it('should create a new instance', () => {
      expect(reader).to.be.instanceOf(EnvioReader);
    });
  });

  describe('#queryEnvio', () => {
    it('should throw if envio config is missing', async () => {
      // Reset singleton instance to test with new config
      (EnvioReader as any).instance = undefined;
      const readerWithoutConfig = EnvioReader.create({ subgraphs: {} });
      await expect(readerWithoutConfig.queryEnvio('query')).to.be.rejectedWith(
        'Envio configuration is missing',
      );
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

  describe('#getLatestBlockNumber', () => {
    it('should return block numbers for domains', async () => {
      const intent1 = createEnvioIntentEntity({ blockNumber: '100', origin: 1337 });
      const intent2 = createEnvioIntentEntity({ blockNumber: '200', origin: 1338 });

      executeEnvioQuery
        .onFirstCall()
        .resolves({ Intent: [intent1] })
        .onSecondCall()
        .resolves({ Intent: [intent2] });

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

  describe('#getHubIntentById', () => {
    it('should return undefined (Envio does not track hub intents)', async () => {
      const result = await reader.getHubIntentById('1337', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getHubInvoiceById', () => {
    it('should return undefined (Envio does not track hub invoices)', async () => {
      const result = await reader.getHubInvoiceById('1337', mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getDepositorEvents', () => {
    it('should return empty array (Envio does not track depositor events)', async () => {
      const result = await reader.getDepositorEvents('1337', 1);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getTokens', () => {
    it('should return empty arrays (Envio does not track tokens)', async () => {
      const result = await reader.getTokens('1337');
      expect(result).to.be.deep.eq([[], []]);
    });
  });

  describe('#getSpokeQueues', () => {
    it('should return empty array (Envio does not track queues)', async () => {
      const result = await reader.getSpokeQueues('1337');
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getSettlementQueues', () => {
    it('should return empty array (Envio does not track settlement queues)', async () => {
      const result = await reader.getSettlementQueues('1337');
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getDepositQueues', () => {
    it('should return empty array (Envio does not track deposit queues)', async () => {
      const result = await reader.getDepositQueues('1337', 100);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getDepositsEnqueuedByNonce', () => {
    it('should return empty array (Envio does not track deposits)', async () => {
      const result = await reader.getDepositsEnqueuedByNonce('1337', 1, 1000);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getDepositsProcessedByNonce', () => {
    it('should return empty array (Envio does not track deposits)', async () => {
      const result = await reader.getDepositsProcessedByNonce('1337', 1, 1000);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getSpokeMessages', () => {
    it('should return empty array (Envio does not track messages)', async () => {
      const result = await reader.getSpokeMessages('1337', 1);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getHubMessages', () => {
    it('should return empty array (Envio does not track hub messages)', async () => {
      const result = await reader.getHubMessages('1337', 1);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getOriginIntentsByNonce', () => {
    it('should return origin intents', async () => {
      const intent1 = createEnvioIntentEntity({
        intentId: mkBytes32('0x1'),
        origin: 1337,
        blockNumber: '100',
      });
      const intent2 = createEnvioIntentEntity({
        intentId: mkBytes32('0x2'),
        origin: 1337,
        blockNumber: '101',
      });

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
      const intent1 = createEnvioIntentEntity({
        intentId: mkBytes32('0x1'),
        origin: 1337,
      });
      const intent2 = createEnvioIntentEntity({
        intentId: mkBytes32('0x2'),
        origin: 1338,
      });

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
    it('should return empty array (Envio does not track settlement intents)', async () => {
      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
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
    it('should return empty arrays (Envio does not track hub intents)', async () => {
      const result = await reader.getHubIntentsByNonce('1337', 0, 0, 0, 1000);
      expect(result).to.be.deep.eq([[], [], []]);
    });
  });

  describe('#getHubInvoicesByNonce', () => {
    it('should return empty arrays (Envio does not track hub invoices)', async () => {
      const result = await reader.getHubInvoicesByNonce('1337', 0, 1000);
      expect(result).to.be.deep.eq([[], []]);
    });
  });

  describe('#getOrdersByNonce', () => {
    it('should return empty array (Envio does not track orders)', async () => {
      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getOrdersByNonce(queryParams);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getEnvioLatestBlockNumber', () => {
    it('should return latest block number for domain', async () => {
      const intent = createEnvioIntentEntity({ blockNumber: '100', origin: 1337 });
      executeEnvioQuery.resolves({ Intent: [intent] });

      const result = await (reader as any).getEnvioLatestBlockNumber('1337');
      expect(result).to.be.eq(100);
    });

    it('should return undefined if no intents found', async () => {
      executeEnvioQuery.resolves({ Intent: [] });

      const result = await (reader as any).getEnvioLatestBlockNumber('1337');
      expect(result).to.be.undefined;
    });
  });

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

