import { SinonStub, SinonStubbedInstance, stub, reset, restore } from 'sinon';
import { mock, getContextStub } from '../../globalTestHook';
import * as Relayer from '@chimera-monorepo/adapters-relayer';
import { RelayerType, getNtpTimeSeconds, expect, mkBytes32, Logger, mkAddress } from '@chimera-monorepo/utils';
import { Interface } from 'ethers/lib/utils';
import { BigNumber, utils } from 'ethers';
import { ChainService } from '@chimera-monorepo/chainservice';
import { processDepositsAndInvoices } from '../../../src/tasks/invoice';
import { LighthouseConfig } from '../../../src/config';
import { Database } from '@chimera-monorepo/database';
import { MAX_UNPROCESSED_EPOCHS_COUNT } from '../../../src/tasks/invoice/processDepositsAndInvoices';

describe('#processDepositsAndInvoices', () => {
  let chainservice: SinonStubbedInstance<ChainService>;
  let logger: SinonStubbedInstance<Logger>;
  let encodeFunctionData: SinonStub;
  let decodeFunctionResult: SinonStub;
  let chains: LighthouseConfig['chains'];
  let database: SinonStubbedInstance<Database>;
  const mockGetFunction = new Interface(['function foo()']).getFunction('foo');

  const tickers = ['USDC'];
  beforeEach(() => {
    const assets = Object.fromEntries(
      tickers.map((t) => {
        return [
          t,
          {
            address: mkAddress('0x' + t),
            symbol: t,
            decimals: t === 'DAI' ? 18 : 6,
            isNative: false,
            coingeckoId: t.toLowerCase(),
            price: {},
          },
        ];
      }),
    );
    chains = mock.chains({
      '1337': {
        ...mock.chains()[1337],
        assets,
      },
      '1338': {
        ...mock.chains()[1338],
        assets,
      },
    });

    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    chainservice = mock.instances.chainservice() as SinonStubbedInstance<ChainService>;
    chainservice.readTx.resolves('0xencoded');

    database = mock.instances.database() as SinonStubbedInstance<Database>;
    database.getAssets.resolves(
      Object.entries(assets).map(([ticker, a]) => ({
        id: `1337-${utils.keccak256(utils.toUtf8Bytes(ticker))}`,
        token: utils.keccak256(utils.toUtf8Bytes(ticker)),
        domain: '1337',
        adopted: a.address,
        approval: true,
        strategy: 'Default',
      })),
    );

    encodeFunctionData = stub(Interface.prototype, 'encodeFunctionData');
    decodeFunctionResult = stub(Interface.prototype, 'decodeFunctionResult');
    Relayer.sendWithRelayerWithBackup = stub(Relayer, 'sendWithRelayerWithBackup').resolves({
      taskId: '123',
      relayerType: RelayerType.Everclear,
    });

    stub(Interface.prototype, 'getFunction').returns(mockGetFunction);

    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config(), chains },
    });
  });

  afterEach(() => {
    restore();
    reset();
  });

  it('should work', async () => {
    encodeFunctionData.returns('0xencoded');

    // Mock iface.decodeFunctionResult('invoices', ...);
    decodeFunctionResult.onCall(0).returns([['invoice1']]);

    // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
    decodeFunctionResult.onCall(1).returns([[1]]);

    // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
    decodeFunctionResult.onCall(2).returns([BigNumber.from(25)]);

    // Mock iface.decodeFunctionResult('depositsAvailableInEpoch', ...);
    decodeFunctionResult.onCall(3).returns([BigNumber.from(25)]);

    // Mock chainservice.getBlockNumber
    chainservice.getBlockNumber.resolves(100);

    await processDepositsAndInvoices();

    const hub = mock.hub();
    // verify call to relayer
    expect(
      Relayer.sendWithRelayerWithBackup.calledWith(
        +hub.domain,
        hub.domain,
        hub.deployments.everclear,
        '0xencoded',
        '0',
      ),
    ).to.be.true;
    // verify call to encoding
    const [name, [params]] = encodeFunctionData.lastCall.args;
    expect(name).to.be.eq('processDepositsAndInvoices');
    expect(params.length).to.be.eq(66);
  });

  it('should skip processing if no invoices and the last epoch already processed', async () => {
    encodeFunctionData.returns('0xencoded');

    // Mock iface.decodeFunctionResult('invoices', ...);
    // Return the mock invoice list
    decodeFunctionResult.onCall(0).returns({head: mkBytes32(), tail: mkBytes32(), length: 0, nodes: {}});

    // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
    decodeFunctionResult.onCall(1).returns([[24]]);

    // Mock iface.decodeFunctionResult('getCurrentEpoch', ...);
    decodeFunctionResult.onCall(2).returns([BigNumber.from(25)]);

    await processDepositsAndInvoices();

    const hub = mock.hub();
    expect(
      Relayer.sendWithRelayerWithBackup.calledWith(
        +hub.domain,
        hub.domain,
        hub.deployments.everclear,
        '0xencoded',
        '0',
      ),
    ).to.be.false;
  });

  describe('unprocessed epochs limit', () => {
    it('should process when unprocessed epochs count exceeds limit', async () => {
      encodeFunctionData.returns('0xencoded');

      // Mock iface.decodeFunctionResult('invoices', ...);
      // Return empty invoice list
      decodeFunctionResult.onCall(0).returns({head: mkBytes32(), tail: mkBytes32(), length: 0, nodes: {}});

      // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
      // Last processed epoch: 50
      decodeFunctionResult.onCall(1).returns([[50]]);

      // Mock iface.decodeFunctionResult('getCurrentEpoch', ...);
      // Current epoch: 152 (so lastClosedEpoch = 151)
      // unprocessedEpochsCount = 151 - 50 = 101 > 100 (limit hit)
      decodeFunctionResult.onCall(2).returns([BigNumber.from(50 + 1 + MAX_UNPROCESSED_EPOCHS_COUNT + 1)]);

      // Mock depositsAvailableInEpoch calls - return 0 for all remaining calls
      // Set default return first, then override with onCall for specific calls
      decodeFunctionResult.returns([BigNumber.from(0)]);

      await processDepositsAndInvoices();

      const hub = mock.hub();
      // Should call relayer because unprocessedEpochsCount > MAX_UNPROCESSED_EPOCHS_COUNT
      expect(
        Relayer.sendWithRelayerWithBackup.calledWith(
          +hub.domain,
          hub.domain,
          hub.deployments.everclear,
          '0xencoded',
          '0',
        ),
      ).to.be.true;
    });

    it('should process when unprocessed epochs count equals limit', async () => {
      encodeFunctionData.returns('0xencoded');

      // Mock iface.decodeFunctionResult('invoices', ...);
      // Return empty invoice list
      decodeFunctionResult.onCall(0).returns({head: mkBytes32(), tail: mkBytes32(), length: 0, nodes: {}});

      // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
      // Last processed epoch: 50
      decodeFunctionResult.onCall(1).returns([[50]]);

      // Mock iface.decodeFunctionResult('getCurrentEpoch', ...);
      // Current epoch: 151 (so lastClosedEpoch = 150)
      // unprocessedEpochsCount = 150 - 50 = 100 (exactly at limit, but limit check is >, so not hit)
      decodeFunctionResult.onCall(2).returns([BigNumber.from(50 + 1 + MAX_UNPROCESSED_EPOCHS_COUNT)]);

      // Mock depositsAvailableInEpoch calls - return 0 for all remaining calls
      decodeFunctionResult.returns([BigNumber.from(0)]);

      await processDepositsAndInvoices();

      const hub = mock.hub();
      // Should call relayer because:
      // - No invoices
      // - No deposits
      // - unprocessedEpochsCount is NOT >= MAX_UNPROCESSED_EPOCHS_COUNT
      expect(
        Relayer.sendWithRelayerWithBackup.calledWith(
          +hub.domain,
          hub.domain,
          hub.deployments.everclear,
          '0xencoded',
          '0',
        ),
      ).to.be.true;
    });

    it('should skip processing when unprocessed epochs count is below limit', async () => {
      encodeFunctionData.returns('0xencoded');

      // Mock iface.decodeFunctionResult('invoices', ...);
      // Return empty invoice list
      decodeFunctionResult.onCall(0).returns({head: mkBytes32(), tail: mkBytes32(), length: 0, nodes: {}});

      // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
      // Last processed epoch: 100
      decodeFunctionResult.onCall(1).returns([[100]]);

      // Mock iface.decodeFunctionResult('getCurrentEpoch', ...);
      // Current epoch: 200 (so lastClosedEpoch = 199)
      // unprocessedEpochsCount = 199 - 100 = 99 <= 100 (limit not hit)
      decodeFunctionResult.onCall(2).returns([BigNumber.from(100 + 1 + MAX_UNPROCESSED_EPOCHS_COUNT - 1)]);

      // Mock depositsAvailableInEpoch calls - return 0 for all remaining calls
      decodeFunctionResult.returns([BigNumber.from(0)]);

      await processDepositsAndInvoices();

      const hub = mock.hub();
      // Should NOT call relayer because:
      // - No invoices
      // - No deposits (all depositsAvailableInEpoch = 0)
      // - unprocessedEpochsCount < MAX_UNPROCESSED_EPOCHS_COUNT
      expect(
        Relayer.sendWithRelayerWithBackup.calledWith(
          +hub.domain,
          hub.domain,
          hub.deployments.everclear,
          '0xencoded',
          '0',
        ),
      ).to.be.false;
    });

    it('should process when unprocessed epochs count is below limit but there are invoices', async () => {
      encodeFunctionData.returns('0xencoded');

      // Mock iface.decodeFunctionResult('invoices', ...);
      // Return invoice list with invoices
      decodeFunctionResult.onCall(0).returns({head: mkBytes32('0x123'), tail: mkBytes32('0x123'), length: 1, nodes: {}});

      // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
      // Last processed epoch: 100
      decodeFunctionResult.onCall(1).returns([[100]]);

      // Mock iface.decodeFunctionResult('getCurrentEpoch', ...);
      // Current epoch: 151 (so lastClosedEpoch = 150)
      // unprocessedEpochsCount = 151 - 100 = 50 <= 100 (limit not hit)
      decodeFunctionResult.onCall(2).returns([BigNumber.from(100 + 1 + MAX_UNPROCESSED_EPOCHS_COUNT / 2)]);

      // Mock depositsAvailableInEpoch calls - return 0 for all remaining calls
      decodeFunctionResult.returns([BigNumber.from(0)]);

      await processDepositsAndInvoices();

      const hub = mock.hub();
      // Should call relayer because there are invoices to process
      expect(
        Relayer.sendWithRelayerWithBackup.calledWith(
          +hub.domain,
          hub.domain,
          hub.deployments.everclear,
          '0xencoded',
          '0',
        ),
      ).to.be.true;
    });

    it('should process when unprocessed epochs count is below limit but there are deposits', async () => {
      encodeFunctionData.returns('0xencoded');

      // Mock iface.decodeFunctionResult('invoices', ...);
      // Return empty invoice list
      decodeFunctionResult.onCall(0).returns({head: mkBytes32(), tail: mkBytes32(), length: 0, nodes: {}});

      // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
      // Last processed epoch: 100
      decodeFunctionResult.onCall(1).returns([[100]]);

      // Mock iface.decodeFunctionResult('getCurrentEpoch', ...);
      // Current epoch: 151 (so lastClosedEpoch = 150)
      // unprocessedEpochsCount = 150 - 100 = 50 <= 100 (limit not hit)
      decodeFunctionResult.onCall(2).returns([BigNumber.from(100 + 1 + MAX_UNPROCESSED_EPOCHS_COUNT / 2)]);

      // Mock depositsAvailableInEpoch calls
      // First call (epoch 101, spoke 1337) has deposits, which will cause early break
      decodeFunctionResult.onCall(3).returns([BigNumber.from(1000)]); // spoke 1337, epoch 101 has deposits

      await processDepositsAndInvoices();

      const hub = mock.hub();
      // Should call relayer because there are deposits to process
      expect(
        Relayer.sendWithRelayerWithBackup.calledWith(
          +hub.domain,
          hub.domain,
          hub.deployments.everclear,
          '0xencoded',
          '0',
        ),
      ).to.be.true;
    });
  });
});
