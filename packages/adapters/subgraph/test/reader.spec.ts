import { stub, restore, createStubInstance, SinonStubbedInstance } from 'sinon';
import { expect, mkBytes32, OriginIntent, DestinationIntent } from '@chimera-monorepo/utils';
import { SubgraphReader, SubgraphQueryMetaParams } from '../src';
import { GraphReader } from '../src/graph';
import { EnvioReader } from '../src/envio';

describe('SubgraphReader (Composite)', () => {
  const domain = '1337';
  const domains = [domain];
  const subgraphs = Object.fromEntries(
    domains.map((domain) => [domain, { endpoints: [`http://localhost:${domain}/graphql`], timeout: 1 }]),
  );
  const envioConfig = {
    url: 'https://envio.example.com/graphql',
    apiKey: 'test-key',
    timeout: 10,
  };
  const config = {
    subgraphs,
    envio: envioConfig,
  };

  let graphReader: SinonStubbedInstance<GraphReader>;
  let envioReader: SinonStubbedInstance<EnvioReader>;
  let reader: SubgraphReader;

  beforeEach(() => {
    // Restore any existing stubs to ensure a clean state
    restore();

    // Create stub instances of both readers
    graphReader = createStubInstance(GraphReader);
    envioReader = createStubInstance(EnvioReader);

    // Stub the create methods to return our stub instances
    stub(GraphReader, 'create').returns(graphReader as any);
    stub(EnvioReader, 'create').returns(envioReader as any);

    reader = SubgraphReader.create(config);
  });

  afterEach(() => {
    // Reset singleton instance
    (SubgraphReader as any).instance = undefined;
  });

  describe('#create', () => {
    it('should create a new instance', () => {
      expect(reader).to.be.instanceOf(SubgraphReader);
    });

    it('should return the same instance on subsequent calls', () => {
      const reader2 = SubgraphReader.create(config);
      expect(reader).to.equal(reader2);
    });

    it('should create both GraphReader and EnvioReader instances', () => {
      expect(GraphReader.create).to.have.been.calledOnce;
      expect(EnvioReader.create).to.have.been.calledOnce;
    });
  });

  describe('#getLatestBlockNumber', () => {
    it('should merge results from both readers and prefer higher block numbers', async () => {
      const graphMap = new Map<string, number>([['1337', 100]]);
      const envioMap = new Map<string, number>([['1337', 150]]);

      graphReader.getLatestBlockNumber.resolves(graphMap);
      envioReader.getLatestBlockNumber.resolves(envioMap);

      const result = await reader.getLatestBlockNumber(domains);
      expect(result.get('1337')).to.be.eq(150); // Should prefer higher block number
      expect(graphReader.getLatestBlockNumber).to.have.been.calledOnce;
      expect(envioReader.getLatestBlockNumber).to.have.been.calledOnce;
    });

    it('should handle errors gracefully and use available results', async () => {
      const graphMap = new Map<string, number>([['1337', 100]]);
      graphReader.getLatestBlockNumber.resolves(graphMap);
      envioReader.getLatestBlockNumber.rejects(new Error('error'));

      const result = await reader.getLatestBlockNumber(domains);
      expect(result.get('1337')).to.be.eq(100);
    });

    it('should return empty map if both readers fail', async () => {
      graphReader.getLatestBlockNumber.rejects(new Error('error'));
      envioReader.getLatestBlockNumber.rejects(new Error('error'));

      const result = await reader.getLatestBlockNumber(domains);
      expect(result.size).to.be.eq(0);
    });
  });

  describe('#getOriginIntentById', () => {
    it('should prefer GraphReader result over EnvioReader', async () => {
      const graphIntent: OriginIntent = {
        id: mkBytes32('0x1'),
        origin: '1337',
      } as OriginIntent;
      const envioIntent: OriginIntent = {
        id: mkBytes32('0x1'),
        origin: '1337',
      } as OriginIntent;

      graphReader.getOriginIntentById.resolves(graphIntent);
      envioReader.getOriginIntentById.resolves(envioIntent);

      const result = await reader.getOriginIntentById(domain, mkBytes32('0x1'));
      expect(result).to.equal(graphIntent); // Should prefer GraphReader
      expect(graphReader.getOriginIntentById).to.have.been.calledOnce;
      expect(envioReader.getOriginIntentById).to.have.been.calledOnce;
    });

    it('should fall back to EnvioReader if GraphReader returns undefined', async () => {
      const envioIntent: OriginIntent = {
        id: mkBytes32('0x1'),
        origin: '1337',
      } as OriginIntent;

      graphReader.getOriginIntentById.resolves(undefined);
      envioReader.getOriginIntentById.resolves(envioIntent);

      const result = await reader.getOriginIntentById(domain, mkBytes32('0x1'));
      expect(result).to.equal(envioIntent);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getOriginIntentById.rejects(new Error('error'));
      envioReader.getOriginIntentById.resolves(undefined);

      const result = await reader.getOriginIntentById(domain, mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getDestinationIntentById', () => {
    it('should prefer GraphReader result over EnvioReader', async () => {
      const graphIntent: DestinationIntent = {
        id: mkBytes32('0x1'),
        destination: '1338',
      } as DestinationIntent;
      const envioIntent: DestinationIntent = {
        id: mkBytes32('0x1'),
        destination: '1338',
      } as DestinationIntent;

      graphReader.getDestinationIntentById.resolves(graphIntent);
      envioReader.getDestinationIntentById.resolves(envioIntent);

      const result = await reader.getDestinationIntentById(domain, mkBytes32('0x1'));
      expect(result).to.equal(graphIntent);
    });

    it('should fall back to EnvioReader if GraphReader returns undefined', async () => {
      const envioIntent: DestinationIntent = {
        id: mkBytes32('0x1'),
        destination: '1338',
      } as DestinationIntent;

      graphReader.getDestinationIntentById.resolves(undefined);
      envioReader.getDestinationIntentById.resolves(envioIntent);

      const result = await reader.getDestinationIntentById(domain, mkBytes32('0x1'));
      expect(result).to.equal(envioIntent);
    });
  });

  describe('#getOriginIntentsByNonce', () => {
    it('should merge results from both readers and deduplicate by intent ID', async () => {
      const graphIntent1: OriginIntent = {
        id: mkBytes32('0x1'),
        origin: '1337',
      } as OriginIntent;
      const graphIntent2: OriginIntent = {
        id: mkBytes32('0x2'),
        origin: '1337',
      } as OriginIntent;
      const envioIntent2: OriginIntent = {
        id: mkBytes32('0x2'), // Duplicate ID
        origin: '1337',
      } as OriginIntent;
      const envioIntent3: OriginIntent = {
        id: mkBytes32('0x3'),
        origin: '1337',
      } as OriginIntent;

      graphReader.getOriginIntentsByNonce.resolves([graphIntent1, graphIntent2]);
      envioReader.getOriginIntentsByNonce.resolves([envioIntent2, envioIntent3]);

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getOriginIntentsByNonce(queryParams);
      expect(result.length).to.be.eq(3); // Should have 3 unique intents
      expect(result.find((i) => i.id === mkBytes32('0x1'))).to.not.be.undefined;
      expect(result.find((i) => i.id === mkBytes32('0x2'))).to.not.be.undefined;
      expect(result.find((i) => i.id === mkBytes32('0x3'))).to.not.be.undefined;
      // Should prefer GraphReader result for duplicate ID
      expect(result.find((i) => i.id === mkBytes32('0x2'))).to.equal(graphIntent2);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getOriginIntentsByNonce.rejects(new Error('error'));
      envioReader.getOriginIntentsByNonce.resolves([]);

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getOriginIntentsByNonce(queryParams);
      expect(result).to.be.deep.eq([]);
    });
  });

  describe('#getDestinationIntentsByNonce', () => {
    it('should merge results from both readers and deduplicate by intent ID', async () => {
      const graphIntent1: DestinationIntent = {
        id: mkBytes32('0x1'),
        destination: '1338',
      } as DestinationIntent;
      const envioIntent2: DestinationIntent = {
        id: mkBytes32('0x2'),
        destination: '1338',
      } as DestinationIntent;

      graphReader.getDestinationIntentsByNonce.resolves([graphIntent1]);
      envioReader.getDestinationIntentsByNonce.resolves([envioIntent2]);

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1338', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getDestinationIntentsByNonce(queryParams);
      expect(result.length).to.be.eq(2);
      expect(result.find((i) => i.id === mkBytes32('0x1'))).to.not.be.undefined;
      expect(result.find((i) => i.id === mkBytes32('0x2'))).to.not.be.undefined;
    });
  });

  describe('#getTokens', () => {
    it('should merge tokens and assets from both readers and deduplicate by ID', async () => {
      const graphTokens = [{ id: 'token1' }, { id: 'token2' }] as any[];
      const graphAssets = [{ id: 'asset1' }, { id: 'asset2' }] as any[];
      const envioTokens = [{ id: 'token2' }, { id: 'token3' }] as any[]; // token2 is duplicate
      const envioAssets = [{ id: 'asset2' }, { id: 'asset3' }] as any[]; // asset2 is duplicate

      graphReader.getTokens.resolves([graphTokens, graphAssets]);
      envioReader.getTokens.resolves([envioTokens, envioAssets]);

      const result = await reader.getTokens('1337');
      expect(result[0].length).to.be.eq(3); // token1, token2, token3 (deduplicated)
      expect(result[1].length).to.be.eq(3); // asset1, asset2, asset3 (deduplicated)
      // Should prefer GraphReader results for duplicates
      expect(result[0].find((t: any) => t.id === 'token2')).to.equal(graphTokens[1]);
    });
  });

  describe('#getSpokeQueues', () => {
    it('should merge queues from both readers and deduplicate by ID', async () => {
      const graphQueues = [{ id: 'queue1' }, { id: 'queue2' }] as any[];
      const envioQueues = [{ id: 'queue2' }, { id: 'queue3' }] as any[]; // queue2 is duplicate

      graphReader.getSpokeQueues.resolves(graphQueues);
      envioReader.getSpokeQueues.resolves(envioQueues);

      const result = await reader.getSpokeQueues(domain);
      expect(result.length).to.be.eq(3); // queue1, queue2, queue3 (deduplicated)
      // Should prefer GraphReader results for duplicates
      expect(result.find((q: any) => q.id === 'queue2')).to.equal(graphQueues[1]);
    });
  });

  describe('#getDepositorEvents', () => {
    it('should merge depositor events from both readers', async () => {
      const graphEvents = [{ id: 'event1' }, { id: 'event2' }] as any[];
      const envioEvents = [{ id: 'event3' }] as any[];

      graphReader.getDepositorEvents.resolves(graphEvents);
      envioReader.getDepositorEvents.resolves(envioEvents);

      const result = await reader.getDepositorEvents(domain, 1);
      expect(result.length).to.be.eq(3);
    });
  });

  describe('#getHubIntentsByNonce', () => {
    it('should merge hub intents from both readers for each array', async () => {
      const graphAdded = [{ id: 'intent1' }, { id: 'intent2' }] as any[];
      const graphFilled = [{ id: 'intent3' }] as any[];
      const graphEnqueued = [{ id: 'intent4' }] as any[];
      const envioAdded = [{ id: 'intent2' }, { id: 'intent5' }] as any[]; // intent2 is duplicate
      const envioFilled = [{ id: 'intent6' }] as any[];
      const envioEnqueued = [{ id: 'intent7' }] as any[];

      graphReader.getHubIntentsByNonce.resolves([graphAdded, graphFilled, graphEnqueued]);
      envioReader.getHubIntentsByNonce.resolves([envioAdded, envioFilled, envioEnqueued]);

      const result = await reader.getHubIntentsByNonce('1337', 0, 0, 0, 1000);
      expect(result[0].length).to.be.eq(3); // intent1, intent2, intent5 (deduplicated)
      expect(result[1].length).to.be.eq(2); // intent3, intent6
      expect(result[2].length).to.be.eq(2); // intent4, intent7
    });
  });

  describe('#getHubInvoicesByNonce', () => {
    it('should merge hub invoices and intents from both readers', async () => {
      const graphInvoices = [{ id: 'invoice1' }, { id: 'invoice2' }] as any[];
      const graphIntents = [{ id: 'intent1' }] as any[];
      const envioInvoices = [{ id: 'invoice2' }, { id: 'invoice3' }] as any[]; // invoice2 is duplicate
      const envioIntents = [{ id: 'intent2' }] as any[];

      graphReader.getHubInvoicesByNonce.resolves([graphInvoices, graphIntents]);
      envioReader.getHubInvoicesByNonce.resolves([envioInvoices, envioIntents]);

      const result = await reader.getHubInvoicesByNonce('1337', 0, 1000);
      expect(result[0].length).to.be.eq(3); // invoice1, invoice2, invoice3 (deduplicated)
      expect(result[1].length).to.be.eq(2); // intent1, intent2
    });
  });

  describe('#getOrdersByNonce', () => {
    it('should merge orders from both readers and deduplicate by ID', async () => {
      const graphOrders = [
        { id: 'order1', domain: '1337' },
        { id: 'order2', domain: '1337' },
      ] as any[];
      const envioOrders = [
        { id: 'order2', domain: '1337' },
        { id: 'order3', domain: '1337' },
      ] as any[]; // order2 is duplicate

      graphReader.getOrdersByNonce.resolves(graphOrders);
      envioReader.getOrdersByNonce.resolves(envioOrders);

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getOrdersByNonce(queryParams);
      expect(result.length).to.be.eq(3); // order1, order2, order3 (deduplicated)
      // Should prefer GraphReader results for duplicates
      expect(result.find((o: any) => o.id === 'order2')).to.equal(graphOrders[1]);
    });
  });

  describe('#query', () => {
    it('should delegate to GraphReader for direct queries', async () => {
      const response = { data: 'test', domain: '1337' };
      graphReader.query.resolves(response);

      const result = await reader.query('1337', ['query']);
      expect(result).to.equal(response);
      expect(graphReader.query).to.have.been.calledOnceWith('1337', ['query']);
      expect(envioReader.query).to.not.have.been.called;
    });
  });

  describe('Error handling', () => {
    it('should handle partial failures gracefully', async () => {
      // GraphReader succeeds, EnvioReader fails
      graphReader.getOriginIntentsByNonce.resolves([
        { id: mkBytes32('0x1'), origin: '1337' } as OriginIntent,
      ]);
      envioReader.getOriginIntentsByNonce.rejects(new Error('error'));

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getOriginIntentsByNonce(queryParams);
      expect(result.length).to.be.eq(1);
      expect(result[0].id).to.be.eq(mkBytes32('0x1'));
    });

    it('should handle both readers failing gracefully', async () => {
      graphReader.getOriginIntentsByNonce.rejects(new Error('error'));
      envioReader.getOriginIntentsByNonce.rejects(new Error('error'));

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getOriginIntentsByNonce(queryParams);
      expect(result).to.be.deep.eq([]);
    });
  });
});
