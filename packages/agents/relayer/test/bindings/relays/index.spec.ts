import { ChainService, EthWallet } from '@chimera-monorepo/chainservice';
import { TasksCache } from '@chimera-monorepo/adapters-cache';
import { RelayerTaskStatus, delay, expect, mkAddress, mkBytes32, mock, chainWrapper, type PublicClient } from '@chimera-monorepo/utils';
import { SinonStub, SinonStubbedInstance, createStubInstance, stub } from 'sinon';
import { FastifyInstance } from 'fastify';

import * as Mockable from '../../../src/mockable';
import * as Relays from '../../../src/bindings/relays';

import { createTask } from '../../mock';
import { mockAppContext } from '../../globalTestHook';

describe('Relayer:Relays', () => {
  describe('#pollCache', () => {
    let cache: { tasks: SinonStubbedInstance<TasksCache> };
    let wallet: SinonStubbedInstance<EthWallet>;
    let chainservice: SinonStubbedInstance<ChainService>;
    let provider: any;

    const task = createTask();
    const id = mkBytes32('0x1234');
    const gasPrice = BigInt('100000');
    const gasLimit = 3000000;
    const walletAddr = mkAddress('0x121212');

    const receipt = {
      transactionHash: mkBytes32('0xdef'),
      blockNumber: 123,
      status: 1,
      confirmations: 1,
      logs: [],
    };

    beforeEach(() => {
      cache = mockAppContext.adapters.cache as unknown as { tasks: SinonStubbedInstance<TasksCache> };
      wallet = mockAppContext.adapters.wallet as SinonStubbedInstance<EthWallet>;
      chainservice = mockAppContext.adapters.chainservice as SinonStubbedInstance<ChainService>;
      provider = {
        getGasPrice: stub().resolves(gasPrice),
        getTransactionCount: stub().resolves(1),
        setSigner: stub().resolves(),
      };

      // wallet.address = '0x1234';
      wallet.getAddress.resolves(walletAddr);

      cache.tasks.getPending.resolves([id]);
      cache.tasks.getTask.resolves(task);
      cache.tasks.getStatus.resolves(RelayerTaskStatus.ExecPending);

      chainservice.getProvider.resolves(provider as any);
      chainservice.sendTx.resolves(receipt);
      chainservice.getGasPrice.resolves('10');
      chainservice.getGasEstimate.resolves('100000');
    });

    it('should handle when no pending tasks retrieved', async () => {
      cache.tasks.getPending.resolves([]);
      await Relays.pollCache();
      expect(cache.tasks.getPending.calledOnce).to.be.true;
      expect(chainservice.sendTx.callCount).to.equal(0);
    });

    it('should handle when task is not found in cache', async () => {
      cache.tasks.getTask.resolves(undefined);
      await Relays.pollCache();
      expect(cache.tasks.getPending.calledOnce).to.be.true;
      expect(cache.tasks.getTask.calledOnceWithExactly(id)).to.be.true;
      expect(chainservice.sendTx.callCount).to.equal(0);
    });

    it('should skip if bad RPCs', async () => {
      chainservice.getProvider.resolves(undefined as any);
      await Relays.pollCache();
      expect(chainservice.getProvider.calledOnceWithExactly(task.chain)).to.be.true;
      expect(chainservice.sendTx.callCount).to.equal(0);
    });

    it('should fail if status is not pending', async () => {
      cache.tasks.getStatus.resolves(RelayerTaskStatus.NotFound);
      await Relays.pollCache();
      expect(cache.tasks.getStatus.calledOnceWithExactly(id)).to.be.true;
      expect(chainservice.sendTx.callCount).to.equal(0);
    });

    it('should fail if it cannot get gas price', async () => {
      const error = new Error('fail');
      chainservice.getGasPrice.rejects(error);
      await expect(Relays.pollCache()).to.be.fulfilled;
      expect(chainservice.getGasPrice.calledOnce).to.be.true;
      expect(chainservice.sendTx.callCount).to.equal(0);
      expect(cache.tasks.setError.calledOnceWithExactly(id, JSON.stringify(error))).to.be.true;
    });

    // FIXME: Implement
    it.skip('should fail if it cannot get gas limit', async () => {});

    it('should fail if it cannot get transaction count', async () => {
      const error = new Error('fail');
      provider.getTransactionCount.rejects(error);
      await expect(Relays.pollCache()).to.be.fulfilled;
      expect(provider.getTransactionCount.calledOnce).to.be.true;
      expect(chainservice.sendTx.callCount).to.equal(0);
      expect(cache.tasks.setError.calledOnceWithExactly(id, JSON.stringify(error))).to.be.true;
    });

    it('should fail if sending tx fails', async () => {
      const error = new Error('fail');
      chainservice.sendTx.rejects(error);
      await expect(Relays.pollCache()).to.be.fulfilled;
      expect(chainservice.sendTx.calledOnce).to.be.true;
      // MIN_GAS_LIMIT is 4,000,000, and since getGasEstimate returns '100000' which is less than MIN_GAS_LIMIT,
      // it uses MIN_GAS_LIMIT, then bumps by 120%: 4,000,000 * 120 / 100 = 4,800,000
      const expectedGasLimit = ((BigInt(4_000_000) * BigInt(120)) / BigInt(100)).toString();
      // getGasPrice returns '10', bumped by 130%: 10 * 130 / 100 = 13
      const expectedGasPrice = ((BigInt('10') * BigInt(130)) / BigInt(100)).toString();
      expect(chainservice.sendTx.getCall(0).args[0]).to.deep.include({
        domain: task.chain,
        data: task.data,
        to: task.to,
        from: walletAddr,
        value: task.fee.amount,
        gasLimit: expectedGasLimit,
        gasPrice: expectedGasPrice,
      });
      expect(cache.tasks.setError.calledOnceWithExactly(id, JSON.stringify(error))).to.be.true;
    });

    it('should fail if setting hash fails', async () => {
      const error = new Error('fail');
      cache.tasks.setHash.rejects(error);
      await expect(Relays.pollCache()).to.be.fulfilled;
      expect(cache.tasks.setHash.calledOnceWithExactly(id, receipt.transactionHash)).to.be.true;
      expect(cache.tasks.setError.calledOnceWithExactly(id, JSON.stringify(error))).to.be.true;
    });

    it('should work', async () => {
      await expect(Relays.pollCache()).to.be.fulfilled;
      expect(chainservice.sendTx.calledOnce).to.be.true;
      // MIN_GAS_LIMIT is 4,000,000, and since getGasEstimate returns '100000' which is less than MIN_GAS_LIMIT,
      // it uses MIN_GAS_LIMIT, then bumps by 120%: 4,000,000 * 120 / 100 = 4,800,000
      const expectedGasLimit = ((BigInt(4_000_000) * BigInt(120)) / BigInt(100)).toString();
      // getGasPrice returns '10', bumped by 130%: 10 * 130 / 100 = 13
      const expectedGasPrice = ((BigInt('10') * BigInt(130)) / BigInt(100)).toString();
      expect(chainservice.sendTx.getCall(0).args[0]).to.deep.include({
        domain: task.chain,
        data: task.data,
        to: task.to,
        from: walletAddr,
        value: task.fee.amount,
        gasLimit: expectedGasLimit,
        gasPrice: expectedGasPrice,
      });
      expect(cache.tasks.setHash.calledOnceWithExactly(id, receipt.transactionHash)).to.be.true;
      expect(cache.tasks.setError.callCount).to.equal(0);
    });
  });

  describe('#bindHealthServer', () => {
    let get: SinonStub;
    let listen: SinonStub;

    beforeEach(() => {
      get = stub();
      listen = stub().returns('foo');
      stub(Mockable, 'getFastifyInstance').returns({
        get,
        listen,
      } as unknown as FastifyInstance);
    });

    it('should work', async () => {
      await expect(Relays.bindHealthServer()).to.be.fulfilled;
      expect(get.calledOnceWith('/ping')).to.be.true;
      expect(
        listen.calledOnceWith({
          port: mockAppContext.config.poller.port,
          host: mockAppContext.config.poller.host,
        }),
      ).to.be.true;
    });
  });

  describe('#bindRelays', () => {
    let pollStub: SinonStub;
    beforeEach(() => {
      pollStub = stub(Relays, 'pollCache').resolves();
    });

    it('should respect cleanup', async () => {
      mockAppContext.config.mode = { cleanup: true };
      await Relays.bindRelays();
      expect(pollStub.calledOnce).to.be.false;
    });

    it('should work', async () => {
      mockAppContext.config.mode = { cleanup: false };
      mockAppContext.config.poller.interval = 300;
      await Relays.bindRelays();
      await delay(500);
      expect(pollStub.callCount).to.be.gte(1);
    });
  });

  describe('#api', () => {
    it('should work', async () => {
      expect(Relays.api.get.ping).to.be.ok;
    });
  });
});
