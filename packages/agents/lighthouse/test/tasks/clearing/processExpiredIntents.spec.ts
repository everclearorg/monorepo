import { Database } from '@chimera-monorepo/database/src';
import { SinonStub, SinonStubbedInstance, stub } from 'sinon';
import { mock } from '../../globalTestHook';
import { createHubIntents } from '@chimera-monorepo/database/test/mock';
import { RelayerType, getNtpTimeSeconds, expect, mkBytes32, Logger } from '@chimera-monorepo/utils';
import { Interface } from 'ethers/lib/utils';
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

    encodeFunctionData = stub(Interface.prototype, 'encodeFunctionData').returns('0xencoded');
    decodeFunctionResult = stub(Interface.prototype, 'decodeFunctionResult').returns([{ status: 2 }]);
    decodeFunctionResult.onCall(0).returns([TTL.toString()]);

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
    const [name, [params]] = encodeFunctionData.lastCall.args;
    expect(name).to.be.eq('handleExpiredIntents');
    console.log(params);
    expect(params.length).to.be.eq(2);
    expect(params).to.be.deep.eq([...new Set(intents.map((i) => i.id))]);
  });
});
