/* eslint-disable @typescript-eslint/no-explicit-any */
import { randomInt } from 'crypto';
import { reset, restore, SinonStub, stub } from 'sinon';
import { expect } from '@chimera-monorepo/utils';

import { RpcError, TransactionReverted, SyncProvider } from '../../../../src';
import { TEST_ERROR, TEST_SENDER_DOMAIN } from '../../../utils';

describe('Eth RpcProvider', () => {
  const testStallTimeout = 100;
  let provider: SyncProvider;

  beforeEach(() => {
    provider = new SyncProvider(
      {
        urls: ['http://localhost:8545'], // Use a valid URL format
      },
      TEST_SENDER_DOMAIN,
      testStallTimeout,
      process.env.LOG_LEVEL === 'debug',
    );
    
    // Stub the underlying client methods to prevent real HTTP calls
    stub(provider.internalProvider.client, 'getBlockNumber').resolves(BigInt(12345));
    stub(provider.internalProvider.client, 'request').resolves('stubbed result');
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
      await provider.sync();
      expect(provider.internalProvider.client.getBlockNumber).to.have.been.calledOnce;
      expect(provider.syncedBlockNumber).to.be.eq(12345);
    });

    it('should throw if getBlockNumber throws', async () => {
      // Restore the original stub and create a new one that throws
      restore();
      stub(provider.internalProvider.client, 'getBlockNumber').rejects(TEST_ERROR);
      await expect(provider.sync()).to.be.rejectedWith(TEST_ERROR);
    });
  });

  describe('#send', () => {
    const testMethod = 'testMethod';
    const testParams = ['testParam1', 'testParam2'];
    const expectedSendResult = 'test send result';

    let requestStub: SinonStub;
    beforeEach(() => {
      requestStub = provider.internalProvider.client.request as SinonStub;
    });

    afterEach(() => {
      restore();
      reset();
    });

    it('should intercept rpc send call', async () => {
      const result = await provider.send(testMethod, testParams);
      expect(requestStub.calledOnce).to.be.true;
      expect(requestStub.calledWith({
        method: testMethod,
        params: testParams,
      })).to.be.true;
      expect(result).to.be.eq('stubbed result');
    });

    it('if attempt fails due to non-RpcError, throws', async () => {
      TEST_ERROR.type = 'test_type';
      requestStub.rejects(TEST_ERROR);
      await expect(provider.send(testMethod, testParams)).to.be.rejectedWith(TEST_ERROR);
      // expect(updateMetricsStub.calledOnce).to.be.true;
    });

    it('if every attempt fails due to RpcError, throws RpcError', async () => {
      const rpcError = new RpcError(RpcError.reasons.ConnectionReset);
      requestStub.rejects(rpcError);
      await expect(provider.send(testMethod, testParams)).to.be.rejectedWith(RpcError);
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
