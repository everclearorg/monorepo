import { SinonStub, SinonStubbedInstance, stub } from 'sinon';
import { expect, mkAddress, mkBytes32, chainWrapper } from '@chimera-monorepo/utils';

import {
  getAssetFromContract,
  getCustodiedAssetsFromHubContract,
  getRegisteredAssetHashFromContract,
  getTokenFromContract,
} from '../../src/helpers';
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
    funcSig: string;
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
      funcSig: 'assetHash(bytes32,uint32)',
      inputs: [tickerHash, domain],
      domain: +mock.config().hub.domain,
      to: mock.config().hub.deployments.everclear,
    },
    {
      name: 'getAssetFromContract',
      fn: getAssetFromContract,
      args: [asset, domain],
      method: 'adoptedForAssets',
      funcSig: 'adoptedForAssets(bytes32)',
      inputs: [assetHash],
      domain: +mock.config().hub.domain,
      to: mock.config().hub.deployments.everclear,
    },
    {
      name: 'getTokenFromContract',
      fn: getTokenFromContract,
      args: [tickerHash],
      method: 'tokenConfigs',
      funcSig: 'tokenConfigs(bytes32)',
      inputs: [tickerHash],
      domain: +mock.config().hub.domain,
      to: mock.config().hub.deployments.everclear,
    },
    {
      name: 'getTokenFromContract',
      fn: getTokenFromContract,
      args: [tickerHash],
      method: 'tokenFees',
      funcSig: 'tokenFees(bytes32)',
      inputs: [tickerHash],
      domain: +mock.config().hub.domain,
      to: mock.config().hub.deployments.everclear,
    },
    {
      name: 'getCustodiedAssetsFromHubContract',
      fn: getCustodiedAssetsFromHubContract,
      args: [assetHash],
      method: 'custodiedAssets',
      funcSig: 'custodiedAssets(bytes32)',
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
    encodeStub = stub(chainWrapper, 'encodeFunctionData').returns('0x1234' as `0x${string}`);
    decodeStub = stub(chainWrapper, 'decodeFunctionResult').returns([['0x1234']]);
  });

  for (const { name, fn, args, method, funcSig, inputs, domain, to } of cases) {
    it(`${name} - should work`, async () => {
      await fn(...args);
      expect(chainreader.readTx).to.be.calledWith({ to, domain, data: '0x1234', funcSig }, 'latest');
      expect(encodeStub).to.be.calledWith({ abi: [], functionName: method, args: inputs });
      expect(decodeStub).to.be.calledWith({ abi: [], functionName: method, data: '0x1234' });
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
