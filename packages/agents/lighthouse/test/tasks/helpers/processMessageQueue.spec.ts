import { OriginIntent, RelayerType, RelayerTaskStatus, expect, mkBytes32, chainWrapper } from '@chimera-monorepo/utils';
import { SinonStub, SinonFakeTimers, stub, useFakeTimers } from 'sinon';
import { getContextStub, mock, createIntentQueues } from '../../globalTestHook';
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
    encodeStub = stub(chainWrapper, 'encodeFunctionData').returns('0xencoded');
    decodeStub = stub(chainWrapper, 'decodeFunctionResult').returns(BigInt(0));

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

    it('should skip dispatch when claimQueueDispatch returns null (already claimed)', async () => {
      const retrieved = [
        mock.queue({ type: 'INTENT', size: 100, lastProcessed: Math.floor(Date.now() / 1000), domain: '1337' }),
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

      // Simulate claim failure (another worker already claimed)
      (mock.instances.database().claimQueueDispatch as SinonStub).resolves(null);

      await processMessageQueue('INTENT');

      // The relayer should NOT have been called because claim failed
      expect(sendWithRelayerWithBackupStub.callCount).to.equal(0);
      const claimStub = mock.instances.database().claimQueueDispatch as SinonStub;
      expect(claimStub.callCount).to.equal(1);
      expect(claimStub.firstCall.args[0]).to.equal('1337'); // domain
      expect(claimStub.firstCall.args[1]).to.equal('INTENT'); // queueType
    });

    it('should promote claim with correct relayer task after successful dispatch', async () => {
      const retrieved = [
        mock.queue({ type: 'INTENT', size: 100, lastProcessed: Math.floor(Date.now() / 1000), domain: '1337' }),
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

      // Verify claim was acquired
      const claimStub = mock.instances.database().claimQueueDispatch as SinonStub;
      expect(claimStub.callCount).to.equal(1);

      // Verify relayer was called
      expect(sendWithRelayerWithBackupStub.callCount).to.equal(1);

      // Verify promoteQueueDispatchClaim was called with the correct arguments
      const promoteStub = mock.instances.database().promoteQueueDispatchClaim as SinonStub;
      expect(promoteStub.callCount).to.equal(1);
      expect(promoteStub.firstCall.args[0]).to.equal('claim:test'); // claimToken
      expect(promoteStub.firstCall.args[1]).to.equal('123'); // taskId from sendWithRelayerWithBackup
      expect(promoteStub.firstCall.args[2]).to.equal(RelayerType.Everclear); // relayerType
    });

    it('should not fail when promoteQueueDispatchClaim throws', async () => {
      const retrieved = [
        mock.queue({ type: 'INTENT', size: 100, lastProcessed: Math.floor(Date.now() / 1000), domain: '1337' }),
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

      (mock.instances.database().promoteQueueDispatchClaim as SinonStub).rejects(new Error('db write failed'));

      // Should not reject — the error is caught and logged
      await expect(processMessageQueue('INTENT')).to.be.fulfilled;
      expect(sendWithRelayerWithBackupStub.callCount).to.equal(1);
    });

    it('should release claim when relayer dispatch fails', async () => {
      const retrieved = [
        mock.queue({ type: 'INTENT', size: 100, lastProcessed: Math.floor(Date.now() / 1000), domain: '1337' }),
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

      sendWithRelayerWithBackupStub.rejects(new Error('relayer failed'));

      await expect(processMessageQueue('INTENT')).to.be.fulfilled;

      // Verify claim was released
      const releaseStub = mock.instances.database().releaseQueueDispatchClaim as SinonStub;
      expect(releaseStub.callCount).to.equal(1);
      expect(releaseStub.firstCall.args[0]).to.equal('claim:test');
    });

    it('should handle releaseQueueDispatchClaim failure gracefully', async () => {
      const retrieved = [
        mock.queue({ type: 'INTENT', size: 100, lastProcessed: Math.floor(Date.now() / 1000), domain: '1337' }),
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

      sendWithRelayerWithBackupStub.rejects(new Error('relayer failed'));
      (mock.instances.database().releaseQueueDispatchClaim as SinonStub).rejects(new Error('release failed'));

      // Should not reject — both errors are caught
      await expect(processMessageQueue('INTENT')).to.be.fulfilled;
    });
  });

  describe('#reconcileQueueDispatches', () => {
    // The module-level lastReconcileTimestamp persists across tests and throttles
    // reconciliation to once per 60s. We use a monotonically increasing base time
    // so each test's Date.now() is always well past the previous lastReconcileTimestamp.
    let clock: SinonFakeTimers;
    let reconcileTimeBase = Date.now() + 10_000_000;

    beforeEach(() => {
      reconcileTimeBase += 200_000; // each test starts 200s past the previous
      clock = useFakeTimers({ now: reconcileTimeBase, shouldAdvanceTime: false });
    });

    afterEach(() => {
      clock.restore();
    });

    function setupReconcileContext(getTaskStatusFn: SinonStub) {
      const ctx = mock.context();
      ctx.adapters.relayers[0].instance.getTaskStatus = getTaskStatusFn;
      getContextStub.returns({
        ...ctx,
        config: {
          ...mock.config(),
          chains: { ...mock.chains() },
          thresholds: {
            '1337': { maxAge: 10, size: 2 },
            '1338': { maxAge: 10, size: 2 },
            '1339': { maxAge: 10, size: 2 },
          },
        },
      });
      // Override database stubs on the context's database adapter directly
      ctx.adapters.database = mock.instances.database() as any;
    }

    it('should update terminal statuses when relayer reports success', async () => {

      const pendingDispatches = [
        { taskId: 'task-1', relayerType: RelayerType.Everclear, domain: '1337', queueType: 'INTENT' },
      ];
      (mock.instances.database().getAllPendingQueueDispatches as SinonStub).resolves(pendingDispatches);

      setupReconcileContext(stub().resolves(RelayerTaskStatus.ExecSuccess));
      getQueuesStub.resolves([]);

      await processMessageQueue('INTENT');

      const updateStub = mock.instances.database().updatePendingQueueDispatchStatus as SinonStub;
      expect(updateStub.callCount).to.equal(1);
      expect(updateStub.firstCall.args[0]).to.equal('task-1');
      expect(updateStub.firstCall.args[1]).to.equal('success');
    });

    it('should mark reverted tasks as reverted', async () => {

      const pendingDispatches = [
        { taskId: 'task-reverted', relayerType: RelayerType.Everclear, domain: '1337', queueType: 'INTENT' },
      ];
      (mock.instances.database().getAllPendingQueueDispatches as SinonStub).resolves(pendingDispatches);

      setupReconcileContext(stub().resolves(RelayerTaskStatus.ExecReverted));
      getQueuesStub.resolves([]);

      await processMessageQueue('INTENT');

      const updateStub = mock.instances.database().updatePendingQueueDispatchStatus as SinonStub;
      expect(updateStub.callCount).to.equal(1);
      expect(updateStub.firstCall.args[1]).to.equal('reverted');
    });

    it('should mark cancelled/blacklisted/not-found tasks as cancelled', async () => {

      const pendingDispatches = [
        { taskId: 'task-cancelled', relayerType: RelayerType.Everclear, domain: '1337', queueType: 'INTENT' },
        { taskId: 'task-blacklisted', relayerType: RelayerType.Everclear, domain: '1337', queueType: 'INTENT' },
        { taskId: 'task-notfound', relayerType: RelayerType.Everclear, domain: '1337', queueType: 'INTENT' },
      ];
      (mock.instances.database().getAllPendingQueueDispatches as SinonStub).resolves(pendingDispatches);

      const getTaskStatusStub = stub();
      getTaskStatusStub.onFirstCall().resolves(RelayerTaskStatus.Cancelled);
      getTaskStatusStub.onSecondCall().resolves(RelayerTaskStatus.Blacklisted);
      getTaskStatusStub.onThirdCall().resolves(RelayerTaskStatus.NotFound);
      setupReconcileContext(getTaskStatusStub);
      getQueuesStub.resolves([]);

      await processMessageQueue('INTENT');

      const updateStub = mock.instances.database().updatePendingQueueDispatchStatus as SinonStub;
      expect(updateStub.callCount).to.equal(3);
      expect(updateStub.getCall(0).args[1]).to.equal('cancelled');
      expect(updateStub.getCall(1).args[1]).to.equal('cancelled');
      expect(updateStub.getCall(2).args[1]).to.equal('cancelled');
    });

    it('should not update status for still-pending relayer tasks', async () => {

      const pendingDispatches = [
        { taskId: 'task-pending', relayerType: RelayerType.Everclear, domain: '1337', queueType: 'INTENT' },
      ];
      (mock.instances.database().getAllPendingQueueDispatches as SinonStub).resolves(pendingDispatches);

      setupReconcileContext(stub().resolves(RelayerTaskStatus.ExecPending));
      getQueuesStub.resolves([]);

      await processMessageQueue('INTENT');

      const updateStub = mock.instances.database().updatePendingQueueDispatchStatus as SinonStub;
      expect(updateStub.callCount).to.equal(0);
    });

    it('should call pruneOldQueueDispatches after reconciliation', async () => {

      // Need at least one pending dispatch to get past the early-return guard
      (mock.instances.database().getAllPendingQueueDispatches as SinonStub).resolves([
        { taskId: 'task-prune', relayerType: RelayerType.Everclear, domain: '1337', queueType: 'INTENT' },
      ]);
      setupReconcileContext(stub().resolves(RelayerTaskStatus.ExecPending));
      getQueuesStub.resolves([]);

      await processMessageQueue('INTENT');

      const pruneStub = mock.instances.database().pruneOldQueueDispatches as SinonStub;
      expect(pruneStub.callCount).to.equal(1);
      expect(pruneStub.firstCall.args[0]).to.equal(7); // DISPATCH_RETENTION_DAYS
    });
  });
});
