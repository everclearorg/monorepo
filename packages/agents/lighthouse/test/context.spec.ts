import { RelayerType, expect } from '@chimera-monorepo/utils';
import { SinonStubbedInstance, stub } from 'sinon';

import { mock } from './globalTestHook';
import { getContext, makeLighthouseTask } from '../src/context';
import { Database } from '@chimera-monorepo/database';

describe('Lighthouse Context', () => {
  const config = mock.config();
  const task = stub().resolves();
  let database: SinonStubbedInstance<Database>;

  beforeEach(() => {
    database = mock.instances.database() as SinonStubbedInstance<Database>;
  });

  describe('#makeLighthouseTask', () => {
    it('should work', async () => {
      await expect(makeLighthouseTask(task, config)).to.be.fulfilled;
      expect(task.calledOnce).to.be.true;
    });

    it('should log error if process logic fails', async () => {
      const failing = stub().rejects(new Error('fail'));
      await expect(makeLighthouseTask(failing, config)).to.be.fulfilled;
      expect(failing.calledOnce).to.be.true;
      expect(mock.instances.logger().error.calledOnce).to.be.true;
    });

    it('should ignore gelato relayers', async () => {
      const withRelayers = mock.config({
        relayers: [
          {
            type: RelayerType.Gelato,
            apiKey: 'gelato',
            url: 'https://gelato.com',
          },
        ],
      });

      await expect(makeLighthouseTask(task, withRelayers)).to.be.fulfilled;
      const context = getContext();
      expect(context.adapters.relayers.filter((r) => r.type === RelayerType.Gelato)).to.be.deep.eq([]);
    });

    it('should throw if no relayer setup function', async () => {
      const withRelayers = mock.config({
        relayers: [
          {
            type: 'test' as any,
            apiKey: 'everclear',
            url: 'https://everclear.com',
          },
        ],
      });

      await expect(makeLighthouseTask(task, withRelayers)).to.be.fulfilled;
      expect(task.calledOnce).to.be.false;
      expect(mock.instances.logger().error.calledOnce).to.be.true;
    });
  });

  describe('#getContext', () => {
    it('should return context before set', () => {
      const context = getContext();
      expect(context).to.be.ok;
    });

    it('should return context after being set', async () => {
      await makeLighthouseTask(task, config);
      const context = getContext();
      expect(context).to.be.ok;
      expect(context.config).to.be.deep.eq(config);
    });
  });
});
