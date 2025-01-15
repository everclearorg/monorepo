import { Logger, expect, getNtpTimeSeconds, mkBytes32 } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkInvoices, checkInvoiceAmount } from '../../src/checklist/queue';
import { getContextStub, mock } from '../globalTestHook';
import { Database } from '@chimera-monorepo/database';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../mock';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { Interface } from 'ethers/lib/utils';
import * as intents from '../../src/helpers/intent';
import * as asset from '../../src/helpers/asset';
import * as Mockable from '../../src/mockable';

describe('checkInvoices', () => {
  let subgraph: SinonStubbedInstance<SubgraphReader>;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let sendAlertsStub: SinonStub;
  let getCurrentEpochStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;
  let encode: SinonStub;
  let decode: SinonStub;
  let database: SinonStubbedInstance<Database>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    subgraph = mock.instances.subgraph() as SinonStubbedInstance<SubgraphReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    encode = stub(Interface.prototype, 'encodeFunctionData');
    decode = stub(Interface.prototype, 'decodeFunctionResult');
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    encode.returns('0xencoded');
    decode.returns(['FILLED']);

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    stub(Mockable, 'resolveAlerts').resolves();

    getCurrentEpochStub = stub(intents, 'getCurrentEpoch');
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkInvoices', () => {
    it('should send alert if invoice processing exceeds threshold', async () => {
      const curTime = getNtpTimeSeconds();
      database.getHubIntentsByStatus.resolves([mock.hubIntent({ addedTimestamp: curTime - 24 * 3600 })]);
      database.getHubInvoicesByIntentIds.resolves([mock.hubInvoice({ entryEpoch: 1 })]);
      getCurrentEpochStub.resolves(2);
      await checkInvoices();
      expect(sendAlertsStub.callCount).to.eq(1);
      expect((sendAlertsStub.getCall(0).args[0] as any).type).to.be.eq('InvoiceNotProcessedYet');
    });

    it('should not send alert if discount of invoice is less than 5', async () => {
      const curTime = getNtpTimeSeconds();
      database.getHubIntentsByStatus.resolves([mock.hubIntent({ addedTimestamp: curTime - 22 * 3600 })]);
      database.getHubInvoicesByIntentIds.resolves([mock.hubInvoice({ entryEpoch: 1 })]);
      getCurrentEpochStub.resolves(3);
      await checkInvoices();
      expect(sendAlertsStub.callCount).to.eq(0);
    });
  });
});

describe('checkInvoiceAmount', () => {
  let subgraph: SinonStubbedInstance<SubgraphReader>;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let sendAlertsStub: SinonStub;
  let getCurrentEpochStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;
  let database: SinonStubbedInstance<Database>;
  let getCustodiedAssetsFromHubContractStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    subgraph = mock.instances.subgraph() as SinonStubbedInstance<SubgraphReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    sendAlertsStub = stub(Mockable, 'sendAlerts');
    getCurrentEpochStub = stub(intents, 'getCurrentEpoch');
    getCustodiedAssetsFromHubContractStub = stub(asset, 'getCustodiedAssetsFromHubContract');
  });

  afterEach(() => {
    restore();
    reset();
  });

  it('should process invoices and send alerts if conditions are met', async () => {
    // Mock data
    const mockInvoices = [
      mock.invoice({ id: '1', originIntent: mock.originIntent({ outputAsset: 'asset1' }), hubInvoiceAmount: '100' }),
      mock.invoice({ id: '2', originIntent: mock.originIntent({ outputAsset: 'asset2' }), hubInvoiceAmount: '200' }),
    ];
    const mockCustodiedAssets = {
      asset1: '150',
      asset2: '250',
    };

    // Stubbing database methods
    database.getInvoicesByStatus.resolves(mockInvoices);
    getCustodiedAssetsFromHubContractStub.callsFake((assetHash) => {
      return Promise.resolve(mockCustodiedAssets[assetHash]);
    });

    // Stubbing other methods
    getCurrentEpochStub.resolves(1234567890);
    sendAlertsStub.resolves();

    // Call the function
    await checkInvoiceAmount();

    // Assertions
    expect(sendAlertsStub.called).to.be.true;
    expect(sendAlertsStub.callCount).to.equal(1);
  });

  it('should not send alerts if no invoices meet the conditions', async () => {
    // Mock data
    const mockInvoices = [
      mock.invoice({ id: '1', originIntent: mock.originIntent({ outputAsset: 'asset1' }), hubInvoiceAmount: '150' }),
      mock.invoice({ id: '2', originIntent: mock.originIntent({ outputAsset: 'asset2' }), hubInvoiceAmount: '250' }),
    ];
    const mockCustodiedAssets = {
      asset1: '150',
      asset2: '250',
    };

    // Stubbing database methods
    database.getInvoicesByStatus.resolves(mockInvoices);
    getCustodiedAssetsFromHubContractStub.callsFake((assetHash) => {
      return Promise.resolve(mockCustodiedAssets[assetHash]);
    });

    // Stubbing other methods
    getCurrentEpochStub.resolves(1234567890);
    sendAlertsStub.resolves();

    // Call the function
    await checkInvoiceAmount();

    // Assertions
    expect(sendAlertsStub.called).to.be.false;
  });
});