import { Interface } from 'ethers/lib/utils';
import { SinonStub, SinonStubbedInstance, stub } from 'sinon';
import { expect, mkAddress, mkBytes32 } from '@chimera-monorepo/utils';

import {
  getAssetFromContract,
  getCustodiedAssetsFromHubContract,
  getRegisteredAssetHashFromContract,
  getTokenFromContract,
} from './../../src/helpers';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { mock } from '../globalTestHook';

describe('Helpers:asset', () => {
  const tickerHash = mkBytes32('0x1200000');
  const asset = mkAddress('0x1212200');
  const assetHash = '0x6b549ff6437ed01c8a008747dfa5226e44146210f639262c454a36c37ef1b6ac';
  const domain = mock.config().hub.domain;
  // All of these functions take a similar form -- calling chainreader.readTx
  // to fetch some property, and decoding to get the value.
  type ContractQueryTestCase = {
    name: string;
    fn: (...inputs: any[]) => Promise<any>;
    args: any[];
    method: string;
    inputs: any[];
    domain: number;
    to: string;
  };
  const cases: ContractQueryTestCase[] = [
    {
      name: 'getRegisteredAssetHashFromContract',
      fn: getRegisteredAssetHashFromContract,
      args: [tickerHash, domain],
      method: 'assetHash',
      inputs: [tickerHash, domain],
      domain: +mock.config().hub.domain,
      to: mock.config().hub.deployments.everclear,
    },
    {
      name: 'getAssetFromContract',
      fn: getAssetFromContract,
      args: [asset, domain],
      method: 'adoptedForAssets',
      inputs: [assetHash],
      domain: +mock.config().hub.domain,
      to: mock.config().hub.deployments.everclear,
    },
    {
      name: 'getTokenFromContract',
      fn: getTokenFromContract,
      args: [tickerHash],
      method: 'tokenConfigs',
      inputs: [tickerHash],
      domain: +mock.config().hub.domain,
      to: mock.config().hub.deployments.everclear,
    },
    {
      name: 'getTokenFromContract',
      fn: getTokenFromContract,
      args: [tickerHash],
      method: 'tokenFees',
      inputs: [tickerHash],
      domain: +mock.config().hub.domain,
      to: mock.config().hub.deployments.everclear,
    },
    {
      name: 'getCustodiedAssetsFromHubContract',
      fn: getCustodiedAssetsFromHubContract,
      args: [assetHash],
      method: 'custodiedAssets',
      inputs: [assetHash],
      domain: +mock.config().hub.domain,
      to: mock.config().hub.deployments.everclear,
    },
  ];

  let chainreader: SinonStubbedInstance<ChainReader>;
  let decodeStub: SinonStub;
  let encodeStub: SinonStub;

  beforeEach(() => {
    chainreader = mock.context().adapters.chainreader as SinonStubbedInstance<ChainReader>;

    chainreader.readTx.resolves('0x1234');
    encodeStub = stub(Interface.prototype, 'encodeFunctionData').returns('0x1234');
    decodeStub = stub(Interface.prototype, 'decodeFunctionResult').returns([['0x1234']]);
  });

  for (const { name, fn, args, method, inputs, domain, to } of cases) {
    it(`${name} - should work`, async () => {
      await fn(...args);
      expect(chainreader.readTx).to.be.calledWith({ to, domain, data: '0x1234' }, 'latest');
      expect(encodeStub).to.be.calledWith(method, inputs);
      expect(decodeStub).to.be.calledWith(method, '0x1234');
    });

    it(`${name} - should fail if encoding errors`, async () => {
      encodeStub.throws(new Error('error'));
      await expect(fn(...args)).to.be.rejectedWith('error');
    });

    it(`${name} - should fail if chainreader.readTx errors`, async () => {
      chainreader.readTx.rejects(new Error('error'));
      await expect(fn(...args)).to.be.rejectedWith('error');
    });

    it(`${name} - should fail if decoding errors`, async () => {
      decodeStub.throws(new Error('error'));
      await expect(fn(...args)).to.be.rejectedWith('error');
    });
  }
});
