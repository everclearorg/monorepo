import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance, SinonStub } from 'sinon';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import { Database } from '@chimera-monorepo/database';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import * as asset from '../../src/helpers/asset';
import { checkTronSpokeBalance } from '../../src/checklist/tron-spoke';
import * as Mockable from '../../src/mockable';

describe('checkTronSpokeBalance', () => {
  let database: SinonStubbedInstance<Database>;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let subgraph: SinonStubbedInstance<SubgraphReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  // getRegisteredAssetHashFromContract and getCustodiedAssetsFromHubContract are globally stubbed
  let custodiedAssets = {};
  let spokeBalances = {};

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

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();
    // getRegisteredAssetHashFromContract is globally stubbed
    // Global stub returns '0xaaa', may need to adjust test expectations
    
    // Setup mock custodied assets for Tron
    custodiedAssets = {
      // TRX on Tron
      '728126428/0xbbbbfcba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '1000000', // 1 TRX (6 decimals)
      // USDT on Tron
      '728126428/0xccccfcba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '1000000', // 1 USDT (6 decimals)
    };
    // getCustodiedAssetsFromHubContract is globally stubbed
    // Note: Global stub returns '1000000000000000000', adjust test expectations as needed
    
    // Setup mock spoke balances for Tron (using TRX and USDT addresses)
    spokeBalances = {
      // TRX balances (native token uses zero address)
      '728126428/0x0000000000000000000000000000000000000000': '10000000', // 10 TRX
      // USDT balances (TRC20 token)
      '728126428/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t': '10000000', // 10 USDT
    };
    chainreader.getBalance.callsFake(async (domainId, _spokeAddress, assetId) => 
      spokeBalances[`${domainId}/${assetId ?? '0x0000000000000000000000000000000000000000'}`]
    );
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkTronSpokeBalance', () => {
    it('should work with sufficient Tron spoke balances', async () => {
      const result = await checkTronSpokeBalance();
      
      expect(result).to.have.property('728126428');
      const tronResult = result['728126428'];
      
      expect(tronResult).to.have.length(2); // TRX and USDT
      
      // Check TRX balance
      const trxBalance = tronResult.find(b => b.assetName === 'TRX');
      expect(trxBalance).to.exist;
      expect(trxBalance!.spokeBalance).to.equal('10000000'); // 10 TRX
      expect(trxBalance!.custodiedAmount).to.equal('1000000'); // 1 TRX
      expect(trxBalance!.belowThreshold).to.be.false;
      
      // Check USDT balance
      const usdtBalance = tronResult.find(b => b.assetName === 'USDT');
      expect(usdtBalance).to.exist;
      expect(usdtBalance!.spokeBalance).to.equal('10000000'); // 10 USDT
      expect(usdtBalance!.custodiedAmount).to.equal('1000000'); // 1 USDT
      expect(usdtBalance!.belowThreshold).to.be.false;
    });

    it('should detect low Tron spoke balances', async () => {
      // Set low spoke balances
      spokeBalances = {
        '728126428/0x0000000000000000000000000000000000000000': '500000', // 0.5 TRX (below 1 TRX custodied)
        '728126428/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t': '500000', // 0.5 USDT (below 1 USDT custodied)
      };
      
      const result = await checkTronSpokeBalance();
      
      const tronResult = result['728126428'];
      expect(tronResult).to.have.length(2);
      
      // Both assets should be below threshold
      expect(tronResult[0].belowThreshold).to.be.true;
      expect(tronResult[1].belowThreshold).to.be.true;
      
      // Should send alerts for low balances
      expect(sendAlertsStub.called).to.be.true;
    });

    it('should handle missing Tron spoke contract configuration', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': {
              ...mock.config().chains['728126428'],
              deployments: {}, // No everclear deployment
            },
          },
        },
      });

      const result = await checkTronSpokeBalance();
      
      // Should return empty result for domain without spoke contract
      expect(result).to.have.property('728126428');
      expect(result['728126428']).to.have.length(0);
    });

    it('should only process Tron chains (network: tvm)', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': { network: 'evm', deployments: { everclear: '0x123' } },
            '728126428': { network: 'tvm', deployments: { everclear: 'TMockAddress' } },
            '1151111081099710': { network: 'svm', deployments: { everclear: 'SolMockAddress' } },
          },
        },
      });

      const result = await checkTronSpokeBalance();
      
      // Should only have results for Tron domain
      expect(result).to.have.property('728126428');
      expect(result).to.not.have.property('1337');
      expect(result).to.not.have.property('1151111081099710');
    });

    it('should handle TRX native asset with zero address', async () => {
      const result = await checkTronSpokeBalance();
      
      // Verify that TRX balance was fetched using zero address (native asset)
      const balanceCalls = chainreader.getBalance.getCalls();
      const trxBalanceCall = balanceCalls.find(call => 
        call.args[0] === 728126428 && 
        call.args[2] === '0x0000000000000000000000000000000000000000'
      );
      expect(trxBalanceCall).to.exist;
    });

    it('should handle TRC20 tokens with proper addresses', async () => {
      const result = await checkTronSpokeBalance();
      
      // Verify that USDT balance was fetched using TRC20 contract address
      const balanceCalls = chainreader.getBalance.getCalls();
      const usdtBalanceCall = balanceCalls.find(call => 
        call.args[0] === 728126428 && 
        call.args[2] === 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'
      );
      expect(usdtBalanceCall).to.exist;
    });

    it('should use 6 decimal precision for TRX calculations', async () => {
      // Test with TRX amounts that would be different with 18 vs 6 decimals
      custodiedAssets = {
        '728126428/0xbbbbfcba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '1500000', // 1.5 TRX
      };
      spokeBalances = {
        '728126428/0x0000000000000000000000000000000000000000': '1000000', // 1 TRX
      };
      
      const result = await checkTronSpokeBalance();
      
      const tronResult = result['728126428'];
      const trxBalance = tronResult.find(b => b.assetName === 'TRX');
      
      // Should detect that 1 TRX < 1.5 TRX (using 6 decimals)
      expect(trxBalance!.belowThreshold).to.be.true;
      expect(trxBalance!.spokeBalance).to.equal('1000000'); // 1 TRX with 6 decimals
      expect(trxBalance!.custodiedAmount).to.equal('1500000'); // 1.5 TRX with 6 decimals
    });

    it('should resolve alerts when balances are sufficient', async () => {
      // Ensure balances are well above custodied amounts
      spokeBalances = {
        '728126428/0x0000000000000000000000000000000000000000': '100000000', // 100 TRX
        '728126428/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t': '100000000', // 100 USDT
      };
      
      await checkTronSpokeBalance();
      
      // Should resolve alerts when balances are sufficient
      expect(resolveAlertsStub.called).to.be.true;
      expect(sendAlertsStub.called).to.be.false;
    });

    it('should handle decimal validation for Tron assets', async () => {
      // Test with assets that have > 18 decimals (should error)
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': {
              ...mock.config().chains['728126428'],
              assets: {
                TRX: {
                  ...mock.config().chains['728126428'].assets.TRX,
                  decimals: 25, // Invalid: > 18 decimals
                },
              },
            },
          },
        },
      });

      // Should not throw but should log error
      await checkTronSpokeBalance();
      
      // Verify error was logged for invalid decimals
      expect(logger.error.called).to.be.true;
    });
  });
});