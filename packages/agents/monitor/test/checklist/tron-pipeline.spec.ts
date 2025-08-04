import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance, SinonStub } from 'sinon';
import { checkTronPipelineStatus } from '../../src/checklist/tron-pipeline';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../src/mockable';
import * as tronHelpers from '../../src/helpers/tron';

describe('Tron Pipeline Monitoring', () => {
  let database: SinonStubbedInstance<Database>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let getTronLastIntentNonceStub: SinonStub;

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
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();
    
    getTronLastIntentNonceStub = stub(tronHelpers, 'getTronLastIntentNonce');
    getTronLastIntentNonceStub.resolves(100); // Chain nonce

    // Setup database mocks
    database.getOriginIntentsLastNonce.resolves(100); // Local nonce
    database.getCheckPoint.resolves(95); // Last saved nonce
    database.saveCheckPoint.resolves();
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronPipelineStatus', () => {
    it('should check Tron pipeline status successfully when in sync', async () => {
      await checkTronPipelineStatus();

      // Should get chain and local nonces
      expect(getTronLastIntentNonceStub.called).to.be.true;
      expect(database.getOriginIntentsLastNonce.calledWith(728126428)).to.be.true;
      
      // Should save new checkpoint when local nonce differs from saved
      expect(database.saveCheckPoint.calledWith('tron_intent_nonce', 100)).to.be.true;
      
      // Should resolve alerts when chain and local nonces match
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should alert when chain and local nonces mismatch', async () => {
      database.getOriginIntentsLastNonce.resolves(95); // Local behind chain
      
      await checkTronPipelineStatus();
      
      // Should send alert for pipeline delay
      expect(sendAlertsStub.called).to.be.true;
      const alert = sendAlertsStub.firstCall.args[0];
      expect(alert.type).to.equal('TronPipelineDelay');
      expect(alert.ids).to.include('TronPipelineDelay');
      expect(alert.reason).to.include('local nonce: 95, chain nonce: 100');
    });

    it('should not alert when chain nonce equals last saved nonce', async () => {
      database.getCheckPoint.resolves(100); // Same as chain nonce
      
      await checkTronPipelineStatus();
      
      // Should not process further when nonces match
      expect(database.getOriginIntentsLastNonce.called).to.be.false;
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should update checkpoint when local nonce changes', async () => {
      database.getOriginIntentsLastNonce.resolves(102); // Local ahead
      database.getCheckPoint.resolves(100); // Different from local
      
      await checkTronPipelineStatus();
      
      // Should update checkpoint to local nonce
      expect(database.saveCheckPoint.calledWith('tron_intent_nonce', 102)).to.be.true;
    });

    it('should not alert when shouldAlert is false', async () => {
      database.getOriginIntentsLastNonce.resolves(95); // Local behind
      
      await checkTronPipelineStatus(false);
      
      // Should not send alerts when disabled
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle no Tron chains configured', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': { network: 'evm' }, // Only EVM chains
          },
        },
      });

      await checkTronPipelineStatus();
      
      // Should return early and not process
      expect(getTronLastIntentNonceStub.called).to.be.false;
      expect(database.getOriginIntentsLastNonce.called).to.be.false;
    });

    it('should use first configured Tron domain', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': { network: 'tvm' }, // Tron mainnet
            '728126429': { network: 'tvm' }, // Hypothetical Tron testnet
          },
        },
      });

      await checkTronPipelineStatus();
      
      // Should use first Tron domain (728126428)
      expect(database.getOriginIntentsLastNonce.calledWith(728126428)).to.be.true;
    });

    it('should resolve alerts when nonces are synchronized', async () => {
      database.getOriginIntentsLastNonce.resolves(100); // Same as chain
      
      await checkTronPipelineStatus();
      
      // Should resolve alerts when synchronized
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle database errors gracefully', async () => {
      database.getOriginIntentsLastNonce.rejects(new Error('Database error'));
      
      // Should not throw
      await checkTronPipelineStatus();
      
      // Error should be handled gracefully
      expect(getTronLastIntentNonceStub.called).to.be.true;
    });

    it('should handle chain nonce fetch errors', async () => {
      getTronLastIntentNonceStub.rejects(new Error('RPC error'));
      
      // Should not throw
      await checkTronPipelineStatus();
      
      // Should still try to get local nonce
      expect(database.getOriginIntentsLastNonce.called).to.be.false; // Won't be called if chain fetch fails
    });

    it('should use correct checkpoint name', async () => {
      await checkTronPipelineStatus();
      
      // Should use specific checkpoint name for Tron
      expect(database.getCheckPoint.calledWith('tron_intent_nonce')).to.be.true;
      expect(database.saveCheckPoint.calledWith('tron_intent_nonce', 100)).to.be.true;
    });

    it('should handle edge case where local nonce equals saved nonce', async () => {
      database.getOriginIntentsLastNonce.resolves(95); // Local nonce
      database.getCheckPoint.resolves(95); // Same as local
      
      await checkTronPipelineStatus();
      
      // Should not save checkpoint again
      expect(database.saveCheckPoint.called).to.be.false;
    });
  });
});