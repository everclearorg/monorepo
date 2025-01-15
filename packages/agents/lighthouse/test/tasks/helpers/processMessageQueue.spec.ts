import { OriginIntent, RelayerType, expect, mkBytes32 } from '@chimera-monorepo/utils';
import { SinonStub, stub } from 'sinon';
import { getContextStub, mock, createIntentQueues } from '../../globalTestHook';
import { Interface } from 'ethers/lib/utils';
import * as Relayer from '@chimera-monorepo/adapters-relayer';
import { processMessageQueue } from '../../../src/tasks/helpers';

describe('Process Message Queue', () => {
  const queues = createIntentQueues();
  const intents = new Map();
  queues.forEach((queue) => {
    const queued = new Array(queue.size).fill(0).map(() => mock.destinationIntent({ origin: queue.domain }));
    intents.set(queue.domain, queued);
  });

  let sendWithRelayerWithBackupStub: SinonStub;
  let getQueuesStub: SinonStub;
  let getMessageQueueContentsStub: SinonStub;
  let encodeStub: SinonStub;
  let decodeStub: SinonStub;

  beforeEach(() => {
    const config = {
      ...mock.config(),
      chains: {
        ...mock.chains(),
      },
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
    };
    getContextStub.returns({
      ...mock.context(),
      config,
    });
    // Interface stubs
    encodeStub = stub(Interface.prototype, 'encodeFunctionData').returns('0xencoded');
    decodeStub = stub(Interface.prototype, 'decodeFunctionResult').returns([0]);

    // Context stubs
    getQueuesStub = stub().resolves(queues);
    getMessageQueueContentsStub = stub().resolves(intents);
    mock.instances.database().getMessageQueues = getQueuesStub;
    mock.instances.database().getMessageQueueContents = getMessageQueueContentsStub;

    // Logic stubs
    sendWithRelayerWithBackupStub = stub(Relayer, 'sendWithRelayerWithBackup').resolves({
      taskId: '123',
      relayerType: RelayerType.Everclear,
    });
  });

  describe('#processMessageQueue', () => {
    it('should fail if database.getMessageQueues fails', async () => {
      mock.instances.database().getMessageQueues = stub().rejects(new Error('fail'));
      await expect(processMessageQueue('INTENT')).to.be.rejectedWith('fail');
    });

    // it('should fail if Interface.encodeFunctionData fails', async () => {
    //   encodeStub.throws(new Error('fail'));
    //   await expect(processMessageQueue('INTENT')).to.be.fulfilled;
    //   expect(sendWithRelayerWithBackupStub.callCount).to.equal(0);
    // });

    // it('should fail if Interface.decodeFunctionResult fails', async () => {
    //   decodeStub.throws(new Error('fail'));
    //   await expect(processMessageQueue('INTENT')).to.be.fulfilled;
    //   expect(sendWithRelayerWithBackupStub.callCount).to.equal(0);
    // });

    it('should fail if sendWithRelayerWithBackup fails', async () => {
      const error = new Error('fail');
      sendWithRelayerWithBackupStub.rejects(error);
      await expect(processMessageQueue('INTENT')).to.be.fulfilled;
      const [message, , , context] = mock.instances.logger().info.lastCall.args;
      expect(message).to.be.eq('Dispatched queues');
      expect(context).to.containSubset({
        type: 'INTENT',
        attempted: 2,
        successful: 0,
        rejected: 2,
      });
      expect(context.errors.length).to.be.eq(2);
    });

    it('should return early if no intents', async () => {
      getQueuesStub.resolves([]);
      await processMessageQueue('INTENT');
      expect(sendWithRelayerWithBackupStub.callCount).to.equal(0);
    });

    it('should return early if no intents are old enough && queue size is below threshold', async () => {
      const queue = mock.queue({ type: 'INTENT', size: 1, lastProcessed: Math.floor(Date.now() / 1000) });
      getQueuesStub.resolves([queue]);
      await processMessageQueue('INTENT');
      expect(sendWithRelayerWithBackupStub.callCount).to.equal(0);
    });

    it('should throw on missing threshold config', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          thresholds: {
            '1337': {
              maxAge: undefined,
              size: undefined,
            },
            '1338': {
              maxAge: undefined,
              size: undefined,
            },
            '1339': {
              maxAge: undefined,
              size: undefined,
            },
          },
        },
      });
      const queues = [
        mock.queue({ type: 'INTENT', size: 100, lastProcessed: Math.floor(Date.now() / 1000), domain: '1337' }),
        mock.queue({ type: 'INTENT', size: 1, lastProcessed: Math.floor(Date.now() / 1000), domain: '1338' }),
      ];
      const intents: OriginIntent[] = [];
      queues.forEach((queue) => {
        const queued = new Array(queue.size)
          .fill(0)
          .map((_, i) => mock.destinationIntent({ origin: queue.domain, id: mkBytes32(`0x${i}${i}${i}`) }));
        intents.push(...queued);
      });
      getMessageQueueContentsStub.resolves(intents);
      getQueuesStub.resolves(queues);
      await expect(processMessageQueue('INTENT')).to.be.rejectedWith('Missing threshold for domain');
    });

    it('should dispatch if queue size is above threshold', async () => {
      const retrieved = [
        mock.queue({ type: 'INTENT', size: 100, lastProcessed: Math.floor(Date.now() / 1000), domain: '1337' }),
        mock.queue({ type: 'INTENT', size: 1, lastProcessed: Math.floor(Date.now() / 1000), domain: '1338' }),
      ];
      const contents = new Map();
      retrieved.forEach((queue) => {
        contents.set(
          queue.domain,
          new Array(queue.size)
            .fill(0)
            .map((_, i) => mock.originIntent({ origin: queue.domain, id: mkBytes32(`0x${i}${i}${i}`) })),
        );
      });
      getMessageQueueContentsStub.resolves(contents);
      getQueuesStub.resolves(retrieved);
      await processMessageQueue('INTENT');
      expect(sendWithRelayerWithBackupStub.callCount).to.equal(1);
    });

    it('should dispatch if oldest intent is older than threshold', async () => {
      const retrieved = [
        mock.queue({ type: 'INTENT', size: 1, lastProcessed: 0, domain: '1337' }),
        mock.queue({ type: 'INTENT', size: 1, lastProcessed: Math.floor(Date.now() / 1000), domain: '1338' }),
      ];
      const contents = new Map();
      retrieved.forEach((queue) => {
        contents.set(
          queue.domain,
          new Array(queue.size)
            .fill(0)
            .map((_, i) => mock.originIntent({ origin: queue.domain, id: mkBytes32(`0x${i}${i}${i}`) })),
        );
      });
      getMessageQueueContentsStub.resolves(contents);
      getQueuesStub.resolves(retrieved);
      await processMessageQueue('INTENT');
      expect(sendWithRelayerWithBackupStub.callCount).to.equal(1);
    });
  });
});
