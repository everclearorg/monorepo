import { RelayerTaskStatus, expect, mkAddress } from '@chimera-monorepo/utils';
import { CachedTaskData, TasksCache } from '../../../src';

const createTasks = (num: number, overrides: Partial<CachedTaskData>[] = []): CachedTaskData[] => {
  return new Array(num).fill(0).map((_, i) => ({
    chain: 1337,
    to: mkAddress(),
    data: '0x',
    fee: {
      chain: 1338,
      amount: '100',
      token: mkAddress('0x1'),
    },
    ...(overrides[i] || {}),
  }));
};

describe('TasksCache', () => {
  let cache: TasksCache;

  beforeEach(() => {
    cache = new TasksCache({ host: 'mock', port: 1234, mock: true });
  });

  describe('#createTask / #getTask', () => {
    it('should work', async () => {
      expect(await cache.getTask('0x123')).to.be.undefined;
      const [task] = createTasks(1);
      const id = await cache.createTask(task);
      expect(await cache.getTask(id)).to.be.deep.eq(task);
    });
  });

  describe('#removePending / #getPending', () => {
    it('should work', async () => {
      const [task] = createTasks(1);
      const id = await cache.createTask(task);
      const pending = await cache.getPending(0, 10);
      expect(pending.findIndex((i) => i.toLowerCase() === id.toLowerCase())).to.be.gt(0);
      await cache.removePending([id]);
      expect(await cache.getTask(id)).to.be.undefined;
    });
  });

  describe('#setStatus / #getStatus', () => {
    it('should work', async () => {
      expect(await cache.getStatus('1')).to.be.eq(RelayerTaskStatus.NotFound);
      const [task] = createTasks(1);
      const id = await cache.createTask(task);
      expect(await cache.getStatus(id)).to.be.eq(RelayerTaskStatus.ExecPending);
      await cache.setStatus(id, RelayerTaskStatus.ExecSuccess);
      expect(await cache.getStatus(id)).to.be.eq(RelayerTaskStatus.ExecSuccess);
    });
  });

  describe('#setError / #getError', () => {
    it('should work', async () => {
      expect(await cache.getError('1')).to.be.undefined;
      const [task] = createTasks(1);
      const id = await cache.createTask(task);
      expect(await cache.getError(id)).to.be.undefined;
      await cache.setError(id, 'error');
      expect(await cache.getError(id)).to.be.eq('error');
    });
  });

  describe('#setHash / #getHash', () => {
    it('should work', async () => {
      expect(await cache.getHash('1')).to.be.undefined;
      const [task] = createTasks(1);
      const id = await cache.createTask(task);
      expect(await cache.getHash(id)).to.be.undefined;
      await cache.setHash(id, '0x123');
      expect(await cache.getHash(id)).to.be.eq('0x123');
    });
  });
});
