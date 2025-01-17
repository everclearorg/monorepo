import { stub, SinonStub, SinonStubbedInstance, createStubInstance } from 'sinon';
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
import * as Mockable from '../../src/mockable';

const loggingContext = {
  requestContext: mock.log.requestContext('RELAYER-TEST'),
  methodContext: mock.log.methodContext(),
};
export const mockGelatoSDKSuccessResponse = { taskId: mockTaskId };
const mockTxHash = mkBytes32('0xbbb');

const logger = new Logger({ name: 'test', level: process.env.LOG_LEVEL || 'silent' });
describe('Adapters: Gelato', () => {
  let isChainSupportedByGelatoStub: SinonStub<[chainId: number], Promise<boolean>>;
  let chainReaderMock: SinonStubbedInstance<ChainReader>;
  let axiosGetStub: SinonStub;
  let gelatoRelayMock;

  beforeEach(() => {
    gelatoRelayMock = {
      callWithSyncFee: stub().resolves(mockGelatoSDKSuccessResponse),
      sponsoredCall: stub().resolves(mockGelatoSDKSuccessResponse),
      isNetworkSupported: stub().resolves(true),
      getSupportedNetworks: stub().resolves(['1337', '1338']),
      getTaskStatus: stub().resolves({ taskState: RelayerTaskStatus.CheckPending, transactionHash: mockTxHash }),
    };
    stub(RelayerIndexFns, 'gelatoRelay').value(gelatoRelayMock);
    chainReaderMock = createStubInstance(ChainReader, {
      getGasEstimateWithRevertCode: stub<[WriteTransaction]>().resolves('1231231231'),
    });
    axiosGetStub = stub(Mockable, 'axiosGet');
  });

  describe('#isChainSupportedByGelato', () => {
    it('should error', async () => {
      gelatoRelayMock.isNetworkSupported.rejects(new Error('Request failed!'));
      await expect(isChainSupportedByGelato(1337)).to.eventually.be.rejectedWith(UnableToGetGelatoSupportedChains);
    });

    it('should return true if a chain is supported by gelato', async () => {
      expect(await isChainSupportedByGelato(1337)).to.be.true;
    });

    it('should return false if a chain is not supported by gelato', async () => {
      gelatoRelayMock.isNetworkSupported.resolves(false);
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
      gelatoRelayMock.getSupportedNetworks.rejects(new Error('Request failed!'));

      await expect(getGelatoRelayChains()).to.eventually.be.rejectedWith(UnableToGetGelatoSupportedChains);
    });
  });

  describe('#getTaskStatus', () => {
    it('happy: should get task status from gelato', async () => {
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.CheckPending);
    });

    it('happy: should get task status from gelato', async () => {
      gelatoRelayMock.getTaskStatus.resolves({
        taskState: RelayerTaskStatus.Blacklisted,
        transactionHash: mockTxHash,
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.Blacklisted);
    });

    it('happy: should get task status from gelato', async () => {
      gelatoRelayMock.getTaskStatus.resolves({
        taskState: RelayerTaskStatus.Cancelled,
        transactionHash: mockTxHash,
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.Cancelled);
    });

    it('happy: should get task status from gelato', async () => {
      gelatoRelayMock.getTaskStatus.resolves({
        taskState: RelayerTaskStatus.CheckPending,
        transactionHash: mockTxHash,
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.CheckPending);
    });

    it('happy: should get task status from gelato', async () => {
      gelatoRelayMock.getTaskStatus.resolves({
        taskState: RelayerTaskStatus.ExecPending,
        transactionHash: mockTxHash,
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.ExecPending);
    });

    it('happy: should get task status from gelato', async () => {
      gelatoRelayMock.getTaskStatus.resolves({
        taskState: RelayerTaskStatus.ExecReverted,
        transactionHash: mockTxHash,
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.ExecReverted);
    });

    it('happy: should get task status from gelato', async () => {
      gelatoRelayMock.getTaskStatus.resolves({
        taskState: RelayerTaskStatus.NotFound,
        transactionHash: mockTxHash,
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.NotFound);
    });

    it('happy: should get task status from gelato', async () => {
      gelatoRelayMock.getTaskStatus.resolves({
        taskState: RelayerTaskStatus.WaitingForConfirmation,
        transactionHash: mockTxHash,
      });
      expect(await getTaskStatus('0x')).to.be.eq(RelayerTaskStatus.WaitingForConfirmation);
    });

    it('should return NotFound if the request fails', async () => {
      gelatoRelayMock.getTaskStatus.rejects(new Error('Request failed!'));

      await expect(getTaskStatus('0x')).to.be.rejectedWith(UnableToGetTaskStatus);
    });
  });

  describe('#waitForTaskCompletion', () => {
    it('should timeout', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getTaskStatus.rejects();
      await expect(
        waitForTaskCompletion(mockTaskId, logger, loggingContext.requestContext, 1_000, 200),
      ).to.be.rejectedWith(TransactionHashTimeout);
    });

    it('should wait until getting finalized task status', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getTaskStatus
        .onFirstCall()
        .resolves({ taskId: mockTaskId, taskState: RelayerTaskStatus.CheckPending });
      gelatoRelayMock.getTaskStatus
        .onSecondCall()
        .resolves({ taskId: mockTaskId, taskState: RelayerTaskStatus.ExecSuccess });
      const taskStatus = await waitForTaskCompletion(mockTaskId, logger, loggingContext.requestContext, 12_000, 200);
      expect(taskStatus).to.be.eq(RelayerTaskStatus.ExecSuccess);
    });

    it('happy: should return taskStatus successfully', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getTaskStatus.resolves({ taskState: RelayerTaskStatus.ExecSuccess });
      const taskStatus = await waitForTaskCompletion(mockTaskId, logger, loggingContext.requestContext, 6_000, 200);
      expect(taskStatus).to.be.eq(RelayerTaskStatus.ExecSuccess);
    });
  });

  describe('#gelatoSDKSend', () => {
    it('should fail to send', async () => {
      gelatoRelayMock.sponsoredCall.rejects();
      const request = {
        chainId: 1337,
        target: mkAddress('0x1'),
        data: '0xfee',
        relayContext: true,
        feeToken: '0x',
      };
      const apiKey = 'apikey';
      await expect(gelatoSDKSend(request, apiKey)).to.eventually.be.rejectedWith(RelayerSendFailed);
    });

    it('happy: should send data successfully!', async () => {
      const request = {
        chainId: 1337,
        target: mkAddress('0x1'),
        data: '0xfee',
        relayContext: true,
        feeToken: '0x',
      };
      const apiKey = 'apikey';
      const res = await gelatoSDKSend(request, apiKey);
      expect(res).to.be.deep.eq(mockGelatoSDKSuccessResponse);
    });
  });

  describe('#getTransactionHash', () => {
    it('happy should return transaction hash successfully', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      expect(await getTransactionHash(mockTaskId)).to.be.eq(mockTxHash);
    });

    it('should throw if fails', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      gelatoRelayMock.getTaskStatus.rejects();
      await expect(getTransactionHash(mockTaskId)).to.be.rejectedWith(UnableToGetTransactionHash);
    });
  });

  describe('#getRelayerAddress', () => {
    beforeEach(() => {
      axiosGetStub.resolves({
        data: { address: getGelatoRelayerAddress(chainIdToDomain(1337).toString()) },
      });
    });

    it('should work', async () => {
      const relayerAddress = await getRelayerAddress(1337);
      expect(relayerAddress).to.eq(getGelatoRelayerAddress(chainIdToDomain(1337).toString()));
    });
  });

  describe('#send', () => {
    let gelatoSDKSendStub;
    beforeEach(() => {
      isChainSupportedByGelatoStub = stub(GelatoFns, 'isChainSupportedByGelato').resolves(true);
      stub(GelatoFns, 'getRelayerAddress').resolves(getGelatoRelayerAddress(chainIdToDomain(1337).toString()));
      chainReaderMock = createStubInstance(ChainReader, {
        getGasEstimateWithRevertCode: stub<[WriteTransaction]>().resolves('1231231231'),
      });
      stub(RelayerIndexFns, 'url').value('http://example.com');
      gelatoSDKSendStub = stub(GelatoFns, 'gelatoSDKSend').resolves(mockGelatoSDKSuccessResponse);
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
          chainReaderMock,
          logger,
          loggingContext.requestContext,
        ),
      ).to.eventually.be.rejectedWith(RelayerSendFailed);
    });

    it('should error if gelato returns no response', async () => {
      gelatoSDKSendStub.resolves();
      expect(
        send(
          mockChainId,
          mockDomain.toString(),
          mkAddress(),
          '0xbeed',
          '0',
          'foo',
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
        chainReaderMock,
        logger,
        loggingContext.requestContext,
      );
      expect(gelatoSDKSendStub).to.be.calledOnce;
      expect(taskId).to.eq(mockTaskId);
    });
  });
});
