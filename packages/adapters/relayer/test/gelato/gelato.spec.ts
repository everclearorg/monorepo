import { stub, SinonStub, SinonStubbedInstance, createStubInstance, restore } from 'sinon';
import {
  mkAddress,
  expect,
  mock,
  Logger,
  getGelatoRelayerAddress,
  RelayerTaskStatus,
  mkBytes32,
  chainIdToDomain,
} from '@chimera-monorepo/utils';
import { StatusCode } from '@gelatocloud/gasless';
import { ChainReader, WriteTransaction } from '@chimera-monorepo/chainservice';

import * as RelayerIndexFns from '../../src/gelato/index';
import { mockChainId, mockDomain, mockTaskId } from '../mock';
import {
  send,
  getRelayerAddress,
  gelatoSDKSend,
  isChainSupportedByGelato,
  getGelatoRelayChains,
  getTaskStatus,
  getTransactionHash,
  waitForTaskCompletion,
} from '../../src/gelato/gelato';
import * as GelatoFns from '../../src/gelato/gelato';
import {
  RelayerSendFailed,
  TransactionHashTimeout,
  UnableToGetGelatoSupportedChains,
  UnableToGetTaskStatus,
  UnableToGetTransactionHash,
} from '../../src/errors';

const loggingContext = {
  requestContext: mock.log.requestContext('RELAYER-TEST'),
  methodContext: mock.log.methodContext(),
};
const mockTxHash = mkBytes32('0xbbb');

