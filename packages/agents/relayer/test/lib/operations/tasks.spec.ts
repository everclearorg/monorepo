import { SinonStubbedInstance } from 'sinon';
import {
  RelayerApiPostTaskRequestParams,
  createRequestContext,
  expect,
  mkAddress,
  mkBytes32,
} from '@chimera-monorepo/utils';
import { TasksCache } from '@chimera-monorepo/adapters-cache';
import { createTask as mockTask } from '../../mock';
import { mockAppContext } from '../../globalTestHook';
import { createTask } from '../../../src/lib/operations/tasks';
import { ParamsInvalid, UnsupportedFeeToken, ChainNotSupported } from '../../../src/lib/errors/tasks';

describe('Relayer:Tasks', () => {
  describe('#createTask', () => {
    let cache: { tasks: SinonStubbedInstance<TasksCache> };

    const task = mockTask();
    const id = mkBytes32('0x1234');

    const params: RelayerApiPostTaskRequestParams = {
      ...task,
      apiKey: 'foobar',
    };

    const requestContext = createRequestContext('createTask:test');

    beforeEach(() => {
      cache = mockAppContext.adapters.cache as unknown as { tasks: SinonStubbedInstance<TasksCache> };

      cache.tasks.createTask.resolves(id);
    });

    it('should fail if input is invalid', async () => {
      await expect(createTask(task.chain, { ...params, apiKey: 1 } as any, requestContext)).to.be.rejectedWith(
        ParamsInvalid,
      );
    });

    it('should fail if unsupported fee token', async () => {
      await expect(
        createTask(task.chain, { ...params, fee: { ...params.fee, token: mkAddress('0x1') } }, requestContext),
      ).to.be.rejectedWith(UnsupportedFeeToken);
    });

    it('should fail if unsupported chain', async () => {
      await expect(createTask(123, params, requestContext)).to.be.rejectedWith(ChainNotSupported);
    });

    it('should fail if task creation fails', async () => {
      cache.tasks.createTask.rejects(new Error('fail'));
      await expect(createTask(task.chain, params, requestContext)).to.be.rejectedWith('fail');
    });

    it('should work', async () => {
      const ret = await createTask(task.chain, params, requestContext);
      expect(ret).to.be.eq(id);
      expect(
        cache.tasks.createTask.calledOnceWithExactly({
          chain: task.chain,
          to: task.to,
          data: task.data,
          fee: task.fee,
        }),
      ).to.be.true;
    });
  });
});
