/* eslint-disable @typescript-eslint/no-explicit-any */
import { randomInt } from 'crypto';
import { reset, restore, SinonStub, SinonStubbedInstance, stub } from 'sinon';
import { expect } from '@chimera-monorepo/utils';
import { providers } from 'ethers';

import { RpcError, TransactionReverted, SyncProvider } from '../../../../src/shared';
import { TEST_ERROR, TEST_SENDER_DOMAIN } from '../../../utils';

describe('Eth RpcProvider', () => {
  const testStallTimeout = 100;
  let provider: SyncProvider;
  let providerStub: SinonStubbedInstance<providers.StaticJsonRpcProvider>;

  beforeEach(() => {
    providerStub = stub(providers.StaticJsonRpcProvider.prototype);
    provider = new SyncProvider(
      {
        url: 'http://------------------',
      },
      TEST_SENDER_DOMAIN,
      testStallTimeout,
      process.env.LOG_LEVEL === 'debug',
    );
  });

  afterEach(() => {
    restore();
    reset();
  });

  it('has correct default values', () => {
    // Expected default values.
    expect(provider.synced).to.be.true;
    expect(provider.syncedBlockNumber).to.be.eq(-1);
    expect(provider.lag).to.be.eq(0);
    expect(provider.priority).to.be.eq(0);
    expect(provider.cps).to.be.eq(0);
    expect(provider.latency).to.be.eq(0);
    expect(provider.reliability).to.be.eq(1);
  });

  describe('#sync', () => {
    const testBlockNumber = randomInt(999999999999);

    it('should retrieve current block number', async () => {
      providerStub.getBlockNumber.resolves(testBlockNumber);
      await provider.sync();
      expect(providerStub.getBlockNumber.calledOnce).to.be.true;
      expect(provider.syncedBlockNumber).to.be.equal(testBlockNumber);
    });

    it('should throw if getBlockNumber throws', async () => {
      providerStub.getBlockNumber.rejects(TEST_ERROR);
      await expect(provider.sync()).to.be.rejectedWith(TEST_ERROR);
    });
  });

  describe('#send', () => {
    const testMethod = 'testMethod';
    const testParams = ['testParam1', 'testParam2'];
    const expectedSendResult = 'test send result';

    let superSendStub: SinonStub;
    beforeEach(() => {
      // This will stub StaticJsonRpcProvider (super class) send method. Only needs to be done once.
      superSendStub = stub((provider as any).__proto__, 'send').resolves(expectedSendResult);
    });

    afterEach(() => {
      restore();
      reset();
    });

    it('should intercept rpc send call', async () => {
      const result = await provider.send(testMethod, testParams);
      expect(superSendStub.calledOnce).to.be.true;
      expect(superSendStub.calledWith(testMethod, testParams)).to.be.true;
      // TODO: For some reason this stub is not being called.
      // expect(updateMetricsStub.calledOnce).to.be.true;
      expect(result).to.be.eq(expectedSendResult);
    });

    it('if attempt fails due to non-RpcError, throws', async () => {
      superSendStub.rejects(TEST_ERROR);
      await expect(provider.send(testMethod, testParams)).to.be.rejectedWith(TEST_ERROR);
      // expect(updateMetricsStub.calledOnce).to.be.true;
    });

    it('if every attempt fails due to RpcError, throws RpcError', async () => {
      const rpcError = new RpcError(RpcError.reasons.ConnectionReset);
      superSendStub.rejects(rpcError);
      await expect(provider.send(testMethod, testParams)).to.be.rejectedWith(RpcError);
      // expect(updateMetricsStub.callCount).to.be.eq(5);
    });
  });

  describe('#updateMetrics', () => {
    const startingReliability = 0.2;
    beforeEach(() => {
      provider.internalProvider.reliability = startingReliability;
    });

    it('success: should update its internal metrics correctly', async () => {
      (provider.internalProvider as any).updateMetrics(true, Date.now() - 1000, 12, 'testMethodName', [
        'testParam1',
        'testParam2',
      ]);
      expect(provider.reliability).to.be.gt(startingReliability);
      expect(provider.latency).to.be.gt(0);
      expect((provider.internalProvider as any).latencies.length).to.be.eq(1);
    });

    it('RPC failure: should update its internal metrics correctly', async () => {
      (provider.internalProvider as any).updateMetrics(
        false,
        Date.now() - 1000,
        12,
        'testMethodName',
        ['testParam1', 'testParam2'],
        {
          type: RpcError.type,
          context: {},
        },
      );
      expect(provider.reliability).to.be.lt(startingReliability);
      expect(provider.latency).to.be.gt(0);
      expect((provider.internalProvider as any).latencies.length).to.be.eq(1);
    });

    it('non-RPC failure: should update its internal metrics correctly', async () => {
      (provider.internalProvider as any).updateMetrics(
        false,
        Date.now() - 1000,
        12,
        'testMethodName',
        ['testParam1', 'testParam2'],
        {
          type: TransactionReverted.type,
          context: {},
        },
      );
      // Reliability should be unchanged.
      expect(provider.reliability).to.be.eq(startingReliability);
      expect(provider.latency).to.be.gt(0);
      expect((provider.internalProvider as any).latencies.length).to.be.eq(1);
    });
  });
});
