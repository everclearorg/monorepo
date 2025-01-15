import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance, SinonStub } from 'sinon';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import { Database } from '@chimera-monorepo/database';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import * as asset from '../../src/helpers/asset';
import { checkSpokeBalance } from '../../src/checklist/spoke';
import * as Mockable from '../../src/mockable';

describe('checkSpokeBalance', () => {
  let database: SinonStubbedInstance<Database>;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let subgraph: SinonStubbedInstance<SubgraphReader>;
  let logger: SinonStubbedInstance<Logger>;
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let getRegisteredAssetHashFromContractStub: SinonStub;
  let getCustodiedAssetsFromHubContractStub: SinonStub;
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
    getRegisteredAssetHashFromContractStub = stub(asset, 'getRegisteredAssetHashFromContract');
    getRegisteredAssetHashFromContractStub.callsFake((tickerHash: string, domain: string) => (`${domain}/${tickerHash}`));
    custodiedAssets = {
      // ETH
      '1337/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '1',
      '1338/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '1',
      // WETH
      '1337/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '1',
      '1338/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '1',
    };
    getCustodiedAssetsFromHubContractStub = stub(asset, 'getCustodiedAssetsFromHubContract');
    getCustodiedAssetsFromHubContractStub.callsFake(async (assetHash) => custodiedAssets[assetHash]);
    spokeBalances = {
      '1337/0': '10',
      '1338/0': '10',
      '1337/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '10',
      '1338/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '10',
    };
    chainreader.getBalance.callsFake(async (domainId, _spokeAddress, assetId) => spokeBalances[`${domainId}/${assetId ?? 0}`])
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkSpokeBalance', () => {
    it('should not alert if spoke balance is normal', async () => {
      await checkSpokeBalance();
      expect(sendAlertsStub.callCount).to.be.eq(0);
      expect(resolveAlertsStub.callCount).to.be.eq(2);

      custodiedAssets = {
        '1337/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '10',
        '1338/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '0',
        '1337/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '1',
        '1338/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '1',
      };
      spokeBalances = {
        '1337/0': '5',
        '1338/0': '5',
        '1337/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '10',
        '1338/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '10',
      };
      await checkSpokeBalance();
      expect(sendAlertsStub.callCount).to.be.eq(0);
      expect(resolveAlertsStub.callCount).to.be.eq(4);
    });
    it('should not alert if there is no spoke balance and custodied', async () => {
      custodiedAssets = {
        '1337/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '0',
        '1338/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '0',
        '1337/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '0',
        '1338/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '0',
      };
      spokeBalances = {
        '1337/0': '0',
        '1338/0': '0',
        '1337/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '0',
        '1338/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '0',
      };
      await checkSpokeBalance();
      expect(sendAlertsStub.callCount).to.be.eq(0);
      expect(resolveAlertsStub.callCount).to.be.eq(2);
    });
    it('should alert if spoke balance is abnormal', async () => {
      custodiedAssets = {
        '1337/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '10',
        '1338/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '10',
        '1337/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '0',
        '1338/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '0',
      };
      spokeBalances = {
        '1337/0': '1',
        '1338/0': '1',
        '1337/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '0',
        '1338/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '0',
      };
      await checkSpokeBalance();
      expect(sendAlertsStub.callCount).to.be.eq(1);
      expect(resolveAlertsStub.callCount).to.be.eq(1);
      
      custodiedAssets = {
        '1337/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '10',
        '1338/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '0',
        '1337/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '0',
        '1338/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '0',
      };
      spokeBalances = {
        '1337/0': '0',
        '1338/0': '5',
        '1337/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '0',
        '1338/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '0',
      };
      await checkSpokeBalance();
      expect(sendAlertsStub.callCount).to.be.eq(2);
      expect(resolveAlertsStub.callCount).to.be.eq(2);
    });
    it('should generate multiple alerts if multiple assets have abnormal spoke balance', async () => {
      custodiedAssets = {
        '1337/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '10',
        '1338/0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4': '10',
        '1337/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '10',
        '1338/0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8': '10',
      };
      spokeBalances = {
        '1337/0': '1',
        '1338/0': '1',
        '1337/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '1',
        '1338/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '1',
      };
      await checkSpokeBalance();
      expect(sendAlertsStub.callCount).to.be.eq(2);
      expect(resolveAlertsStub.callCount).to.be.eq(0);
    })
  });
});
