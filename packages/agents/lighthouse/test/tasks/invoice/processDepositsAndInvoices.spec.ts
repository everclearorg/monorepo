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

describe('#processDepositsAndInvoices', () => {
  let chainservice: SinonStubbedInstance<ChainService>;
  let logger: SinonStubbedInstance<Logger>;
  let encodeFunctionData: SinonStub;
  let decodeFunctionResult: SinonStub;
  let sendWithRelayerWithBackup: SinonStub;
  let chains: LighthouseConfig['chains'];
  let database: SinonStubbedInstance<Database>;

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
    decodeFunctionResult.onCall(1).returns([[3]]);

    // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
    decodeFunctionResult.onCall(2).returns([BigNumber.from(25)]);

    // Mock chainservice.getBlockNumber
    chainservice.getBlockNumber.resolves(100);

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
});
