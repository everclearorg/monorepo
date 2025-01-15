import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance } from 'sinon';
import { checkGas } from '../../src/checklist/gas';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import { Database } from '@chimera-monorepo/database';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';

describe('checkGas', () => {
  let database: SinonStubbedInstance<Database>;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let subgraph: SinonStubbedInstance<SubgraphReader>;
  let logger: SinonStubbedInstance<Logger>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    subgraph = mock.instances.subgraph() as SinonStubbedInstance<SubgraphReader>;

    chainreader.getBlockNumber.resolves(1);
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkGas', () => {
    it('should work', async () => {
      chainreader.getBalance.resolves('100');
      expect(checkGas()).to.not.throw;
    });
    it('should work with the default block number', async () => {
      chainreader.getBalance.throws(new Error('Error fetching balance'));
      expect(checkGas()).to.throw;
    });
  });
});
