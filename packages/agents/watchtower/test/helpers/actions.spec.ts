import { stub, match, SinonStubbedInstance } from 'sinon';
import * as MockActions from '../../src/helpers/actions';
import * as MockAlerts from '../../src/helpers/alerts';

import { Logger, createRequestContext, expect, mkAddress, mkHash } from '@chimera-monorepo/utils';
import { mockAppContext } from '../globalTestHook';
import { WatcherConfig } from '../../src/lib/entities';
import { TEST_REPORT } from '../mock';
import { ChainService, ITransactionReceipt, WriteTransaction } from '@chimera-monorepo/chainservice';
import { BigNumber, Wallet, utils } from 'ethers';

/* eslint-disable  @typescript-eslint/no-explicit-any */
describe('Actions', () => {
  let domainIds: string[];

  const requestContext = createRequestContext('Actions');
  let config = {} as WatcherConfig;
  let logger: SinonStubbedInstance<Logger>;
  let chainService: SinonStubbedInstance<ChainService>;
  let wallet: SinonStubbedInstance<Wallet>;

  let mockWriteTransaction: WriteTransaction = {
    domain: 1337,
    to: mkAddress('0x1'),
    from: mkAddress('0x2'),
    data: '',
    value: '0',
  };
  let mockTransactionReceipt: ITransactionReceipt = {
    blockNumber: 123,
    transactionHash: mkHash('0x1'),
    confirmations: 1,
  };

  beforeEach(async () => {
    logger = mockAppContext.logger as SinonStubbedInstance<Logger>;
    chainService = mockAppContext.adapters.chainservice as SinonStubbedInstance<ChainService>;
    wallet = mockAppContext.adapters.wallet as SinonStubbedInstance<Wallet>;
    config = mockAppContext.config;
    domainIds = Object.keys(config.chains).concat(config.hub.domain);
  });

  afterEach(() => {});

  describe('pauseProtocol', () => {
    it('Should try to pause the protocol', async () => {
      const sendAlertsStub = stub(MockAlerts, 'sendAlerts').resolves();
      const pauseDomainStub = stub(MockActions, 'pauseDomain').resolves({
        paused: true,
        needsAction: false,
        domainId: domainIds[0],
        reason: 'test',
      });

      const results = await MockActions.pauseProtocol(TEST_REPORT, requestContext);

      expect(results).to.be.an('array').that.has.lengthOf(domainIds.length);
      expect(sendAlertsStub.callCount).to.eq(1);
      expect(pauseDomainStub.callCount).to.eq(domainIds.length);
    });

    it('Should return an array showing paused is true', async () => {
      stub(MockAlerts, 'sendAlerts').resolves();
      const pauseDomainStub = stub(MockActions, 'pauseDomain').resolves({
        paused: true,
        needsAction: false,
        domainId: domainIds[0],
        reason: 'test',
      });

      const results = await MockActions.pauseProtocol(TEST_REPORT, requestContext);
      expect(results).to.be.an('array').that.has.lengthOf(domainIds.length);
      expect(results[0]).to.be.an('object').that.has.property('paused', true);
      expect(pauseDomainStub.callCount).to.eq(domainIds.length);
    });

    it('Should throw if send alerts fails', async () => {
      stub(MockAlerts, 'sendAlerts').rejects();
      const pauseDomainStub = stub(MockActions, 'pauseDomain').resolves({
        paused: true,
        needsAction: false,
        domainId: domainIds[0],
        reason: 'test',
      });

      await expect(MockActions.pauseProtocol(TEST_REPORT, requestContext)).to.be.rejectedWith(
        'An error happened when executing pauseProtocol()',
      );
      expect(pauseDomainStub.callCount).to.eq(domainIds.length);
    });

    it('Should throw if pauseDomain fails', async () => {
      stub(MockAlerts, 'sendAlerts').resolves();
      stub(MockActions, 'pauseDomain').rejects();

      await expect(MockActions.pauseProtocol(TEST_REPORT, requestContext)).to.be.rejectedWith(
        'An error happened when executing pauseProtocol()',
      );
    });
  });

  describe('pauseDomain', async () => {
    it('Should attempt to send a transaction if domain is not paused', async () => {
      const isDomainPausedStub = stub(MockActions, 'isDomainPaused').resolves(false);
      const sendPauseDomainTxStub = stub(MockActions, 'sendPauseDomainTx').resolves({
        tx: mockWriteTransaction,
        receipt: mockTransactionReceipt,
      });

      const status = await MockActions.pauseDomain(domainIds[0], requestContext);

      expect(status).to.be.an('object').that.has.property('paused', true);
      expect(status).to.be.an('object').that.has.property('domainId', domainIds[0]);
      expect(status).to.be.an('object').that.has.property('needsAction', false);
      expect(status).to.be.an('object').that.has.property('tx', mockTransactionReceipt.transactionHash);
      expect(isDomainPausedStub.callCount).to.eq(1);
      expect(sendPauseDomainTxStub.callCount).to.eq(1);
    });

    it('Should return that the domains werent paused if the pause transaction fails', async () => {
      const isDomainPausedStub = stub(MockActions, 'isDomainPaused').resolves(false);
      const reason = `Failed to pause domain ${domainIds[0]}, transaction failed`;

      const sendPauseDomainTxStub = stub(MockActions, 'sendPauseDomainTx').rejects();

      const status = await MockActions.pauseDomain(domainIds[0], requestContext);

      expect(status).to.be.an('object').that.has.property('paused', false);
      expect(status).to.be.an('object').that.has.property('domainId', domainIds[0]);
      expect(status).to.be.an('object').that.has.property('needsAction', true);
      expect(status).to.be.an('object').that.has.property('reason', reason);
      expect(isDomainPausedStub.callCount).to.eq(1);
      expect(sendPauseDomainTxStub.callCount).to.eq(1);
      expect(logger.error.callCount).to.eq(1);
    });

    it('Should return that the protocol is already paused if it is', async () => {
      const isDomainPausedStub = stub(MockActions, 'isDomainPaused').resolves(true);
      const reason = `Skipping domain(${domainIds[0]}) pause since it is already paused`;

      const status = await MockActions.pauseDomain(domainIds[0], requestContext);

      expect(status).to.be.an('object').that.has.property('paused', false);
      expect(status).to.be.an('object').that.has.property('domainId', domainIds[0]);
      expect(status).to.be.an('object').that.has.property('needsAction', false);
      expect(status).to.be.an('object').that.has.property('reason', reason);
      expect(isDomainPausedStub.callCount).to.eq(1);
      expect(logger.info.callCount).to.eq(2);
    });

    it('Should try to make a transaction if fetching fails', async () => {
      const isDomainPausedStub = stub(MockActions, 'isDomainPaused').rejects();
      stub(MockActions, 'sendPauseDomainTx').rejects();
      const reason = `Failed to pause domain ${domainIds[0]}, transaction failed`;

      const status = await MockActions.pauseDomain(domainIds[0], requestContext);

      expect(status).to.be.an('object').that.has.property('paused', false);
      expect(status).to.be.an('object').that.has.property('domainId', domainIds[0]);
      expect(status).to.be.an('object').that.has.property('needsAction', true);
      expect(status).to.be.an('object').that.has.property('reason', reason);
      expect(isDomainPausedStub.callCount).to.eq(1);
      expect(logger.error.callCount).to.eq(1);
    });

    it('Should make a transaction if fetching fails', async () => {
      stub(MockActions, 'isDomainPaused').rejects();
      const sendPauseDomainTxStub = stub(MockActions, 'sendPauseDomainTx').resolves({
        tx: mockWriteTransaction,
        receipt: mockTransactionReceipt,
      });

      const status = await MockActions.pauseDomain(domainIds[0], requestContext);

      expect(status).to.be.an('object').that.has.property('paused', true);
      expect(status).to.be.an('object').that.has.property('domainId', domainIds[0]);
      expect(status).to.be.an('object').that.has.property('needsAction', false);
      expect(status).to.be.an('object').that.has.property('tx', mockTransactionReceipt.transactionHash);
      expect(sendPauseDomainTxStub.callCount).to.eq(1);
    });

    it('Should send extra alerts if the protocol needs manual action', async () => {
      stub(MockActions, 'isDomainPaused').rejects();
      stub(MockActions, 'sendPauseDomainTx').rejects();

      const sendAlertsStub = stub(MockAlerts, 'sendAlerts').resolves();

      const results = await MockActions.pauseProtocol(TEST_REPORT, requestContext);
      const reasons = results.map((r) => r.reason);

      expect(sendAlertsStub.callCount).to.eq(2);
      expect(sendAlertsStub.calledWith(match({ domains: domainIds, reason: reasons.join(' - '), logger: logger }))).to
        .be.true;
    });
  });

  describe('isDomainPaused', () => {
    const domainId = '1337';
    let everclear: string;
    let everclearInterface: utils.Interface;

    beforeEach(() => {
      everclear = mockAppContext.config.chains[domainId].deployments!.everclear!;
      everclearInterface = new utils.Interface([
        {
          type: 'function',
          name: 'paused',
          inputs: [],
          outputs: [{ name: '__paused', type: 'bool', internalType: 'bool' }],
          stateMutability: 'view',
        },
      ]);
    });

    it('Should return true if the domain is paused', async () => {
      // mock readTx
      const result = '0x0000000000000000000000000000000000000000000000000000000000000001';
      const readTxStub = chainService.readTx.resolves(result);

      // call
      const isPaused: boolean = await MockActions.isDomainPaused(domainId, '0x123', everclearInterface);
      expect(isPaused).to.be.true;
      expect(readTxStub.callCount).to.eq(1);
    });

    it('Should return false if the domain is not paused', async () => {
      // mock readTx
      const result = '0x0000000000000000000000000000000000000000000000000000000000000000';
      const readTxStub = chainService.readTx.resolves(result);

      // call
      const isPaused: boolean = await MockActions.isDomainPaused(domainId, '0x123', everclearInterface);
      expect(isPaused).to.be.false;
      expect(readTxStub.callCount).to.eq(1);
    });
  });

  describe('sendPauseDomainTx', () => {
    let everclear: string;
    let everclearInterface: utils.Interface;
    const gasMultiplier = 1;
    const domainId = '1337';
    const everclearAddress = '0x123';
    const from = '0x45678';

    beforeEach(() => {
      everclear = mockAppContext.config.chains[domainId].deployments!.everclear!;
      everclearInterface = new utils.Interface([
        { type: 'function', name: 'pause', inputs: [], outputs: [], stateMutability: 'nonpayable' },
      ]);
    });

    it('Should send a transaction to pause the domain', async () => {
      chainService.getGasPrice.resolves('10');
      wallet.getAddress.resolves(from);
      chainService.sendTx.resolves({
        blockNumber: 123,
        status: 1,
        transactionHash: mkHash('0x1'),
        confirmations: 10,
      } as ITransactionReceipt);

      const result = await MockActions.sendPauseDomainTx(
        everclearInterface,
        everclearAddress,
        domainId,
        gasMultiplier,
        requestContext,
      );

      expect(result.tx).to.be.deep.eq({
        to: everclearAddress,
        data: everclearInterface.encodeFunctionData('pause'),
        value: '0',
        domain: +domainId,
        from: from,
        gasPrice: '10',
        gasLimit: '100000',
      });
      expect(result.receipt).to.be.deep.eq({
        blockNumber: 123,
        confirmations: 10,
        status: 1,
        transactionHash: mkHash('0x1'),
      });
    });

    it('Should throw if tx status is returned 0', async () => {
      chainService.getGasPrice.resolves('1');
      wallet.getAddress.resolves(from);
      chainService.sendTx.resolves({
        blockNumber: 123,
        status: 0,
        transactionHash: mkHash('0x1'),
        confirmations: 10,
      } as ITransactionReceipt);

      await expect(
        MockActions.sendPauseDomainTx(everclearInterface, everclearAddress, domainId, gasMultiplier, requestContext),
      ).to.be.rejectedWith('Transaction failed with status: 0');
    });

    it('Should throw if getting the gas price fails', async () => {
      chainService.getGasPrice.rejects();

      await expect(
        MockActions.sendPauseDomainTx(everclearInterface, everclearAddress, domainId, gasMultiplier, requestContext),
      ).to.be.rejectedWith(`An error happened when executing sendPauseDomainTx(${domainId})`);
    });

    it('Should throw if getting the address fails', async () => {
      chainService.getGasPrice.resolves('1');
      chainService.getAddress.rejects();

      await expect(
        MockActions.sendPauseDomainTx(everclearInterface, everclearAddress, domainId, gasMultiplier, requestContext),
      ).to.be.rejectedWith(`An error happened when executing sendPauseDomainTx(${domainId})`);
    });
  });
});
