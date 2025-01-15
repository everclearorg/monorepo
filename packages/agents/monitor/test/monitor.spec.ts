import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance, SinonStub, useFakeTimers } from 'sinon';
import { getContextStub, mock } from './globalTestHook';
import { MonitorService, bindConfig, makeMonitor, getSubgraphReaderConfig } from '../src/monitor';
import { createProcessEnv } from './mock';
import * as mockFunctions from '../src/config';
import * as setupFunctions from '../src/setup';
import * as checkFunctions from '../src/checklist/index';
import * as bindings from '../src/bindings/index';

import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';

describe('Monitor', () => {
  let subgraph: SinonStubbedInstance<SubgraphReader>;
  let logger: SinonStubbedInstance<Logger>;
  let getConfigStub: SinonStub;
  let runChecksStub: SinonStub;
  let bindServerStub: SinonStub;
  let shouldReloadEverclearConfigStub: SinonStub;
  let setupSubgraphReaderStub: SinonStub;
  let clock: sinon.SinonFakeTimers;
  let exitStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    subgraph = mock.instances.subgraph() as SinonStubbedInstance<SubgraphReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    subgraph.getDestinationIntentById.resolves(mock.destinationIntent());
    getConfigStub = stub(mockFunctions, 'getConfig').resolves(mock.config());
    runChecksStub = stub(checkFunctions, 'runChecks').resolves();
    shouldReloadEverclearConfigStub = stub(mockFunctions, 'shouldReloadEverclearConfig');
    shouldReloadEverclearConfigStub.resolves({ reloadConfig: false, reloadSubgraph: false });
    setupSubgraphReaderStub = stub(setupFunctions, 'setupSubgraphReader');
    exitStub = stub(process, 'exit');
    bindServerStub = stub(bindings, 'bindServer');
    bindServerStub.resolves();

    setupSubgraphReaderStub.resolves(subgraph);
    exitStub.returns(1);

    clock = useFakeTimers({
      shouldClearNativeTimers: true,
    });
  });
  
  afterEach(() => {
    restore();
    reset();
  });

  describe('#makeMonitor', () => {
    it('should work for monitor server', async () => {
      expect(makeMonitor(MonitorService.SERVER)).to.not.throw;
    });

    it('should work for monitor poller', async () => {
      expect(makeMonitor(MonitorService.POLLER)).to.not.throw;
    });

    it('should fail with bad config', async () => {
      getConfigStub.resolves({});

      expect(makeMonitor(MonitorService.SERVER)).to.be.returned;
      expect(exitStub.calledWith(1));
    });
  });

  describe('#bindConfig', () => {
    it('should work', async () => {
      expect(bindConfig()).to.not.throw;
    });
    it('should handle execption', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: { ...mock.config() },
      });
      shouldReloadEverclearConfigStub.resolves(undefined);

      await bindConfig();
      clock.tick(10000);

      expect(bindConfig()).to.not.be.rejected;
    });
    it('should update config if reloadConfig is true', async () => {
      getConfigStub.resolves({ polling: { config: 100 } });
      shouldReloadEverclearConfigStub.resolves({ reloadConfig: true, reloadSubgraph: false });

      await bindConfig();
      clock.tick(10000);
      expect(getConfigStub.callCount).to.equal(1);
    });

    it('should update subgraph if reloadSubgraph is true', async () => {
      // getConfigStub.resolves({ polling: { config: 100 } });
      getContextStub.returns({
        ...mock.context(),
        config: { ...mock.config() },
      });
      shouldReloadEverclearConfigStub.resolves({ reloadConfig: false, reloadSubgraph: true });

      await bindConfig();
      clock.tick(10000);

      expect(bindConfig()).to.not.be.rejected;
    });
  });

  describe('#getSubgraphReaderConfig', () => {
    it('should work', async () => {
      const config = mock.config();
      const result = getSubgraphReaderConfig(config.chains);

      expect(Object.keys(result.subgraphs).length).to.equal(2);
    });
  });
});
