import { stub, restore, createStubInstance, SinonStubbedInstance } from 'sinon';
import {
  expect,
  mkBytes32,
  OriginIntent,
  DestinationIntent,
  ProtocolUpdateLog,
  HubTokenUpdateLog,
  HubAssetUpdateLog,
  HubIntent,
  HubInvoice,
  SettlementIntent,
  HubDeposit,
  TIntentStatus,
  HubMeta,
  SpokeMeta,
  Message,
  HubMessage,
  Queue,
  DepositQueue,
  DepositorEvent,
  Order,
} from '@chimera-monorepo/utils';
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
    restore();
  });

  // ===========================================================================
  // #create
  // ===========================================================================

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

    it('should not create GraphReader when goldskyEnabled is false', () => {
      (SubgraphReader as any).instance = undefined;
      restore();

      const graphCreateStub = stub(GraphReader, 'create').returns(graphReader as any);
      const envioCreateStub = stub(EnvioReader, 'create').returns(envioReader as any);

      const newReader = SubgraphReader.create({ ...config, goldskyEnabled: false });
      expect(newReader).to.be.instanceOf(SubgraphReader);
      expect(graphCreateStub).to.not.have.been.called;
      expect(envioCreateStub).to.have.been.calledOnce;

      (SubgraphReader as any).instance = undefined;
    });

    it('should not create EnvioReader when envioEnabled is false', () => {
      (SubgraphReader as any).instance = undefined;
      restore();

      const graphCreateStub = stub(GraphReader, 'create').returns(graphReader as any);
      const envioCreateStub = stub(EnvioReader, 'create').returns(envioReader as any);

      const newReader = SubgraphReader.create({ ...config, envioEnabled: false });
      expect(newReader).to.be.instanceOf(SubgraphReader);
      expect(graphCreateStub).to.have.been.calledOnce;
      expect(envioCreateStub).to.not.have.been.called;

      (SubgraphReader as any).instance = undefined;
    });

    it('should not create EnvioReader when envio url is missing', () => {
      (SubgraphReader as any).instance = undefined;
      restore();

      const graphCreateStub = stub(GraphReader, 'create').returns(graphReader as any);
      const envioCreateStub = stub(EnvioReader, 'create').returns(envioReader as any);

      const newReader = SubgraphReader.create({ subgraphs, envio: undefined });
      expect(newReader).to.be.instanceOf(SubgraphReader);
      expect(graphCreateStub).to.have.been.calledOnce;
      expect(envioCreateStub).to.not.have.been.called;

      (SubgraphReader as any).instance = undefined;
    });
  });

  // ===========================================================================
  // #query
  // ===========================================================================

  describe('#query', () => {
    it('should call all readers and return first non-undefined result', async () => {
      const response = { data: 'test', domain: '1337' };
      graphReader.query.resolves(response);
      envioReader.query.resolves(undefined);

      const result = await reader.query('1337', ['query']);
      expect(result).to.equal(response);
      expect(graphReader.query).to.have.been.calledOnceWith('1337', ['query']);
      expect(envioReader.query).to.have.been.calledOnceWith('1337', ['query']);
    });

    it('should return envio result when graph returns undefined', async () => {
      const response = { data: 'envio', domain: '1337' };
      graphReader.query.resolves(undefined);
      envioReader.query.resolves(response);

      const result = await reader.query('1337', ['query']);
      expect(result).to.equal(response);
    });

    it('should return undefined when no readers exist', async () => {
      (SubgraphReader as any).instance = undefined;
      restore();

      stub(GraphReader, 'create').returns(graphReader as any);
      stub(EnvioReader, 'create').returns(envioReader as any);

      const emptyReader = SubgraphReader.create({
        subgraphs,
        goldskyEnabled: false,
        envioEnabled: false,
      });

      const result = await emptyReader.query('1337', ['query']);
      expect(result).to.be.undefined;

      (SubgraphReader as any).instance = undefined;
    });

    it('should throw when all readers reject', async () => {
      const error = new Error('query failed');
      graphReader.query.rejects(error);
      envioReader.query.rejects(new Error('also failed'));

      try {
        await reader.query('1337', ['query']);
        expect.fail('should have thrown');
      } catch (e: any) {
        expect(e.message).to.equal('query failed');
      }
    });

    it('should return fulfilled result when one rejects and another fulfills', async () => {
      const response = { data: 'test', domain: '1337' };
      graphReader.query.rejects(new Error('failed'));
      envioReader.query.resolves(response);

      const result = await reader.query('1337', ['query']);
      expect(result).to.equal(response);
    });

    it('should return undefined when all readers return undefined', async () => {
      graphReader.query.resolves(undefined);
      envioReader.query.resolves(undefined);

      const result = await reader.query('1337', ['query']);
      expect(result).to.be.undefined;
    });
  });

  // ===========================================================================
  // #getLatestBlockNumber
  // ===========================================================================

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

    it('should prefer graph block number when it is higher', async () => {
      const graphMap = new Map<string, number>([['1337', 200]]);
      const envioMap = new Map<string, number>([['1337', 100]]);

      graphReader.getLatestBlockNumber.resolves(graphMap);
      envioReader.getLatestBlockNumber.resolves(envioMap);

      const result = await reader.getLatestBlockNumber(domains);
      expect(result.get('1337')).to.be.eq(200);
    });

    it('should handle multiple domains', async () => {
      const multiDomains = ['1337', '1338'];
      const graphMap = new Map<string, number>([
        ['1337', 100],
        ['1338', 200],
      ]);
      const envioMap = new Map<string, number>([
        ['1337', 150],
        ['1338', 180],
      ]);

      graphReader.getLatestBlockNumber.resolves(graphMap);
      envioReader.getLatestBlockNumber.resolves(envioMap);

      const result = await reader.getLatestBlockNumber(multiDomains);
      expect(result.get('1337')).to.be.eq(150);
      expect(result.get('1338')).to.be.eq(200);
    });

    it('should not include domain in result if max is 0', async () => {
      graphReader.getLatestBlockNumber.resolves(new Map());
      envioReader.getLatestBlockNumber.resolves(new Map());

      const result = await reader.getLatestBlockNumber(domains);
      expect(result.has('1337')).to.be.false;
    });
  });

  // ===========================================================================
  // Single entity by ID (firstResult-based methods)
  // ===========================================================================

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

    it('should handle errors gracefully', async () => {
      graphReader.getDestinationIntentById.rejects(new Error('error'));
      envioReader.getDestinationIntentById.resolves(undefined);

      const result = await reader.getDestinationIntentById(domain, mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getHubIntentById', () => {
    it('should prefer GraphReader result over EnvioReader', async () => {
      const graphIntent = { id: mkBytes32('0x1') } as HubIntent;
      const envioIntent = { id: mkBytes32('0x1') } as HubIntent;

      graphReader.getHubIntentById.resolves(graphIntent);
      envioReader.getHubIntentById.resolves(envioIntent);

      const result = await reader.getHubIntentById(domain, mkBytes32('0x1'));
      expect(result).to.equal(graphIntent);
    });

    it('should fall back to EnvioReader if GraphReader returns undefined', async () => {
      const envioIntent = { id: mkBytes32('0x1') } as HubIntent;

      graphReader.getHubIntentById.resolves(undefined);
      envioReader.getHubIntentById.resolves(envioIntent);

      const result = await reader.getHubIntentById(domain, mkBytes32('0x1'));
      expect(result).to.equal(envioIntent);
    });

    it('should return undefined when both return undefined', async () => {
      graphReader.getHubIntentById.resolves(undefined);
      envioReader.getHubIntentById.resolves(undefined);

      const result = await reader.getHubIntentById(domain, mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });

    it('should handle errors gracefully', async () => {
      graphReader.getHubIntentById.rejects(new Error('error'));
      envioReader.getHubIntentById.resolves(undefined);

      const result = await reader.getHubIntentById(domain, mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getHubInvoiceById', () => {
    it('should prefer GraphReader result over EnvioReader', async () => {
      const graphInvoice = { id: mkBytes32('0x1') } as HubInvoice;
      const envioInvoice = { id: mkBytes32('0x1') } as HubInvoice;

      graphReader.getHubInvoiceById.resolves(graphInvoice);
      envioReader.getHubInvoiceById.resolves(envioInvoice);

      const result = await reader.getHubInvoiceById(domain, mkBytes32('0x1'));
      expect(result).to.equal(graphInvoice);
    });

    it('should fall back to EnvioReader if GraphReader returns undefined', async () => {
      const envioInvoice = { id: mkBytes32('0x1') } as HubInvoice;

      graphReader.getHubInvoiceById.resolves(undefined);
      envioReader.getHubInvoiceById.resolves(envioInvoice);

      const result = await reader.getHubInvoiceById(domain, mkBytes32('0x1'));
      expect(result).to.equal(envioInvoice);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getHubInvoiceById.rejects(new Error('error'));
      envioReader.getHubInvoiceById.resolves(undefined);

      const result = await reader.getHubInvoiceById(domain, mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getSettlementIntentById', () => {
    it('should prefer GraphReader result over EnvioReader', async () => {
      const graphIntent = { intentId: mkBytes32('0x1') } as SettlementIntent;
      const envioIntent = { intentId: mkBytes32('0x1') } as SettlementIntent;

      graphReader.getSettlementIntentById.resolves(graphIntent);
      envioReader.getSettlementIntentById.resolves(envioIntent);

      const result = await reader.getSettlementIntentById(domain, mkBytes32('0x1'));
      expect(result).to.equal(graphIntent);
    });

    it('should fall back to EnvioReader if GraphReader returns undefined', async () => {
      const envioIntent = { intentId: mkBytes32('0x1') } as SettlementIntent;

      graphReader.getSettlementIntentById.resolves(undefined);
      envioReader.getSettlementIntentById.resolves(envioIntent);

      const result = await reader.getSettlementIntentById(domain, mkBytes32('0x1'));
      expect(result).to.equal(envioIntent);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getSettlementIntentById.rejects(new Error('error'));
      envioReader.getSettlementIntentById.resolves(undefined);

      const result = await reader.getSettlementIntentById(domain, mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getHubDepositEnqueuedById', () => {
    it('should prefer GraphReader result over EnvioReader', async () => {
      const graphDeposit = { id: mkBytes32('0x1'), status: 'DISPATCHED' as TIntentStatus } as HubDeposit & {
        status: TIntentStatus;
      };
      const envioDeposit = { id: mkBytes32('0x1'), status: 'DISPATCHED' as TIntentStatus } as HubDeposit & {
        status: TIntentStatus;
      };

      graphReader.getHubDepositEnqueuedById.resolves(graphDeposit);
      envioReader.getHubDepositEnqueuedById.resolves(envioDeposit);

      const result = await reader.getHubDepositEnqueuedById(domain, mkBytes32('0x1'));
      expect(result).to.equal(graphDeposit);
    });

    it('should fall back to EnvioReader if GraphReader returns undefined', async () => {
      const envioDeposit = { id: mkBytes32('0x1'), status: 'DISPATCHED' as TIntentStatus } as HubDeposit & {
        status: TIntentStatus;
      };

      graphReader.getHubDepositEnqueuedById.resolves(undefined);
      envioReader.getHubDepositEnqueuedById.resolves(envioDeposit);

      const result = await reader.getHubDepositEnqueuedById(domain, mkBytes32('0x1'));
      expect(result).to.equal(envioDeposit);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getHubDepositEnqueuedById.rejects(new Error('error'));
      envioReader.getHubDepositEnqueuedById.resolves(undefined);

      const result = await reader.getHubDepositEnqueuedById(domain, mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  describe('#getHubDepositProcessedById', () => {
    it('should prefer GraphReader result over EnvioReader', async () => {
      const graphDeposit = { id: mkBytes32('0x1'), status: 'SETTLED' as TIntentStatus } as HubDeposit & {
        status: TIntentStatus;
      };
      const envioDeposit = { id: mkBytes32('0x1'), status: 'SETTLED' as TIntentStatus } as HubDeposit & {
        status: TIntentStatus;
      };

      graphReader.getHubDepositProcessedById.resolves(graphDeposit);
      envioReader.getHubDepositProcessedById.resolves(envioDeposit);

      const result = await reader.getHubDepositProcessedById(domain, mkBytes32('0x1'));
      expect(result).to.equal(graphDeposit);
    });

    it('should fall back to EnvioReader if GraphReader returns undefined', async () => {
      const envioDeposit = { id: mkBytes32('0x1'), status: 'SETTLED' as TIntentStatus } as HubDeposit & {
        status: TIntentStatus;
      };

      graphReader.getHubDepositProcessedById.resolves(undefined);
      envioReader.getHubDepositProcessedById.resolves(envioDeposit);

      const result = await reader.getHubDepositProcessedById(domain, mkBytes32('0x1'));
      expect(result).to.equal(envioDeposit);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getHubDepositProcessedById.rejects(new Error('error'));
      envioReader.getHubDepositProcessedById.resolves(undefined);

      const result = await reader.getHubDepositProcessedById(domain, mkBytes32('0x1'));
      expect(result).to.be.undefined;
    });
  });

  // ===========================================================================
  // Meta (single entity - firstResult)
  // ===========================================================================

  describe('#getHubMeta', () => {
    it('should prefer GraphReader result over EnvioReader', async () => {
      const graphMeta = { id: 'hub-meta' } as HubMeta;
      const envioMeta = { id: 'hub-meta' } as HubMeta;

      graphReader.getHubMeta.resolves(graphMeta);
      envioReader.getHubMeta.resolves(envioMeta);

      const result = await reader.getHubMeta(domain);
      expect(result).to.equal(graphMeta);
    });

    it('should fall back to EnvioReader if GraphReader returns undefined', async () => {
      const envioMeta = { id: 'hub-meta' } as HubMeta;

      graphReader.getHubMeta.resolves(undefined);
      envioReader.getHubMeta.resolves(envioMeta);

      const result = await reader.getHubMeta(domain);
      expect(result).to.equal(envioMeta);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getHubMeta.rejects(new Error('error'));
      envioReader.getHubMeta.resolves(undefined);

      const result = await reader.getHubMeta(domain);
      expect(result).to.be.undefined;
    });
  });

  describe('#getSpokeMeta', () => {
    it('should prefer GraphReader result over EnvioReader', async () => {
      const graphMeta = { id: 'spoke-meta' } as SpokeMeta;
      const envioMeta = { id: 'spoke-meta' } as SpokeMeta;

      graphReader.getSpokeMeta.resolves(graphMeta);
      envioReader.getSpokeMeta.resolves(envioMeta);

      const result = await reader.getSpokeMeta(domain);
      expect(result).to.equal(graphMeta);
    });

    it('should fall back to EnvioReader if GraphReader returns undefined', async () => {
      const envioMeta = { id: 'spoke-meta' } as SpokeMeta;

      graphReader.getSpokeMeta.resolves(undefined);
      envioReader.getSpokeMeta.resolves(envioMeta);

      const result = await reader.getSpokeMeta(domain);
      expect(result).to.equal(envioMeta);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getSpokeMeta.rejects(new Error('error'));
      envioReader.getSpokeMeta.resolves(undefined);

      const result = await reader.getSpokeMeta(domain);
      expect(result).to.be.undefined;
    });
  });

  // ===========================================================================
  // Array results (mergeArrays-based methods)
  // ===========================================================================

  describe('#getDepositorEvents', () => {
    it('should merge depositor events from both readers', async () => {
      const graphEvents = [{ id: 'event1' }, { id: 'event2' }] as any[];
      const envioEvents = [{ id: 'event3' }] as any[];

      graphReader.getDepositorEvents.resolves(graphEvents);
      envioReader.getDepositorEvents.resolves(envioEvents);

      const result = await reader.getDepositorEvents(domain, 1);
      expect(result.length).to.be.eq(3);
    });

    it('should deduplicate by id', async () => {
      const graphEvents = [{ id: 'event1' }, { id: 'event2' }] as any[];
      const envioEvents = [{ id: 'event2' }, { id: 'event3' }] as any[];

      graphReader.getDepositorEvents.resolves(graphEvents);
      envioReader.getDepositorEvents.resolves(envioEvents);

      const result = await reader.getDepositorEvents(domain, 1);
      expect(result.length).to.be.eq(3);
      expect(result.find((e: any) => e.id === 'event2')).to.equal(graphEvents[1]);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getDepositorEvents.rejects(new Error('error'));
      envioReader.getDepositorEvents.resolves([{ id: 'event1' }] as any[]);

      const result = await reader.getDepositorEvents(domain, 1);
      expect(result.length).to.be.eq(1);
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

    it('should handle errors gracefully and use available results', async () => {
      const graphTokens = [{ id: 'token1' }] as any[];
      const graphAssets = [{ id: 'asset1' }] as any[];

      graphReader.getTokens.resolves([graphTokens, graphAssets]);
      envioReader.getTokens.rejects(new Error('error'));

      const result = await reader.getTokens('1337');
      expect(result[0].length).to.be.eq(1);
      expect(result[1].length).to.be.eq(1);
    });

    it('should return empty arrays when both readers fail', async () => {
      graphReader.getTokens.rejects(new Error('error'));
      envioReader.getTokens.rejects(new Error('error'));

      const result = await reader.getTokens('1337');
      expect(result[0].length).to.be.eq(0);
      expect(result[1].length).to.be.eq(0);
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

  describe('#getSettlementQueues', () => {
    it('should merge queues from both readers and deduplicate by ID', async () => {
      const graphQueues = [{ id: 'queue1' }, { id: 'queue2' }] as any[];
      const envioQueues = [{ id: 'queue2' }, { id: 'queue3' }] as any[];

      graphReader.getSettlementQueues.resolves(graphQueues);
      envioReader.getSettlementQueues.resolves(envioQueues);

      const result = await reader.getSettlementQueues(domain);
      expect(result.length).to.be.eq(3);
      expect(result.find((q: any) => q.id === 'queue2')).to.equal(graphQueues[1]);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getSettlementQueues.resolves([{ id: 'queue1' }] as any[]);
      envioReader.getSettlementQueues.rejects(new Error('error'));

      const result = await reader.getSettlementQueues(domain);
      expect(result.length).to.be.eq(1);
    });
  });

  describe('#getDepositQueues', () => {
    it('should merge deposit queues from both readers and deduplicate by ID', async () => {
      const graphQueues = [{ id: 'dq1' }, { id: 'dq2' }] as any[];
      const envioQueues = [{ id: 'dq2' }, { id: 'dq3' }] as any[];

      graphReader.getDepositQueues.resolves(graphQueues);
      envioReader.getDepositQueues.resolves(envioQueues);

      const result = await reader.getDepositQueues(domain, 0);
      expect(result.length).to.be.eq(3);
      expect(result.find((q: any) => q.id === 'dq2')).to.equal(graphQueues[1]);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getDepositQueues.rejects(new Error('error'));
      envioReader.getDepositQueues.resolves([{ id: 'dq1' }] as any[]);

      const result = await reader.getDepositQueues(domain, 0);
      expect(result.length).to.be.eq(1);
    });
  });

  describe('#getDepositsEnqueuedByNonce', () => {
    it('should merge deposits from both readers and deduplicate by ID', async () => {
      const graphDeposits = [
        { id: 'dep1', status: 'DISPATCHED' },
        { id: 'dep2', status: 'DISPATCHED' },
      ] as any[];
      const envioDeposits = [
        { id: 'dep2', status: 'DISPATCHED' },
        { id: 'dep3', status: 'DISPATCHED' },
      ] as any[];

      graphReader.getDepositsEnqueuedByNonce.resolves(graphDeposits);
      envioReader.getDepositsEnqueuedByNonce.resolves(envioDeposits);

      const result = await reader.getDepositsEnqueuedByNonce(domain, 0, 1000);
      expect(result.length).to.be.eq(3);
      expect(result.find((d: any) => d.id === 'dep2')).to.equal(graphDeposits[1]);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getDepositsEnqueuedByNonce.rejects(new Error('error'));
      envioReader.getDepositsEnqueuedByNonce.resolves([{ id: 'dep1', status: 'DISPATCHED' }] as any[]);

      const result = await reader.getDepositsEnqueuedByNonce(domain, 0, 1000);
      expect(result.length).to.be.eq(1);
    });
  });

  describe('#getDepositsProcessedByNonce', () => {
    it('should merge deposits from both readers and deduplicate by ID', async () => {
      const graphDeposits = [{ id: 'dep1', status: 'SETTLED' }] as any[];
      const envioDeposits = [
        { id: 'dep1', status: 'SETTLED' },
        { id: 'dep2', status: 'SETTLED' },
      ] as any[];

      graphReader.getDepositsProcessedByNonce.resolves(graphDeposits);
      envioReader.getDepositsProcessedByNonce.resolves(envioDeposits);

      const result = await reader.getDepositsProcessedByNonce(domain, 0, 1000);
      expect(result.length).to.be.eq(2);
      expect(result.find((d: any) => d.id === 'dep1')).to.equal(graphDeposits[0]);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getDepositsProcessedByNonce.rejects(new Error('error'));
      envioReader.getDepositsProcessedByNonce.resolves([{ id: 'dep1', status: 'SETTLED' }] as any[]);

      const result = await reader.getDepositsProcessedByNonce(domain, 0, 1000);
      expect(result.length).to.be.eq(1);
    });
  });

  describe('#getSpokeMessages', () => {
    it('should merge messages from both readers and deduplicate by ID', async () => {
      const graphMessages = [{ id: 'msg1' }, { id: 'msg2' }] as any[];
      const envioMessages = [{ id: 'msg2' }, { id: 'msg3' }] as any[];

      graphReader.getSpokeMessages.resolves(graphMessages);
      envioReader.getSpokeMessages.resolves(envioMessages);

      const result = await reader.getSpokeMessages(domain, 0);
      expect(result.length).to.be.eq(3);
      expect(result.find((m: any) => m.id === 'msg2')).to.equal(graphMessages[1]);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getSpokeMessages.rejects(new Error('error'));
      envioReader.getSpokeMessages.resolves([{ id: 'msg1' }] as any[]);

      const result = await reader.getSpokeMessages(domain, 0);
      expect(result.length).to.be.eq(1);
    });
  });

  describe('#getHubMessages', () => {
    it('should merge hub messages from both readers and deduplicate by ID', async () => {
      const graphMessages = [{ id: 'hmsg1' }, { id: 'hmsg2' }] as any[];
      const envioMessages = [{ id: 'hmsg2' }, { id: 'hmsg3' }] as any[];

      graphReader.getHubMessages.resolves(graphMessages);
      envioReader.getHubMessages.resolves(envioMessages);

      const result = await reader.getHubMessages(domain, 0);
      expect(result.length).to.be.eq(3);
      expect(result.find((m: any) => m.id === 'hmsg2')).to.equal(graphMessages[1]);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getHubMessages.rejects(new Error('error'));
      envioReader.getHubMessages.resolves([{ id: 'hmsg1' }] as any[]);

      const result = await reader.getHubMessages(domain, 0);
      expect(result.length).to.be.eq(1);
    });
  });

  describe('#getHubMetaUpdates', () => {
    it('should merge results from both readers and deduplicate by id (prefer GraphReader)', async () => {
      const graphUpdate2: ProtocolUpdateLog = {
        id: 'hub-meta-2',
        domain,
        chainId: domain,
        event: 'PAUSED',
        key: 'paused',
        updated: 'True',
        transactionHash: mkBytes32('0xtx'),
        timestamp: 1,
        blockNumber: 10,
        txOrigin: mkBytes32('0xorigin'),
        txNonce: 1,
      };
      const graphUpdates: ProtocolUpdateLog[] = [
        {
          ...graphUpdate2,
          id: 'hub-meta-1',
        },
        graphUpdate2,
      ];
      const envioDupUpdate2: ProtocolUpdateLog = { ...graphUpdate2 }; // same id, different object
      const envioUpdates: ProtocolUpdateLog[] = [envioDupUpdate2, { ...graphUpdate2, id: 'hub-meta-3' }];

      graphReader.getHubMetaUpdates.resolves(graphUpdates);
      envioReader.getHubMetaUpdates.resolves(envioUpdates);

      const result = await reader.getHubMetaUpdates(domain, 0);
      expect(result.length).to.equal(3);
      expect(result.find((u) => u.id === 'hub-meta-2')).to.equal(graphUpdate2);
    });
  });

  describe('#getSpokeMetaUpdates', () => {
    it('should handle one reader failing and still return results', async () => {
      const graphUpdates: ProtocolUpdateLog[] = [
        {
          id: 'spoke-meta-1',
          domain,
          chainId: domain,
          event: 'GATEWAY_UPDATED',
          key: 'gateway',
          updated: mkBytes32('0xgw'),
          transactionHash: mkBytes32('0xtx'),
          timestamp: 1,
          blockNumber: 10,
          txOrigin: mkBytes32('0xorigin'),
          txNonce: 1,
        },
      ];
      graphReader.getSpokeMetaUpdates.resolves(graphUpdates);
      envioReader.getSpokeMetaUpdates.rejects(new Error('error'));

      const result = await reader.getSpokeMetaUpdates(domain, 0);
      expect(result).to.deep.equal(graphUpdates);
    });

    it('should merge results from both readers', async () => {
      const graphUpdates: ProtocolUpdateLog[] = [
        {
          id: 'spoke-meta-1',
          domain,
          chainId: domain,
          event: 'GATEWAY_UPDATED',
          key: 'gateway',
          updated: mkBytes32('0xgw'),
          transactionHash: mkBytes32('0xtx'),
          timestamp: 1,
          blockNumber: 10,
          txOrigin: mkBytes32('0xorigin'),
          txNonce: 1,
        },
      ];
      const envioUpdates: ProtocolUpdateLog[] = [
        {
          id: 'spoke-meta-2',
          domain,
          chainId: domain,
          event: 'GATEWAY_UPDATED',
          key: 'gateway',
          updated: mkBytes32('0xgw2'),
          transactionHash: mkBytes32('0xtx2'),
          timestamp: 2,
          blockNumber: 20,
          txOrigin: mkBytes32('0xorigin2'),
          txNonce: 2,
        },
      ];
      graphReader.getSpokeMetaUpdates.resolves(graphUpdates);
      envioReader.getSpokeMetaUpdates.resolves(envioUpdates);

      const result = await reader.getSpokeMetaUpdates(domain, 0);
      expect(result.length).to.equal(2);
    });
  });

  describe('#getHubTokenUpdates', () => {
    it('should merge results from both readers and deduplicate by id (prefer GraphReader)', async () => {
      const graphUpdate2: HubTokenUpdateLog = {
        id: 'hub-token-2',
        domain,
        tickerHash: mkBytes32('0xticker'),
        kind: 'TOKEN_CONFIGS_SET',
        feeRecipients: [],
        feeAmounts: [],
        maxDiscountBps: 0,
        discountPerEpoch: 0,
        prioritizedStrategy: 'DEFAULT',
        transactionHash: mkBytes32('0xtx'),
        timestamp: 1,
        blockNumber: 10,
        txOrigin: mkBytes32('0xorigin'),
        txNonce: 1,
      };
      const graphUpdates: HubTokenUpdateLog[] = [{ ...graphUpdate2, id: 'hub-token-1' }, graphUpdate2];
      const envioDupUpdate2: HubTokenUpdateLog = { ...graphUpdate2 }; // same id, different object
      const envioUpdates: HubTokenUpdateLog[] = [envioDupUpdate2, { ...graphUpdate2, id: 'hub-token-3' }];

      graphReader.getHubTokenUpdates.resolves(graphUpdates);
      envioReader.getHubTokenUpdates.resolves(envioUpdates);

      const result = await reader.getHubTokenUpdates(domain, 0);
      expect(result.length).to.equal(3);
      expect(result.find((u) => u.id === 'hub-token-2')).to.equal(graphUpdate2);
    });
  });

  describe('#getHubAssetUpdates', () => {
    it('should handle one reader failing and still return results', async () => {
      const graphUpdates: HubAssetUpdateLog[] = [
        {
          id: 'hub-asset-1',
          domain,
          assetId: mkBytes32('0xasset'),
          tokenId: mkBytes32('0xticker'),
          tickerHash: mkBytes32('0xticker'),
          assetDomain: '1338',
          kind: 'ASSET_CONFIG_SET',
          assetHash: mkBytes32('0xhash'),
          adopted: mkBytes32('0xadopted'),
          approval: true,
          strategy: 'DEFAULT',
          transactionHash: mkBytes32('0xtx'),
          timestamp: 1,
          blockNumber: 10,
          txOrigin: mkBytes32('0xorigin'),
          txNonce: 1,
        },
      ];
      graphReader.getHubAssetUpdates.resolves(graphUpdates);
      envioReader.getHubAssetUpdates.rejects(new Error('error'));

      const result = await reader.getHubAssetUpdates(domain, 0);
      expect(result).to.deep.equal(graphUpdates);
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

  describe('#getSettlementIntentsByNonce', () => {
    it('should merge results from both readers and deduplicate by intentId', async () => {
      const graphIntent1 = { intentId: mkBytes32('0x1'), id: 's1' } as unknown as SettlementIntent;
      const graphIntent2 = { intentId: mkBytes32('0x2'), id: 's2' } as unknown as SettlementIntent;
      const envioIntent2 = { intentId: mkBytes32('0x2'), id: 's2' } as unknown as SettlementIntent;
      const envioIntent3 = { intentId: mkBytes32('0x3'), id: 's3' } as unknown as SettlementIntent;

      graphReader.getSettlementIntentsByNonce.resolves([graphIntent1, graphIntent2]);
      envioReader.getSettlementIntentsByNonce.resolves([envioIntent2, envioIntent3]);

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getSettlementIntentsByNonce(queryParams);
      expect(result.length).to.be.eq(3);
      // Should prefer GraphReader result for duplicate intentId
      expect(result.find((i) => i.intentId === mkBytes32('0x2'))).to.equal(graphIntent2);
    });

    it('should handle errors gracefully', async () => {
      graphReader.getSettlementIntentsByNonce.rejects(new Error('error'));
      envioReader.getSettlementIntentsByNonce.resolves([]);

      const queryParams = new Map<string, SubgraphQueryMetaParams>([
        ['1337', { latestNonce: 0, maxBlockNumber: 1000 }],
      ]);

      const result = await reader.getSettlementIntentsByNonce(queryParams);
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

  // ===========================================================================
  // Tuple results
  // ===========================================================================

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

    it('should handle errors gracefully', async () => {
      graphReader.getHubIntentsByNonce.resolves([[{ id: 'intent1' }] as any[], [], []]);
      envioReader.getHubIntentsByNonce.rejects(new Error('error'));

      const result = await reader.getHubIntentsByNonce('1337', 0, 0, 0, 1000);
      expect(result[0].length).to.be.eq(1);
      expect(result[1].length).to.be.eq(0);
      expect(result[2].length).to.be.eq(0);
    });

    it('should return empty tuples when both readers fail', async () => {
      graphReader.getHubIntentsByNonce.rejects(new Error('error'));
      envioReader.getHubIntentsByNonce.rejects(new Error('error'));

      const result = await reader.getHubIntentsByNonce('1337', 0, 0, 0, 1000);
      expect(result[0].length).to.be.eq(0);
      expect(result[1].length).to.be.eq(0);
      expect(result[2].length).to.be.eq(0);
    });

    it('should prefer GraphReader results for duplicate IDs', async () => {
      const graphIntent = { id: 'intent1', extra: 'graph' } as any;
      const envioIntent = { id: 'intent1', extra: 'envio' } as any;

      graphReader.getHubIntentsByNonce.resolves([[graphIntent], [], []]);
      envioReader.getHubIntentsByNonce.resolves([[envioIntent], [], []]);

      const result = await reader.getHubIntentsByNonce('1337', 0, 0, 0, 1000);
      expect(result[0].length).to.be.eq(1);
      expect(result[0][0]).to.equal(graphIntent);
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

    it('should handle errors gracefully', async () => {
      graphReader.getHubInvoicesByNonce.resolves([[{ id: 'invoice1' }] as any[], [{ id: 'intent1' }] as any[]]);
      envioReader.getHubInvoicesByNonce.rejects(new Error('error'));

      const result = await reader.getHubInvoicesByNonce('1337', 0, 1000);
      expect(result[0].length).to.be.eq(1);
      expect(result[1].length).to.be.eq(1);
    });

    it('should return empty tuples when both readers fail', async () => {
      graphReader.getHubInvoicesByNonce.rejects(new Error('error'));
      envioReader.getHubInvoicesByNonce.rejects(new Error('error'));

      const result = await reader.getHubInvoicesByNonce('1337', 0, 1000);
      expect(result[0].length).to.be.eq(0);
      expect(result[1].length).to.be.eq(0);
    });

    it('should prefer GraphReader results for duplicate IDs', async () => {
      const graphInvoice = { id: 'invoice1', extra: 'graph' } as any;
      const envioInvoice = { id: 'invoice1', extra: 'envio' } as any;

      graphReader.getHubInvoicesByNonce.resolves([[graphInvoice], []]);
      envioReader.getHubInvoicesByNonce.resolves([[envioInvoice], []]);

      const result = await reader.getHubInvoicesByNonce('1337', 0, 1000);
      expect(result[0].length).to.be.eq(1);
      expect(result[0][0]).to.equal(graphInvoice);
    });
  });

  // ===========================================================================
  // Error handling
  // ===========================================================================

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

    it('should handle synchronous throws in firstResult', async () => {
      graphReader.getOriginIntentById.throws(new Error('sync error'));
      envioReader.getOriginIntentById.resolves({ id: mkBytes32('0x1') } as OriginIntent);

      const result = await reader.getOriginIntentById(domain, mkBytes32('0x1'));
      expect(result).to.not.be.undefined;
    });

    it('should handle synchronous throws in mergeArrays', async () => {
      graphReader.getSpokeQueues.throws(new Error('sync error'));
      envioReader.getSpokeQueues.resolves([{ id: 'queue1' }] as any[]);

      const result = await reader.getSpokeQueues(domain);
      expect(result.length).to.be.eq(1);
    });
  });
});
