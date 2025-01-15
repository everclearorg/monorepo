import { Logger, RelayerType, Settlement, domainToChainId, expect, mkBytes32 } from '@chimera-monorepo/utils';
import * as Relayer from '@chimera-monorepo/adapters-relayer';
import { Bytes, Interface } from 'ethers/lib/utils';
import { constants, Wallet } from 'ethers';
import { SinonStub, SinonStubbedInstance, createStubInstance, stub } from 'sinon';

import { dispatchMessageQueueViaRelayers, getQueueMethodName } from '../../../src/tasks/helpers';
import { createIntentQueues, getContextStub, mock } from '../../globalTestHook';
import { LighthouseContext } from '../../../src/context';
import { RelayerSendFailed } from '../../../src/errors/tasks';

describe('Helpers:dispatchMessageQueueViaRelayers', () => {
  const [queue] = createIntentQueues();
  const intents = [mock.destinationIntent({ origin: queue.domain })];
  const rc = mock.requestContext();
  let context: LighthouseContext;

  let sendWithRelayerWithBackupStub: SinonStub;
  let encodeStub: SinonStub;
  let decodeStub: SinonStub;
  let wallet: SinonStubbedInstance<Wallet>;

  beforeEach(() => {
    // Interface stubs
    wallet = createStubInstance(Wallet, {
      signMessage: stub<[string | Bytes], Promise<string>>().resolves('0xsigned'),
    });

    // Set mock context
    context = {
      ...mock.context(),
      config: {
        ...mock.config(),
        thresholds: {
          '1337': {
            maxAge: 10,
            size: 2,
          },
          '1338': {
            maxAge: 10,
            size: 2,
          },
          '1339': {
            maxAge: 10,
            size: 2,
          },
        },
      },
      adapters: {
        ...mock.context().adapters,
        wallet,
      },
    };

    // Function stubs
    getContextStub.returns(context);
    encodeStub = stub(Interface.prototype, 'encodeFunctionData').returns('0xencoded');
    decodeStub = stub(Interface.prototype, 'decodeFunctionResult').returns([constants.Zero]);
    sendWithRelayerWithBackupStub = stub(Relayer, 'sendWithRelayerWithBackup').resolves({
      taskId: '123',
      relayerType: RelayerType.Everclear,
    });
  });

  it('should return early if chain is not configured', async () => {
    const result = await dispatchMessageQueueViaRelayers('INTENT', { ...queue, domain: '123123' }, intents, rc);
    expect(result).to.be.empty;
    expect(sendWithRelayerWithBackupStub.callCount).to.be.eq(0);
    expect((context.logger.warn as SinonStub).calledWith('Missing chain config')).to.be.true;
  });

  it('should return early if deployments are not configured', async () => {
    getContextStub.returns({
      ...context,
      config: {
        ...context.config,
        chains: {
          ...context.config.chains,
          [queue.domain]: {
            deployments: {},
          },
        },
      },
    });
    const result = await dispatchMessageQueueViaRelayers('INTENT', queue, intents, rc);
    expect(result).to.be.empty;
    expect(sendWithRelayerWithBackupStub.callCount).to.be.eq(0);
    expect((context.logger.warn as SinonStub).calledWith('Missing gateway or everclear address')).to.be.true;
  });

  it('should fail if all relayers cannot get address', async () => {
    (context.adapters.relayers[0].instance.getRelayerAddress as SinonStub).rejects(new Error('fail'));
    await expect(dispatchMessageQueueViaRelayers('INTENT', queue, intents, rc)).to.be.rejectedWith(RelayerSendFailed);
    expect(sendWithRelayerWithBackupStub.callCount).to.be.eq(0);
  });

  it('should fail if wallet cannot sign messages', async () => {
    wallet.signMessage.rejects(new Error('fail'));
    await expect(dispatchMessageQueueViaRelayers('INTENT', queue, intents, rc)).to.be.rejectedWith(RelayerSendFailed);
    expect(sendWithRelayerWithBackupStub.callCount).to.be.eq(0);
  });

  it('should fail if encoding function data fails', async () => {
    encodeStub.throws(new Error('fail'));
    // first instance is when wallet nonce is decoded, outside of try-catch
    await expect(dispatchMessageQueueViaRelayers('INTENT', queue, intents, rc)).to.be.rejectedWith('fail');
    expect(sendWithRelayerWithBackupStub.callCount).to.be.eq(0);
  });

  it('should fail if all relayer sends fail', async () => {
    sendWithRelayerWithBackupStub.rejects(new Error('fail'));
    await expect(dispatchMessageQueueViaRelayers('INTENT', queue, intents, rc)).to.be.rejectedWith(RelayerSendFailed);
    expect(sendWithRelayerWithBackupStub.callCount).to.be.eq(context.adapters.relayers.length);
  });

  it('should work', async () => {
    const ret = await dispatchMessageQueueViaRelayers('INTENT', queue, intents, rc);
    expect(ret).to.not.be.empty;
    expect(
      sendWithRelayerWithBackupStub.alwaysCalledWithExactly(
        domainToChainId(queue.domain),
        queue.domain,
        mock.chains()[queue.domain].deployments?.everclear,
        '0xencoded', // encode stub value
        '0',
        [context.adapters.relayers[0]],
        context.adapters.chainservice,
        context.logger,
        rc,
      ),
    ).to.be.true;
  });

  it('should work for settlements', async () => {
    const settlements: Settlement[] = [
      {
        intentId: intents[0].id,
        amount: intents[0].amount,
        asset: intents[0].outputAsset,
        recipient: intents[0].receiver,
      },
    ];
    const ret = await dispatchMessageQueueViaRelayers('SETTLEMENT', { ...queue, type: 'SETTLEMENT' }, settlements, rc);
    expect(ret).to.not.be.empty;
    expect(encodeStub.calledWith(getQueueMethodName('SETTLEMENT'))).to.be.true;
  });

  it('should not dispatch more than 15 intents for a 10M gas limit message destination', async () => {
    context.config.chains['1337'].gasLimit = 10_000_000;
    const largeQueue = mock.queue({ type: 'INTENT', size: 150, lastProcessed: 0, domain: '1337' });
    const contents = new Array(queue.size)
      .fill(0)
      .map((_, i) => mock.originIntent({ origin: queue.domain, id: mkBytes32(`0x${i}${i}${i}`) }));
    await dispatchMessageQueueViaRelayers('INTENT', largeQueue, contents, rc);
    // FIXME: revert this to 15 once batching is implemented 
    expect(sendWithRelayerWithBackupStub.callCount).to.be.greaterThanOrEqual(1); // 150 / 15, should dispatch 10 tasks
    const call = (context.logger as SinonStubbedInstance<Logger>).debug
      .getCalls()
      .find((c) => c.args.includes('Generating transaction for relayer'));
    expect(call).to.not.be.undefined;
    expect(call!.lastArg.toDequeue).to.be.lessThanOrEqual(15);
  });
});
