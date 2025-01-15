import { HyperlaneStatus, hexDataLength } from 'ethers/lib/utils';
import { QueueType, expect } from '@chimera-monorepo/utils';

import { getQueueMessageBody } from '../../../src/tasks/helpers';
import { UnknownQueueType } from '../../../src/errors';

describe('Helpers:hyperlane', () => {
  const size = 3;
  const id = '0xfdaf9c934754a7ae3e88f8d74597fa5539621b99f69bfccba4171378c1df3d54';

  // src: https://dashboard.tenderly.co/tx/sepolia/0xdbb7d644174f91313c4bc01c952b5f2eb6a949904cf90cd5291537a6e79317d8?trace=0.2.1.0.1
  const body = '0x48656c6c6f2c20776f726c64';
  const recipient = '0xedc1a3edf87187085a3abb7a9a65e1e7ae370c07';
  const destination = 97;
  const nonce = 740680;
  const origin = 11155111;
  const sender = '0xcb8eca4ab47c7dc89bc455271a0650f66e0dae6e';
  const message = {
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

  describe('#getQueueMessageBody', () => {
    it('should throw if unrecognized type', async () => {
      expect(() => getQueueMessageBody('foo' as any, size)).to.throw(UnknownQueueType);
    });

    it('should work for settlements', async () => {
      const ret = getQueueMessageBody(QueueType.Settlement, size);
      expect(hexDataLength(ret)).to.be.eq(1 + 128 * size);
    });
  });
});
