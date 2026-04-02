import { SinonStubbedInstance } from 'sinon';

import { updateHubDeposits } from '../../../src/lib/operations';
import { expect, TIntentStatus } from '@chimera-monorepo/utils';
import { mockAppContext } from '../../globalTestHook';
import { createHubDeposits } from '@chimera-monorepo/database/test/mock';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { Database } from '@chimera-monorepo/database';
import { CartographerConfig } from '../../../src/config';

describe('Invoice operations', () => {
  describe('#updateHubDeposits', () => {
    let reader: SinonStubbedInstance<SubgraphReader>;
    let database: SinonStubbedInstance<Database>;
    let config: CartographerConfig;

    const enqueued = createHubDeposits(5).map((e) => ({ ...e, status: TIntentStatus.Added }));
    const processed = createHubDeposits(
      5,
      enqueued.map((e) => ({
        ...e,
        processedTimestamp: Math.floor(Date.now() / 1000) * 1.5,
        processedTxNonce: Date.now(),
      })),
    ).map((e) => ({ ...e, status: TIntentStatus.DepositProcessed }));

    beforeEach(() => {
      reader = mockAppContext.adapters.subgraph as SinonStubbedInstance<SubgraphReader>;
      database = mockAppContext.adapters.database as SinonStubbedInstance<Database>;
      config = mockAppContext.config;

      reader.getLatestBlockNumber.resolves(new Map([[config.hub.domain, 100_00]]));
      (reader.getDepositsEnqueuedByNonceWithCheckpoints as any).resolves([enqueued, { goldsky: 1 }]);
      (reader.getDepositsProcessedByNonceWithCheckpoints as any).resolves([[], {}]);

      database.getCheckPoint.resolves(0);
      database.saveHubDeposits.resolves();
      database.saveCheckPoint.resolves();
    });

    it('should exit early if cannot get latest block number from hub subgraph', async () => {
      reader.getLatestBlockNumber.resolves(new Map());
      await updateHubDeposits(mockAppContext);
      expect(database.saveHubDeposits.callCount).to.be.eq(0);
    });

    it('should work', async () => {
      await updateHubDeposits(mockAppContext);

      expect(database.saveHubDeposits).callCount(1);
      // saveReaderCheckpoints: 1 for enqueued (has results), 0 for processed (empty)
      expect(database.saveCheckPoint.callCount).to.be.eq(1);
      expect(database.saveHubIntents).calledOnceWith(
        enqueued.map((e) => ({ status: e.status, domain: config.hub.domain, id: e.intentId })),
        ['status'],
      );
    });

    it('should work with processed deposits', async () => {
      (reader.getDepositsProcessedByNonceWithCheckpoints as any).resolves([processed, { goldsky: 1 }]);
      await updateHubDeposits(mockAppContext);

      expect(database.saveHubDeposits).callCount(1);
      // saveReaderCheckpoints: 1 for enqueued + 1 for processed
      expect(database.saveCheckPoint.callCount).to.be.eq(2);
      expect(database.saveHubIntents).calledOnceWith(
        processed.map((e) => ({ status: e.status, domain: config.hub.domain, id: e.intentId })),
        ['status'],
      );
    });
  });
});
