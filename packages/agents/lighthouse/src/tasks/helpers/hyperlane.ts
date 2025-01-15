import { QueueType } from '@chimera-monorepo/utils';
import { hexlify, randomBytes } from 'ethers/lib/utils';
import { UnknownQueueType } from '../../errors';

const MESSAGE_IDENTIFIER_LENGTH = 1; // length of `MessageType` enum in bytes
const SETTLEMENT_MESSAGE_LENGTH = 128; // length of single settlement message data

export const getQueueMessageBody = (type: QueueType, size: number) => {
  switch (type) {
    case 'SETTLEMENT':
      return getSettlementQueueMessageBody(size);
    default:
      throw new UnknownQueueType(type);
  }
};

/**
 * Approximate the message body by generating random bytes of the same length
 * @param settlements Number of settlements to process
 * @returns Length of message
 */
const getSettlementQueueMessageBody = (settlements: number) => {
  return hexlify(randomBytes(MESSAGE_IDENTIFIER_LENGTH + SETTLEMENT_MESSAGE_LENGTH * settlements));
};
