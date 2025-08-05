import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkTronPipelineStatus } from '../../src/checklist/tron-pipeline';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../src/mockable';

describe('Tron Pipeline Status Checklist', () => {
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let database: SinonStubbedInstance<Database>;
  let getTronLastIntentNonceStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    
    sendAlertsStub = stub(Mockable, 'sendAlerts').resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts').resolves();
    
    // Mock the getTronLastIntentNonce function by replacing the import
    const TronHelpers = require('../../src/helpers/tron');
    getTronLastIntentNonceStub = stub(TronHelpers, 'getTronLastIntentNonce').resolves(100);
    
    // Mock database responses
    database.getOriginIntentsLastNonce.resolves(100);
    database.getCheckPoint.resolves(100);
    database.saveCheckPoint.resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronPipelineStatus', () => {
    it('should return early when chain nonce matches saved nonce', async () => {
      getTronLastIntentNonceStub.resolves(100);
      database.getCheckPoint.resolves(100);
      database.getOriginIntentsLastNonce.resolves(100);
      
      await checkTronPipelineStatus();
      
      // Should return early and not send alerts
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.false;
      expect(logger.debug.called).to.be.true;
    });

    it('should save checkpoint when local nonce differs from saved nonce', async () => {
      getTronLastIntentNonceStub.resolves(102); // Different from saved
      database.getCheckPoint.resolves(100); // Saved nonce
      database.getOriginIntentsLastNonce.resolves(101); // Local nonce
      
      await checkTronPipelineStatus();
      
      expect(database.saveCheckPoint.calledWith('tron_intent_nonce', 101)).to.be.true;
    });

    it('should not save checkpoint when local nonce equals saved nonce', async () => {
      getTronLastIntentNonceStub.resolves(102); // Different from saved
      database.getCheckPoint.resolves(100); // Saved nonce
      database.getOriginIntentsLastNonce.resolves(100); // Same as saved nonce
      
      await checkTronPipelineStatus();
      
      expect(database.saveCheckPoint.called).to.be.false;
    });

    it('should send alerts when chain nonce differs from local nonce', async () => {
      getTronLastIntentNonceStub.resolves(102); // Chain nonce
      database.getCheckPoint.resolves(100); // Saved nonce
      database.getOriginIntentsLastNonce.resolves(101); // Local nonce (different from chain)
      
      await checkTronPipelineStatus(true); // shouldAlert = true
      
      expect(sendAlertsStub.called).to.be.true;
      expect(logger.warn.called).to.be.true;
    });

    it('should resolve alerts when chain nonce equals local nonce', async () => {
      getTronLastIntentNonceStub.resolves(101); // Chain nonce
      database.getCheckPoint.resolves(100); // Saved nonce (different)
      database.getOriginIntentsLastNonce.resolves(101); // Local nonce (same as chain)
      
      await checkTronPipelineStatus(true); // shouldAlert = true
      
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should not send alerts when shouldAlert is false', async () => {
      getTronLastIntentNonceStub.resolves(102); // Chain nonce
      database.getCheckPoint.resolves(100); // Saved nonce
      database.getOriginIntentsLastNonce.resolves(101); // Local nonce (different)
      
      await checkTronPipelineStatus(false); // shouldAlert = false
      
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should handle database errors gracefully', async () => {
      database.getOriginIntentsLastNonce.rejects(new Error('Database error'));
      
      try {
        await checkTronPipelineStatus();
        expect.fail('Should have thrown an error');
      } catch (error: any) {
        expect(error.message).to.eq('Database error');
      }
    });

    it('should handle getTronLastIntentNonce errors gracefully', async () => {
      getTronLastIntentNonceStub.rejects(new Error('Nonce error'));
      
      try {
        await checkTronPipelineStatus();
        expect.fail('Should have thrown an error');
      } catch (error: any) {
        expect(error.message).to.eq('Nonce error');
      }
    });

    it('should handle different nonce scenarios for branch coverage', async () => {
      // Test various nonce combinations to hit different branches
      const scenarios = [
        { chain: 100, saved: 100, local: 100 }, // All same
        { chain: 101, saved: 100, local: 100 }, // Chain differs
        { chain: 100, saved: 99, local: 100 },  // Saved differs
        { chain: 102, saved: 100, local: 101 }, // All different
      ];

      for (const scenario of scenarios) {
        getTronLastIntentNonceStub.resolves(scenario.chain);
        database.getCheckPoint.resolves(scenario.saved);
        database.getOriginIntentsLastNonce.resolves(scenario.local);
        
        await checkTronPipelineStatus();
        // Each scenario should complete without errors
      }
    });
  });
});