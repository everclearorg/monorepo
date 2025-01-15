import { SinonStub } from 'sinon';

import { updateAssets, updateDepositors } from '../../../src/lib/operations';
import { expect } from '@chimera-monorepo/utils';
import { mockAppContext } from '../../globalTestHook';
import { createAssets, createDepositEvents, createTokens } from '@chimera-monorepo/database/test/mock';

describe('Depositors operations', () => {
  describe('#updateDepositors', () => {
    it('should work', async () => {
      const domains = Object.keys(mockAppContext.config.chains);
      const depositEvents = createDepositEvents(5);
      (mockAppContext.adapters.subgraph.getDepositorEvents as SinonStub).resolves(depositEvents);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);
      await updateDepositors();
      expect(mockAppContext.adapters.database.saveDepositors as SinonStub).callCount(1);
      expect(mockAppContext.adapters.database.saveBalances as SinonStub).callCount(1);
      expect(mockAppContext.adapters.database.getCheckPoint as SinonStub).callCount(domains.length);
      expect(mockAppContext.adapters.database.saveCheckPoint as SinonStub).callCount(
        Object.keys(mockAppContext.config.chains).length,
      );
    });
  });

  describe('#updateAssets', () => {
    it('should work', async () => {
      const assets = createAssets(5);
      const tokens = createTokens(2);
      (mockAppContext.adapters.subgraph.getTokens as SinonStub).resolves([tokens, assets]);
      (mockAppContext.adapters.database.getCheckPoint as SinonStub).resolves(0);

      await updateAssets();

      expect(mockAppContext.adapters.database.saveAssets as SinonStub).callCount(1);
      expect(mockAppContext.adapters.database.saveTokens as SinonStub).callCount(1);

      expect(mockAppContext.adapters.database.saveAssets as SinonStub).to.be.calledWithExactly(assets);
      expect(mockAppContext.adapters.database.saveTokens as SinonStub).to.be.calledWithExactly(tokens);
    });
  });
});
