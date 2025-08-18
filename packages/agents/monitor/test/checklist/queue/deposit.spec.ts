import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkDepositQueueCount, checkDepositQueueLatency } from '../../../src/checklist/queue/deposit';
import { getContextStub, mock } from '../../globalTestHook';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { createProcessEnv } from '../../mock';
import { Database } from '@chimera-monorepo/database';
import { mkHash } from '@chimera-monorepo/utils';
import * as Mockable from '../../../src/mockable';

describe('checkDepositQueueState', () => {
  let chainreader: SinonStubbedInstance<ChainReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let database: SinonStubbedInstance<Database>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    const enqueuedDeposit = mock.depositQueue();
    database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
    sendAlertsStub = stub(Mockable, 'sendAlerts');
    resolveAlertsStub = stub(Mockable, 'resolveAlerts').resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkDepositQueueCount', () => {
    it('should work', async () => {
      const epoch = 100;
      const domain = '1337';
      const tickerHash = mkHash('0x1234');
      const enqueuedDeposit = mock.depositQueue({ epoch, domain, tickerHash });
      database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
      const result = await checkDepositQueueCount();
      const validResult = new Map([[`100-1337-${tickerHash}`, 1]]);
      expect(result).to.deep.equal(validResult);
    });
    it('should work with no data in db', async () => {
      database.getAllEnqueuedDeposits.resolves([]);
      const result = await checkDepositQueueCount();
      const validEmptyResult = new Map();
      expect(result).to.deep.equal(validEmptyResult);
    });

    it('should send alert', async () => {
      await checkDepositQueueCount();
      expect(sendAlertsStub.callCount).to.eq(1);
    });
  });

  describe('#checkDepositQueueLatency', () => {
    it('should work with no pending deposits', async () => {
      database.getAllEnqueuedDeposits.resolves([]);
      const result = await checkDepositQueueLatency();
      expect(result.size).to.eq(0);
    });

    it('should work with pending deposits', async () => {
      sendAlertsStub.resolves();
      const epoch = 100;
      const domain = '1337';
      const tickerHash = mkHash('0x1234');
      const enqueuedDeposit = mock.depositQueue({ epoch, domain, tickerHash, enqueuedTimestamp: 1 });
      database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
      await checkDepositQueueLatency();
      expect(sendAlertsStub.callCount).to.eq(1);
    });

    it('should fail', async () => {
      expect(checkDepositQueueLatency()).to.be.rejected;
    });

    it('should handle multiple deposits with same key', async () => {
      const epoch = 100;
      const domain = '1337';
      const tickerHash = mkHash('0x1234');
      const deposit1 = mock.depositQueue({ epoch, domain, tickerHash, enqueuedTimestamp: 100 });
      const deposit2 = mock.depositQueue({ epoch, domain, tickerHash, enqueuedTimestamp: 50 });
      const deposit3 = mock.depositQueue({ epoch, domain, tickerHash, enqueuedTimestamp: 150 });
      
      database.getAllEnqueuedDeposits.resolves([deposit1, deposit2, deposit3]);
      
      const result = await checkDepositQueueLatency();
      // Should use the oldest timestamp (50)
      expect(result.get(`${domain}-${tickerHash}`)).to.eq(50);
    });

    it('should not send alert if latency is within threshold', async () => {
      const config = mock.config();
      config.thresholds.maxDepositQueueLatency = 3600; // Set threshold to 1 hour
      
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const epoch = 100;
      const domain = '1337';
      const tickerHash = mkHash('0x1234');
      const currentTime = Math.floor(Date.now() / 1000);
      // Set timestamp to be within threshold (100 seconds ago, well under 3600 seconds)
      const enqueuedDeposit = mock.depositQueue({ 
        epoch, 
        domain, 
        tickerHash, 
        enqueuedTimestamp: currentTime - 100
      });
      
      database.getAllEnqueuedDeposits.resolves([enqueuedDeposit]);
      
      await checkDepositQueueLatency();
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.true;
    });

    it('should handle deposits across different domains and ticker hashes', async () => {
      const epoch = 100;
      const deposits = [
        mock.depositQueue({ epoch, domain: '1337', tickerHash: mkHash('0x1234'), enqueuedTimestamp: 100 }),
        mock.depositQueue({ epoch, domain: '1338', tickerHash: mkHash('0x1234'), enqueuedTimestamp: 200 }),
        mock.depositQueue({ epoch, domain: '1337', tickerHash: mkHash('0x5678'), enqueuedTimestamp: 150 }),
      ];
      
      database.getAllEnqueuedDeposits.resolves(deposits);
      
      const result = await checkDepositQueueLatency();
      expect(result.size).to.eq(3);
      expect(result.get('1337-' + mkHash('0x1234'))).to.eq(100);
      expect(result.get('1338-' + mkHash('0x1234'))).to.eq(200);
      expect(result.get('1337-' + mkHash('0x5678'))).to.eq(150);
    });
  });

  describe('#checkDepositQueueCount', () => {
    it('should handle multiple deposits increasing count', async () => {
      const epoch = 100;
      const domain = '1337';
      const tickerHash = mkHash('0x1234');
      const deposits = [
        mock.depositQueue({ epoch, domain, tickerHash }),
        mock.depositQueue({ epoch, domain, tickerHash }),
        mock.depositQueue({ epoch, domain, tickerHash }),
      ];
      
      database.getAllEnqueuedDeposits.resolves(deposits);
      
      const result = await checkDepositQueueCount();
      expect(result.get(`${epoch}-${domain}-${tickerHash}`)).to.eq(3);
    });

    it('should not send alert when below threshold', async () => {
      const config = mock.config();
      config.thresholds.maxDepositQueueCount = 10; // Set high threshold
      
      getContextStub.returns({
        ...mock.context(),
        config,
      });
      
      const epoch = 100;
      const domain = '1337';
      const tickerHash = mkHash('0x1234');
      const deposits = [
        mock.depositQueue({ epoch, domain, tickerHash }),
        mock.depositQueue({ epoch, domain, tickerHash }),
      ];
      
      database.getAllEnqueuedDeposits.resolves(deposits);
      
      await checkDepositQueueCount();
      expect(sendAlertsStub.called).to.be.false;
    });
  });
});
