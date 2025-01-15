import { stub, SinonStub, SinonStubbedInstance, createStubInstance } from 'sinon';
import {
  mkAddress,
  expect,
  mock,
  Logger,
  RelayerApiPostTaskRequestParams,
  EverclearError,
  mkBytes32,
  RelayerTaskStatus,
} from '@chimera-monorepo/utils';
import { ChainReader, WriteTransaction } from '@chimera-monorepo/chainservice';
import { constants } from 'ethers';

import {
  everclearRelayerSend,
  getRelayerAddress,
  getTaskStatus,
  getTransactionHash,
  waitForTaskCompletion,
} from '../../src/everclear/everclear';
import * as RelayerIndexFns from '../../src/everclear/index';
import * as Mockable from '../../src/mockable';
import { TransactionHashTimeout, UnableToGetTaskStatus, UnableToGetTransactionHash } from '../../src/errors';
import { mockChainId, mockDomain } from '../mock';

const loggingContext = {
  requestContext: mock.log.requestContext('RELAYER-TEST'),
  methodContext: mock.log.methodContext(),
};
const logger = new Logger({ name: 'test', level: process.env.LOG_LEVEL || 'silent' });
describe('Everclear Relayer', () => {
  let axiosPostStub: SinonStub;
  let axiosGetStub: SinonStub;
  let chainReaderMock: SinonStubbedInstance<ChainReader>;

  beforeEach(() => {
    axiosPostStub = stub(Mockable, 'axiosPost');
    axiosGetStub = stub(Mockable, 'axiosGet');
    chainReaderMock = createStubInstance(ChainReader, {
      getGasEstimateWithRevertCode: stub<[WriteTransaction]>().resolves('1231231231'),
    });

    stub(RelayerIndexFns, 'url').value('http://example.com');
  });

  describe('#everclearRelayerSend', () => {
    it('happy: should post data successfully', async () => {
      axiosGetStub.resolves({ data: mkAddress('0xaaa') });
      axiosPostStub.resolves({ data: { taskId: 'foo' } });
      const params: RelayerApiPostTaskRequestParams = {
        to: mkAddress(),
        data: '0xbeed',
        fee: {
          amount: '0',
          chain: mockChainId,
          token: constants.AddressZero,
        },
        apiKey: 'foo',
      };
      const res = await everclearRelayerSend(
        mockChainId,
        mockDomain.toString(),
        params.to,
        params.data,
        '0',
        'foo',
        chainReaderMock,
        logger,
        loggingContext.requestContext,
      );
      expect(axiosPostStub).to.have.been.calledOnceWithExactly(`http://example.com/relays/${mockChainId}`, params);
      expect(res).to.be.deep.eq('foo');
    });

    it('should throw if post fails', async () => {
      axiosGetStub.resolves({ data: mkAddress('0xaaa') });
      axiosPostStub.throws(new Error('Request failed!'));
      await expect(
        everclearRelayerSend(
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
      ).to.be.rejectedWith(EverclearError);
    });
  });

  describe('#getRelayerAddress', () => {
    it('happy: should get relayer address successfully', async () => {
      axiosGetStub.resolves({ data: mkAddress('0xaaa') });
      expect(await getRelayerAddress()).to.be.eq(mkAddress('0xaaa'));
    });
    it('should throw if get fails', async () => {
      axiosGetStub.throws();
      await expect(getRelayerAddress()).to.be.rejected;
    });
  });

  describe('#getTaskStatus', () => {
    it('happy should return NotFound status', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      axiosGetStub.resolves({ data: { taskId: mockTaskId } });
      expect(await getTaskStatus(mockTaskId)).to.be.eq(RelayerTaskStatus.NotFound);
    });
    it('happy should get task status successfully', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      axiosGetStub.resolves({ data: { taskId: mockTaskId, taskState: RelayerTaskStatus.CheckPending } });
      expect(await getTaskStatus(mockTaskId)).to.be.eq(RelayerTaskStatus.CheckPending);
    });
    it('should throw if fails', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      axiosGetStub.throws();
      await expect(getTaskStatus(mockTaskId)).to.be.rejectedWith(UnableToGetTaskStatus);
    });
  });

  describe('#getTransactionHash', () => {
    it('happy should return transaction hash successfully', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      const mockTxHash = mkBytes32('0xbbb');
      axiosGetStub.resolves({ data: { data: [{ transactionHash: mockTxHash }] } });
      expect(await getTransactionHash(mockTaskId)).to.be.eq(mockTxHash);
    });
    it('should throw if fails', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      axiosGetStub.throws();
      await expect(getTransactionHash(mockTaskId)).to.be.rejectedWith(UnableToGetTransactionHash);
    });
  });

  describe('#waitForTaskCompletion', () => {
    it('should timeout', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      axiosGetStub.onFirstCall().throws();
      await expect(
        waitForTaskCompletion(mockTaskId, logger, loggingContext.requestContext, 1_00, 2000),
      ).to.be.rejectedWith(TransactionHashTimeout);
    });
    it('should wait until getting finalized task status', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      axiosGetStub.onFirstCall().resolves({ data: { taskId: mockTaskId, taskState: RelayerTaskStatus.CheckPending } });
      axiosGetStub.onSecondCall().resolves({ data: { taskId: mockTaskId, taskState: RelayerTaskStatus.ExecSuccess } });
      const taskStatus = await waitForTaskCompletion(mockTaskId, logger, loggingContext.requestContext, 12_000, 200);
      expect(taskStatus).to.be.eq(RelayerTaskStatus.ExecSuccess);
    });

    it('happy: should return taskStatus successfully', async () => {
      const mockTaskId = mkBytes32('0xaaa');
      axiosGetStub.resolves({ data: { taskId: mockTaskId, taskState: RelayerTaskStatus.ExecSuccess } });
      const taskStatus = await waitForTaskCompletion(mockTaskId, logger, loggingContext.requestContext, 6_000, 200);
      expect(taskStatus).to.be.eq(RelayerTaskStatus.ExecSuccess);
    });
  });
});