const logger = new Logger({ name: 'test', level: process.env.LOG_LEVEL || 'silent' });
describe('Adapters: Gelato', () => {
  let isChainSupportedByGelatoStub: SinonStub<[chainId: number], Promise<boolean>>;
  let chainReaderMock: SinonStubbedInstance<ChainReader>;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let gelatoRelayMock: any;

  beforeEach(() => {
    gelatoRelayMock = {
      sendTransaction: stub().resolves(mockTaskId),
      getCapabilities: stub().resolves({
        1337: { feeCollector: mkAddress('0xfee'), tokens: [] },
        1338: { feeCollector: mkAddress('0xfee'), tokens: [] },
      }),
      getStatus: stub().resolves({
        status: StatusCode.Pending,
        chainId: 1337,
        createdAt: Date.now(),
      }),
      waitForStatus: stub().resolves({
        status: StatusCode.Success,
        chainId: 1337,
        createdAt: Date.now(),
        receipt: { transactionHash: mockTxHash },
      }),
    };
    stub(RelayerIndexFns, 'gelatoRelay').value(gelatoRelayMock);
    chainReaderMock = createStubInstance(ChainReader, {
      getGasEstimateWithRevertCode: stub<[WriteTransaction]>().resolves('1231231231'),
    });
  });

  afterEach(() => {
    restore();
  });

  describe('#isChainSupportedByGelato', () => {
    it('should error', async () => {
      gelatoRelayMock.getCapabilities.rejects(new Error('Request failed!'));
      await expect(isChainSupportedByGelato(1337)).to.eventually.be.rejectedWith(UnableToGetGelatoSupportedChains);
    });

    it('should return true if a chain is supported by gelato', async () => {
      expect(await isChainSupportedByGelato(1337)).to.be.true;
    });

    it('should return false if a chain is not supported by gelato', async () => {
      gelatoRelayMock.getCapabilities.resolves({ 9999: { feeCollector: mkAddress('0xfee'), tokens: [] } });
      expect(await isChainSupportedByGelato(12345)).to.be.false;
    });
  });

  describe('#getRelayerAddress', () => {
    it('happy: should return address', async () => {
      expect(await getRelayerAddress(1337)).to.be.eq(getGelatoRelayerAddress(chainIdToDomain(1337).toString()));
    });
  });

  describe('#getGelatoRelayChains', () => {
    it('happy: should get relay chains from gelato', async () => {
      expect(await getGelatoRelayChains()).to.be.deep.eq(['1337', '1338']);
    });

    it('should throw the request fails', async () => {
      gelatoRelayMock.getCapabilities.rejects(new Error('Request failed!'));

      await expect(getGelatoRelayChains()).to.eventually.be.rejectedWith(UnableToGetGelatoSupportedChains);
    });
  });

  describe('#getTaskStatus', () => {
    it('happy: should get CheckPending status', async () => {
      gelatoRelayMock.getStatus.resolves({
        status: StatusCode.Pending,
        chainId: 1337,
        createdAt: Date.now(),
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.CheckPending);
    });

    it('happy: should get ExecPending status', async () => {
      gelatoRelayMock.getStatus.resolves({
        status: StatusCode.Submitted,
        chainId: 1337,
        createdAt: Date.now(),
        hash: mockTxHash,
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.ExecPending);
    });

    it('happy: should get ExecSuccess status', async () => {
      gelatoRelayMock.getStatus.resolves({
        status: StatusCode.Success,
        chainId: 1337,
        createdAt: Date.now(),
        receipt: { transactionHash: mockTxHash },
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.ExecSuccess);
    });

    it('happy: should get Cancelled status for Rejected', async () => {
      gelatoRelayMock.getStatus.resolves({
        status: StatusCode.Rejected,
        chainId: 1337,
        createdAt: Date.now(),
        message: 'rejected',
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.Cancelled);
    });

    it('happy: should get ExecReverted status', async () => {
      gelatoRelayMock.getStatus.resolves({
        status: StatusCode.Reverted,
        chainId: 1337,
        createdAt: Date.now(),
        data: '0x',
        receipt: { transactionHash: mockTxHash },
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.ExecReverted);
    });

    it('should throw if the request fails', async () => {
      gelatoRelayMock.getStatus.rejects(new Error('Request failed!'));

      await expect(getTaskStatus('0x')).to.be.rejectedWith(UnableToGetTaskStatus);
    });
  });

  describe('#waitForTaskCompletion', () => {
    it('should timeout', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getStatus.rejects();
      await expect(
        waitForTaskCompletion(mockTaskId, logger, loggingContext.requestContext, 1_000, 200),
      ).to.be.rejectedWith(TransactionHashTimeout);
    });

    it('should wait until getting finalized task status', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getStatus
        .onFirstCall()
        .resolves({ status: StatusCode.Pending, chainId: 1337, createdAt: Date.now() });
      gelatoRelayMock.getStatus
        .onSecondCall()
        .resolves({
          status: StatusCode.Success,
          chainId: 1337,
          createdAt: Date.now(),
          receipt: { transactionHash: mockTxHash },
        });
      const taskStatus = await waitForTaskCompletion(mockTaskId, logger, loggingContext.requestContext, 12_000, 200);
      expect(taskStatus).to.be.eq(RelayerTaskStatus.ExecSuccess);
    });

    it('happy: should return taskStatus successfully', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getStatus.resolves({
        status: StatusCode.Success,
        chainId: 1337,
        createdAt: Date.now(),
        receipt: { transactionHash: mockTxHash },
      });
      const taskStatus = await waitForTaskCompletion(mockTaskId, logger, loggingContext.requestContext, 6_000, 200);
      expect(taskStatus).to.be.eq(RelayerTaskStatus.ExecSuccess);
    });
  });

  describe('#gelatoSDKSend', () => {
    it('should fail to send', async () => {
      gelatoRelayMock.sendTransaction.rejects();
      await expect(gelatoSDKSend(1337, mkAddress('0x1'), '0xfee')).to.eventually.be.rejectedWith(RelayerSendFailed);
    });

    it('happy: should send data successfully!', async () => {
      const res = await gelatoSDKSend(1337, mkAddress('0x1'), '0xfee');
      expect(res).to.be.eq(mockTaskId);
    });
  });

  describe('#getTransactionHash', () => {
    it('happy: should return transaction hash for Success status', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getStatus.resolves({
        status: StatusCode.Success,
        chainId: 1337,
        createdAt: Date.now(),
        receipt: { transactionHash: mockTxHash },
      });
      expect(await getTransactionHash(mockTaskId)).to.be.eq(mockTxHash);
    });

    it('happy: should return hash for Submitted status', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getStatus.resolves({
        status: StatusCode.Submitted,
        chainId: 1337,
        createdAt: Date.now(),
        hash: mockTxHash,
      });
      expect(await getTransactionHash(mockTaskId)).to.be.eq(mockTxHash);
    });

    it('should return undefined for Pending status', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getStatus.resolves({
        status: StatusCode.Pending,
        chainId: 1337,
        createdAt: Date.now(),
      });
      expect(await getTransactionHash(mockTaskId)).to.be.undefined;
    });

    it('should throw if fails', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getStatus.rejects();
      await expect(getTransactionHash(mockTaskId)).to.be.rejectedWith(UnableToGetTransactionHash);
    });
  });

  describe('#getRelayerAddress', () => {
    it('should work', async () => {
      const relayerAddress = await getRelayerAddress(1337);
      expect(relayerAddress).to.eq(getGelatoRelayerAddress(chainIdToDomain(1337).toString()));
    });
  });

  describe('#send', () => {
    let gelatoSDKSendStub: SinonStub;
    beforeEach(() => {
      isChainSupportedByGelatoStub = stub(GelatoFns, 'isChainSupportedByGelato').resolves(true);
      stub(GelatoFns, 'getRelayerAddress').resolves(getGelatoRelayerAddress(chainIdToDomain(1337).toString()));
      chainReaderMock = createStubInstance(ChainReader, {
        getGasEstimateWithRevertCode: stub<[WriteTransaction]>().resolves('1231231231'),
      });
      gelatoSDKSendStub = stub(GelatoFns, 'gelatoSDKSend').resolves(mockTaskId);
    });

    it('should error if gelato returns error', async () => {
      gelatoSDKSendStub.rejects('oh no');
      expect(
        send(
          mockChainId,
          mockDomain.toString(),
          mkAddress(),
          '0xbeed',
          '0',
          'foo',
          'gelatoApiKey',
          chainReaderMock,
          logger,
          loggingContext.requestContext,
        ),
      ).to.eventually.be.rejectedWith(RelayerSendFailed);
    });

    it('should error if gelato returns no response', async () => {
      gelatoSDKSendStub.resolves(undefined);
      expect(
        send(
          mockChainId,
          mockDomain.toString(),
          mkAddress(),
          '0xbeed',
          '0',
          'foo',
          'gelatoApiKey',
          chainReaderMock,
          logger,
          loggingContext.requestContext,
        ),
      ).to.eventually.be.rejectedWith(RelayerSendFailed);
    });

    it("should throw if the chain isn't supported by gelato", () => {
      isChainSupportedByGelatoStub.resolves(false);
      expect(
        send(
          mockChainId,
          mockDomain.toString(),
          mkAddress(),
          '0xbeed',
          '0',
          'foo',
          'gelatoApiKey',
          chainReaderMock,
          logger,
          loggingContext.requestContext,
        ),
      ).to.eventually.be.rejectedWith(Error);
    });

    it('should send the bid to the relayer', async () => {
      const taskId = await send(
        Number(mockChainId),
        mockDomain.toString(),
        mkAddress(),
        '0xbeed',
        '0',
        'foo',
        'gelatoApiKey',
        chainReaderMock,
        logger,
        loggingContext.requestContext,
      );
      expect(gelatoSDKSendStub).to.be.calledOnce;
      expect(taskId).to.eq(mockTaskId);
    });
  });
});
