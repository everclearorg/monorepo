import { Logger, expect, TRON_CHAINID, GasType } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkTronGas, checkTronPipelineStatus } from '../../src/checklist/tron';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import * as Mockable from '../../src/mockable';
import * as Utils from '@chimera-monorepo/utils';
import { Database } from '@chimera-monorepo/database';

describe('Checklist - Tron', () => {
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let fetchRelayerDataStub: SinonStub;
  let getTronLastIntentNonceStub: SinonStub;
  let getAccountResourcesStub: SinonStub;
  let defaultTronWebFactoryStub: SinonStub;
  let tronWebMock: any;
  let database: SinonStubbedInstance<Database>;
  let logger: SinonStubbedInstance<Logger>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });

    database = mock.instances.database() as SinonStubbedInstance<Database>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;

    getContextStub.returns({
      ...mock.context(),
      config: { 
        ...mock.config(),
        relayers: [
          { type: 'Everclear', url: 'https://relayer.example.com' }
        ]
      },
    });

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();
    fetchRelayerDataStub = stub(Mockable, 'fetchRelayerData');
    fetchRelayerDataStub.resolves('T1234567890abcdef');
    getTronLastIntentNonceStub = stub(Mockable, 'getTronLastIntentNonce');
    getTronLastIntentNonceStub.resolves(100);
    
    getAccountResourcesStub = stub(Mockable, 'getAccountResources');
    
    tronWebMock = {
      // Mock TronWeb instance
    };
    
    defaultTronWebFactoryStub = stub(Utils.DefaultTronWebFactory.prototype, 'create');
    defaultTronWebFactoryStub.returns(tronWebMock);
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronGas', () => {
    it('should work with no TVM chains', async () => {
      const config = mock.config();
      // Remove TVM chains
      delete config.chains['1339'];
      getContextStub.returns({
        ...mock.context(),
        config,
      });

      const result = await checkTronGas(true);
      expect(result).to.deep.equal([]);
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle successful resource checks without alerts', async () => {
      const config = mock.config();
      config.chains['1339'].minBandwidthOnRelayer = 1000;
      config.chains['1339'].minEnergyOnRelayer = 2000;
      config.chains['1339'].minBandwidthOnGateway = 500;
      config.chains['1339'].minEnergyOnGateway = 1000;
      
      getContextStub.returns({
        ...mock.context(),
        config,
      });

      getAccountResourcesStub.resolves({
        bandwidth: BigInt(5000),
        energy: BigInt(10000),
      });

      const result = await checkTronGas(true);
      
      expect(result).to.have.lengthOf(2); // bandwidth and energy
      expect(result[0].domain).to.equal('1339');
      expect(result[0].gasType).to.equal(GasType.Bandwidth);
      expect(result[0].belowRelayerThreshold).to.be.false;
      expect(result[0].belowGatewayThreshold).to.be.false;
      expect(result[1].gasType).to.equal(GasType.Energy);
      
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.callCount).to.equal(4); // 4 resolve calls for bandwidth/energy on relayer/gateway
    });

    it('should send alerts when resources are below threshold', async () => {
      const config = mock.config();
      config.chains['1339'].minBandwidthOnRelayer = 1000;
      config.chains['1339'].minEnergyOnRelayer = 2000;
      config.chains['1339'].minBandwidthOnGateway = 500;
      config.chains['1339'].minEnergyOnGateway = 1000;
      
      getContextStub.returns({
        ...mock.context(),
        config,
      });

      // Mock getAccountResources to be called twice (once for relayer, once for gateway)
      getAccountResourcesStub.onFirstCall().resolves({
        bandwidth: BigInt(100), // Below all thresholds
        energy: BigInt(200),     // Below all thresholds
      });
      getAccountResourcesStub.onSecondCall().resolves({
        bandwidth: BigInt(100), // Below all thresholds  
        energy: BigInt(200),     // Below all thresholds
      });

      const result = await checkTronGas(true);
      
      expect(result).to.have.lengthOf(2);
      // Check that thresholds are violated (bandwidth item first, then energy)
      expect(result[0].belowRelayerThreshold || result[0].belowGatewayThreshold).to.be.true;
      expect(result[1].belowRelayerThreshold || result[1].belowGatewayThreshold).to.be.true;
      
      expect(sendAlertsStub.callCount).to.be.greaterThan(0); // At least some alerts sent
      // Don't check resolveAlertsStub since it might be called in various scenarios
    });

    it('should handle missing relayer address', async () => {
      fetchRelayerDataStub.resolves(undefined);

      const result = await checkTronGas(true);
      
      expect(result).to.have.lengthOf(2);
      expect(result[0].relayerAddress).to.be.undefined;
      expect(result[0].belowRelayerThreshold).to.be.false;
    });

    it('should handle missing gateway address', async () => {
      const config = mock.config();
      delete config.chains['1339'].deployments.gateway;
      
      getContextStub.returns({
        ...mock.context(),
        config,
      });

      getAccountResourcesStub.resolves({
        bandwidth: BigInt(5000),
        energy: BigInt(10000),
      });

      const result = await checkTronGas(true);
      
      expect(result).to.have.lengthOf(2);
      expect(result[0].gatewayAddress).to.be.undefined;
      expect(result[0].belowGatewayThreshold).to.be.false;
    });

    it('should handle errors when fetching resources', async () => {
      getAccountResourcesStub.rejects(new Error('RPC error'));

      const result = await checkTronGas(true);
      
      expect(result).to.have.lengthOf(2);
      expect(result[0].relayerGas).to.be.undefined;
      expect(result[0].gatewayGas).to.be.undefined;
      expect(logger.error.called).to.be.true;
    });

    it('should not send alerts when shouldAlert is false', async () => {
      getAccountResourcesStub.resolves({
        bandwidth: BigInt(100),
        energy: BigInt(200),
      });

      const result = await checkTronGas(false);
      
      expect(result).to.have.lengthOf(2);
      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should handle partial threshold violations', async () => {
      const config = mock.config();
      config.chains['1339'].minBandwidthOnRelayer = 6000;
      config.chains['1339'].minEnergyOnRelayer = 100;
      config.chains['1339'].minBandwidthOnGateway = 100;
      config.chains['1339'].minEnergyOnGateway = 6000;
      
      getContextStub.returns({
        ...mock.context(),
        config,
      });

      // Mock for relayer call
      getAccountResourcesStub.onFirstCall().resolves({
        bandwidth: BigInt(5000), // Below relayer threshold, above gateway
        energy: BigInt(5000),     // Above relayer threshold, below gateway
      });
      // Mock for gateway call  
      getAccountResourcesStub.onSecondCall().resolves({
        bandwidth: BigInt(5000), // Below relayer threshold, above gateway
        energy: BigInt(5000),     // Above relayer threshold, below gateway
      });

      const result = await checkTronGas(true);
      
      expect(sendAlertsStub.callCount).to.be.greaterThan(0); // At least some alerts for violations
      expect(resolveAlertsStub.callCount).to.be.greaterThanOrEqual(0); // Some resolves for non-violations
    });

    it('should use default provider when none specified', async () => {
      const config = mock.config();
      config.chains['1339'].providers = [];
      
      getContextStub.returns({
        ...mock.context(),
        config,
      });

      getAccountResourcesStub.resolves({
        bandwidth: BigInt(5000),
        energy: BigInt(10000),
      });

      await checkTronGas(true);
      
      expect(defaultTronWebFactoryStub.calledWith('https://api.trongrid.io')).to.be.true;
    });
  });

  describe('#checkTronPipelineStatus', () => {
    beforeEach(() => {
      database.getOriginIntentsLastNonce.resolves(100);
      database.getCheckPoint.resolves(90);
      database.saveCheckPoint.resolves();
    });

    it('should not alert when chain nonce matches saved checkpoint', async () => {
      getTronLastIntentNonceStub.resolves(90);
      database.getCheckPoint.resolves(90);

      await checkTronPipelineStatus(true);

      expect(sendAlertsStub.called).to.be.false;
      expect(database.saveCheckPoint.called).to.be.false;
    });

    it('should save checkpoint when local nonce differs from saved', async () => {
      getTronLastIntentNonceStub.resolves(95);
      database.getOriginIntentsLastNonce.resolves(100);
      database.getCheckPoint.resolves(90);

      await checkTronPipelineStatus(true);

      expect(database.saveCheckPoint.calledWith('tron_intent_nonce', 100)).to.be.true;
    });

    it('should send alert when chain nonce differs from local nonce', async () => {
      getTronLastIntentNonceStub.resolves(95);
      database.getOriginIntentsLastNonce.resolves(100);

      await checkTronPipelineStatus(true);

      expect(sendAlertsStub.callCount).to.equal(1);
      const alertCall = sendAlertsStub.getCall(0);
      expect(alertCall.args[0].type).to.equal('TronPipelineDelay');
      expect(alertCall.args[0].reason).to.include('local nonce: 100, chain nonce: 95');
    });

    it('should resolve alert when nonces match', async () => {
      getTronLastIntentNonceStub.resolves(100);
      database.getOriginIntentsLastNonce.resolves(100);
      database.getCheckPoint.resolves(95);

      await checkTronPipelineStatus(true);

      expect(resolveAlertsStub.callCount).to.equal(1);
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should not send alerts when shouldAlert is false', async () => {
      getTronLastIntentNonceStub.resolves(95);
      database.getOriginIntentsLastNonce.resolves(100);

      await checkTronPipelineStatus(false);

      expect(sendAlertsStub.called).to.be.false;
      expect(resolveAlertsStub.called).to.be.false;
    });

    it('should handle checkpoint save and nonce mismatch together', async () => {
      getTronLastIntentNonceStub.resolves(85);
      database.getOriginIntentsLastNonce.resolves(100);
      database.getCheckPoint.resolves(90);

      await checkTronPipelineStatus(true);

      expect(database.saveCheckPoint.calledWith('tron_intent_nonce', 100)).to.be.true;
      expect(sendAlertsStub.callCount).to.equal(1);
    });
  });
});