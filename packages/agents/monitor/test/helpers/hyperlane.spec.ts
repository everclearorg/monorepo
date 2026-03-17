import { SinonStub, SinonStubbedInstance, stub } from 'sinon';
import { expect, HyperlaneMessageResponse, HyperlaneStatus, Message, mkHash, chainWrapper, POLYMER_DOMAIN_PAIRS } from '@chimera-monorepo/utils';
import * as Mockable from '../../src/mockable';

import { getDispatchedMessage, getDispatchedMessageFromEvent, getMessageStatus } from '../../src/helpers';
import { NoDispatchEventOnMessage, NoGatewayConfigured } from '../../src/types';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { Database } from '@chimera-monorepo/database';
import { mock } from '../globalTestHook';

describe('Helpers:hyperlane', () => {
  const id = '0xfdaf9c934754a7ae3e88f8d74597fa5539621b99f69bfccba4171378c1df3d54';

  // src: https://dashboard.tenderly.co/tx/sepolia/0xdbb7d644174f91313c4bc01c952b5f2eb6a949904cf90cd5291537a6e79317d8?trace=0.2.1.0.1
  const body = '0x48656c6c6f2c20776f726c64';
  const recipient = '0xedc1a3edf87187085a3abb7a9a65e1e7ae370c07';
  const destination = 97;
  const nonce = 740680;
  const origin = 11155111;
  const sender = '0xcb8eca4ab47c7dc89bc455271a0650f66e0dae6e';
  const message: HyperlaneMessageResponse = {
    id,
    originMailbox: '',
    status: 'pending' as HyperlaneStatus,
    destinationDomainId: destination,
    body,
    originDomainId: origin,
    recipient,
    sender,
    nonce,
  };
  const expected =
    '0x03000b4d4800aa36a7000000000000000000000000cb8eca4ab47c7dc89bc455271a0650f66e0dae6e00000061000000000000000000000000edc1a3edf87187085a3abb7a9a65e1e7ae370c0748656c6c6f2c20776f726c64';

  let getHyperlaneMessageStatusStub: SinonStub;
  let chainreader: SinonStubbedInstance<ChainReader>;
  let decodeStub: SinonStub;
  let database: SinonStubbedInstance<Database>;
  let encodeStub: SinonStub;
  let decodeEventLogStub: SinonStub;

  describe('#getMessageStatus', () => {
    beforeEach(() => {
      getHyperlaneMessageStatusStub = stub(Mockable, 'getHyperlaneMessageStatus').resolves(message);
      chainreader = mock.context().adapters.chainreader as SinonStubbedInstance<ChainReader>;

      // Mock readTx for mailbox call (first call) and delivered call (second call)
      chainreader.readTx
        .onFirstCall().resolves('0x1234') // mailbox call
        .onSecondCall().resolves('0x0000000000000000000000000000000000000000000000000000000000000000'); // delivered call (false)
      chainreader.getGasEstimateWithRevertCode.resolves('0');
      chainreader.getTransactionReceipt.resolves({
        transactionHash: mkHash('0xtx'),
        logs: [{ topics: [mkHash('0xtopic')] }],
      } as any);

      encodeStub = stub(chainWrapper, 'encodeFunctionData').returns('0x1234' as `0x${string}`);
      // Mock decodeFunctionResult: first call returns mailbox address, second call returns delivered boolean
      decodeStub = stub(chainWrapper, 'decodeFunctionResult')
        .onFirstCall().returns('0x1234' as `0x${string}`) // mailbox address
        .onSecondCall().returns(false); // delivered boolean
      decodeEventLogStub = stub(chainWrapper, 'decodeEventLog').returns({ args: { message: message.body } } as any);

      database = mock.instances.database() as SinonStubbedInstance<Database>;
    });

    it('should handle fail if axios fails', async () => {
      // If readTx fails, it will throw and status will be 'none' if no messages
      chainreader.readTx.rejects(new Error('RPC error'));
      expect(await getMessageStatus(id)).to.be.deep.eq({ status: 'none' });
    });

    it('should handle when no messages returned', async () => {
      database.getMessagesByIds.resolves([]);
      expect(await getMessageStatus(id)).to.be.deep.eq({ status: 'none' });
    });

    it('should handle when message is delivered', async () => {
      database.getMessagesByIds.resolves([mock.message()]);
      // Mock delivered call to return true
      chainreader.readTx
        .onFirstCall().resolves('0x1234') // mailbox call
        .onSecondCall().resolves('0x0000000000000000000000000000000000000000000000000000000000000001'); // delivered call (true)
      decodeStub
        .onFirstCall().returns('0x1234' as `0x${string}`) // mailbox address
        .onSecondCall().returns(true); // delivered boolean
      expect(await getMessageStatus(id)).to.be.deep.eq({ status: 'delivered' });
    });

    it('should fail if no gateway found for domains', async () => {
      database.getMessagesByIds.resolves([mock.message({ destinationDomain: '1111' })]);
      await expect(getMessageStatus(id)).to.be.rejectedWith(NoGatewayConfigured);
    });

    it('should fail if getting mailbox fails', async () => {
      database.getMessagesByIds.resolves([mock.message({ destinationDomain: '1111' })]);
      chainreader.readTx.rejects(new Error('fail'));
      await expect(getMessageStatus(id)).to.be.rejected;
    });

    it('should return pending if no destination domain', async () => {
      database.getMessagesByIds.resolves([mock.message({ destinationDomain: undefined })]);
      chainreader.getGasEstimateWithRevertCode.rejects(new Error('fail'));
      expect(await getMessageStatus(id)).to.be.deep.eq({ status: 'pending' });
    });

    it('should work if tx is not delivered but is relayable', async () => {
      database.getMessagesByIds.resolves([mock.message()]);
      decodeStub
        .onFirstCall().returns('0x1234' as `0x${string}`) // mailbox address
        .onSecondCall().returns(false); // delivered boolean

      const ret = await getMessageStatus(id, true);
      expect(ret).to.be.deep.eq({
        status: 'relayable',
        relayTransaction: {
          to: '0x1234',
          domain: 1338,
          data: '0x1234',
          value: '0',
          funcSig: 'process(bytes,bytes)',
        },
      });
    });

    it('should work if tx is delivered', async () => {
      database.getMessagesByIds.resolves([mock.message()]);
      // Mock delivered call to return true
      chainreader.readTx
        .onFirstCall().resolves('0x1234') // mailbox call
        .onSecondCall().resolves('0x0000000000000000000000000000000000000000000000000000000000000001'); // delivered call (true)
      decodeStub
        .onFirstCall().returns('0x1234' as `0x${string}`) // mailbox address
        .onSecondCall().returns(true); // delivered boolean
      const ret = await getMessageStatus(id);
      expect(ret).to.be.deep.eq({
        status: 'delivered',
      });
    });

    it('should return delivered for polymer route when polymer API confirms delivery', async () => {
      const [polymerOrigin, polymerDest] = POLYMER_DOMAIN_PAIRS[0]; // e.g. ['1', '25327']
      database.getMessagesByIds.resolves([mock.message({ originDomain: polymerOrigin, destinationDomain: polymerDest })]);
      const getPolymerMsgDeliveredStub = stub(Mockable, 'getPolymerMsgDelivered').resolves(HyperlaneStatus.delivered);
      expect(await getMessageStatus(id)).to.be.deep.eq({ status: 'delivered' });
      expect(getPolymerMsgDeliveredStub.calledOnceWith(id)).to.be.true;
    });

    it('should return pending for polymer route when polymer API returns pending', async () => {
      const [polymerOrigin, polymerDest] = POLYMER_DOMAIN_PAIRS[0];
      database.getMessagesByIds.resolves([mock.message({ originDomain: polymerOrigin, destinationDomain: polymerDest })]);
      stub(Mockable, 'getPolymerMsgDelivered').resolves(HyperlaneStatus.pending);
      expect(await getMessageStatus(id)).to.be.deep.eq({ status: 'pending' });
    });

    it('should return pending for polymer route when polymer API throws', async () => {
      const [polymerOrigin, polymerDest] = POLYMER_DOMAIN_PAIRS[0];
      database.getMessagesByIds.resolves([mock.message({ originDomain: polymerOrigin, destinationDomain: polymerDest })]);
      stub(Mockable, 'getPolymerMsgDelivered').rejects(new Error('Polymer API error'));
      expect(await getMessageStatus(id)).to.be.deep.eq({ status: 'pending' });
    });

    it('should work if hyperlane api fails (derives from chain)', async () => {
      getHyperlaneMessageStatusStub.resolves(undefined);
      database.getMessagesByIds.resolves([mock.message()]);

      chainreader.getTransactionReceipt.resolves({
        transactionHash: mkHash('0xtx'),
        logs: [{ 
          topics: ['0x3d0c9a00', mkHash('0xtopic')],
          data: '0x1234'
        }],
      } as any);

      const ret = await getMessageStatus(id, true);
      expect(ret.status).to.be.eq('relayable');
      expect(ret.relayTransaction).to.be.deep.eq({
        to: '0x1234',
        data: '0x1234',
        domain: +mock.message().destinationDomain!,
        value: '0',
        funcSig: 'process(bytes,bytes)',
      });
    });
  });

  describe('#getDispatchedMessage', () => {
    it('should work', async () => {
      expect(getDispatchedMessage(message)).to.be.eq(expected);
    });
  });

  describe('#getDispatchedMessageFromEvent', () => {
    const originMessage = {
      originDomain: message.originDomainId.toString(),
      transactionHash: mkHash('0xtx'),
    } as unknown as Message;

    beforeEach(() => {
      chainreader = mock.context().adapters.chainreader as SinonStubbedInstance<ChainReader>;
      chainreader.getTransactionReceipt.resolves({
        transactionHash: originMessage.transactionHash,
        logs: [{ 
          topics: ['0x3d0c9a00', mkHash('0xtopic')],
          data: '0x1234'
        }],
      } as any);
      
      decodeEventLogStub = stub(chainWrapper, 'decodeEventLog').returns({ args: { message: message.body } } as any);
    });

    it('should throw if cannot find Dispatch event', async () => {
      chainreader.getTransactionReceipt.resolves({ transactionHash: originMessage.transactionHash, logs: [] } as any);
      await expect(getDispatchedMessageFromEvent(originMessage)).to.be.rejectedWith(NoDispatchEventOnMessage);
    });

    it('should work', async () => {
      const body = await getDispatchedMessageFromEvent(originMessage);
      expect(body).to.be.eq(message.body);
    });
  });
});
