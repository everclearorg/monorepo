import { Database } from '@chimera-monorepo/database/src';
import { SinonStub, SinonStubbedInstance, stub } from 'sinon';
import { mock } from '../../globalTestHook';
import { createHubIntents } from '@chimera-monorepo/database/test/mock';
import { RelayerType, getNtpTimeSeconds, expect, mkBytes32, Logger, chainWrapper } from '@chimera-monorepo/utils';
import { ChainService } from '@chimera-monorepo/chainservice';
import * as Relayer from '@chimera-monorepo/adapters-relayer';

import { processExpiredIntents } from '../../../src/tasks/clearing';

describe('#processExpiredIntents', () => {
  let database: SinonStubbedInstance<Database>;
  let chainservice: SinonStubbedInstance<ChainService>;
  let logger: SinonStubbedInstance<Logger>;
  let encodeFunctionData: SinonStub;
  let decodeFunctionResult: SinonStub;
  let sendWithRelayerWithBackup: SinonStub;

  const TTL = 1_000;

  const intents = createHubIntents(2, [
    {
      status: 'ADDED',
      id: mkBytes32('0x1'),
      domain: '1337',
      addedTimestamp: getNtpTimeSeconds() - 2_000,
    },
    {
      status: 'ADDED',
      id: mkBytes32('0x2'),
      domain: '1337',
      addedTimestamp: getNtpTimeSeconds() - 2_000,
    },
  ]);

  beforeEach(() => {
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;

    chainservice = mock.instances.chainservice() as SinonStubbedInstance<ChainService>;
    chainservice.readTx.resolves('0xencoded');

    database = mock.instances.database() as SinonStubbedInstance<Database>;
    database.getExpiredIntents.resolves(intents);

    encodeFunctionData = stub(chainWrapper, 'encodeFunctionData').returns('0xencoded');
    decodeFunctionResult = stub(chainWrapper, 'decodeFunctionResult').returns(BigInt(TTL));

    sendWithRelayerWithBackup = stub(Relayer, 'sendWithRelayerWithBackup').resolves({
      taskId: '123',
      relayerType: RelayerType.Everclear,
    });
  });

  it('should fail if it cannot get the intent TTL from the hub', async () => {
    chainservice.readTx.rejects(new Error('fail'));
    await expect(processExpiredIntents()).to.be.rejectedWith('fail');
  });

  it('should fail if it cannot get the expired intents from the database', async () => {
    database.getExpiredIntents.rejects(new Error('fail'));
    await expect(processExpiredIntents()).to.be.rejectedWith('fail');
  });

  it('should fail if it cannot submit the expired settlement to the relayer', async () => {
    sendWithRelayerWithBackup.rejects(new Error('fail'));
    await expect(processExpiredIntents()).to.be.rejectedWith('fail');
  });

  it('should return early if no expired intents exist', async () => {
    database.getExpiredIntents.resolves([]);
    await processExpiredIntents();
    expect(logger.info.calledWith('No expired intents to process')).to.be.true;
  });

  it('should work', async () => {
    await processExpiredIntents();
    const hub = mock.hub();
    // verify call to relayer
    expect(sendWithRelayerWithBackup.calledWith(+hub.domain, hub.domain, hub.deployments.everclear, '0xencoded', '0'))
      .to.be.true;
    // verify call to encoding
    expect(encodeFunctionData.called).to.be.true;
    const lastCall = encodeFunctionData.lastCall;
    expect(lastCall).to.not.be.undefined;
    expect(lastCall!.args).to.not.be.undefined;
    const args = lastCall!.args;
    expect(args).to.not.be.undefined;
    expect(args.length).to.be.greaterThan(0);
    const callObject = args[0];
    expect(callObject).to.not.be.undefined;
    expect(callObject.functionName).to.be.eq('handleExpiredIntents');
    const params = callObject.args[0];
    expect(params.length).to.be.eq(2);
    expect(params).to.be.deep.eq([...new Set(intents.map((i) => i.id))]);
  });
});
