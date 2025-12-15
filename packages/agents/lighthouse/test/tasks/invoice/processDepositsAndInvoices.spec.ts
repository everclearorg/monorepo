import { SinonStub, SinonStubbedInstance, stub, reset, restore } from 'sinon';
import { mock, getContextStub } from '../../globalTestHook';
import * as Relayer from '@chimera-monorepo/adapters-relayer';
import { RelayerType, getNtpTimeSeconds, expect, mkBytes32, Logger, mkAddress, chainWrapper } from '@chimera-monorepo/utils';
import { ChainService } from '@chimera-monorepo/chainservice';
import { processDepositsAndInvoices } from '../../../src/tasks/invoice';
import { LighthouseConfig } from '../../../src/config';
import { Database } from '@chimera-monorepo/database';

describe('#processDepositsAndInvoices', () => {
  let chainservice: SinonStubbedInstance<ChainService>;
  let logger: SinonStubbedInstance<Logger>;
  let encodeFunctionData: SinonStub;
  let decodeFunctionResult: SinonStub;
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
    // Remove local readTx stub - use global one

    database = mock.instances.database() as SinonStubbedInstance<Database>;
    database.getAssets.resolves([
      {
        id: `1337-${chainWrapper.keccak256(chainWrapper.stringToHex('USDC'))}`,
        token: chainWrapper.keccak256(chainWrapper.stringToHex('USDC')),
        domain: '1337',
        adopted: mkAddress('0xUSDC'),
        approval: true,
        strategy: 'Default',
      },
      {
        id: `6398-${chainWrapper.keccak256(chainWrapper.stringToHex('ETH'))}`,
        token: chainWrapper.keccak256(chainWrapper.stringToHex('ETH')),
        domain: '6398',
        adopted: mkAddress('0x456'),
        approval: true,
        strategy: 'Default',
      },
      {
        id: `6398-${chainWrapper.keccak256(chainWrapper.stringToHex('WETH'))}`,
        token: chainWrapper.keccak256(chainWrapper.stringToHex('WETH')),
        domain: '6398',
        adopted: mkAddress('0x567'),
        approval: true,
        strategy: 'Default',
      },
      {
        id: `6398-${chainWrapper.keccak256(chainWrapper.stringToHex('CLEAR'))}`,
        token: chainWrapper.keccak256(chainWrapper.stringToHex('CLEAR')),
        domain: '6398',
        adopted: mkAddress('0x678'),
        approval: true,
        strategy: 'Default',
      },
    ]);

    encodeFunctionData = stub(chainWrapper, 'encodeFunctionData').returns('0xencoded');
    decodeFunctionResult = stub(chainWrapper, 'decodeFunctionResult').returns(BigInt(0));
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
    decodeFunctionResult.onCall(0).returns({
      head: mkBytes32('0x1234'),
      tail: mkBytes32('0x5678'),
      length: BigInt(1),
      nodes: {}
    });

    // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
    decodeFunctionResult.onCall(1).returns(BigInt(24));

    // Mock iface.decodeFunctionResult('lastClosedEpochsProcessed', ...);
    decodeFunctionResult.onCall(2).returns(BigInt(25));

    // Mock iface.decodeFunctionResult('depositsAvailableInEpoch', ...);
    decodeFunctionResult.onCall(3).returns(BigInt(1000000)); // Return a value > 0 to trigger deposits processing

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
    expect(encodeFunctionData.called).to.be.true;
  });

  it('should skip processing if no invoices and the last epoch already processed', async () => {
    encodeFunctionData.returns('0xencoded');

    // Mock decodeFunctionResult to return appropriate values for all calls
    decodeFunctionResult.callsFake((args) => {
      // Mock invoices call - return empty invoice list
      if (args.functionName === 'invoices') {
        return {head: mkBytes32(), tail: mkBytes32(), length: 0, nodes: {}};
      }
      // Mock lastClosedEpochsProcessed call - return 24 (same as currentEpoch - 1)
      if (args.functionName === 'lastClosedEpochsProcessed') {
        return BigInt(24);
      }
      // Mock getCurrentEpoch call - return 25
      if (args.functionName === 'getCurrentEpoch') {
        return BigInt(25);
      }
      // Mock depositsAvailableInEpoch call - return 0 (no deposits)
      if (args.functionName === 'depositsAvailableInEpoch') {
        return BigInt(0);
      }
      // Default fallback
      return BigInt(0);
    });

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
