import { Interface } from 'ethers/lib/utils';
import { SinonStub, SinonStubbedInstance, stub } from 'sinon';
import { expect, mkBytes32 } from '@chimera-monorepo/utils';

import { getCurrentEpoch, getIntentContextFromContract } from './../../src/helpers';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { mock } from '../globalTestHook';

describe('Helpers:intent', () => {
  describe('fetch from chain functions', () => {
    const intentId = mkBytes32('0x1200000');
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
        name: 'getIntentContextFromContract',
        fn: getIntentContextFromContract,
        args: [intentId],
        method: 'contexts',
        inputs: [intentId],
        domain: +mock.config().hub.domain,
        to: mock.config().hub.deployments.everclear,
      },
      {
        name: 'getCurrentEpoch',
        fn: getCurrentEpoch,
        args: [],
        method: 'getCurrentEpoch',
        inputs: [],
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
      decodeStub = stub(Interface.prototype, 'decodeFunctionResult').returns(['0x1234']);
    });

    for (const { name, fn, args, method, inputs, domain, to } of cases) {
      it(`${name} - should work`, async () => {
        await fn(...args);
        expect(chainreader.readTx).to.be.calledWith({ to, domain, data: '0x1234' }, 'latest');
        expect(encodeStub).to.be.calledOnceWithExactly(method, inputs);
        expect(decodeStub).to.be.calledOnceWithExactly(method, '0x1234');
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
});
