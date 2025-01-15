import { QueueType } from '@chimera-monorepo/utils';
import { UnknownQueueType } from '../../errors';

export const getQueueMethodName = (type: QueueType) => {
  switch (type) {
    case 'INTENT':
      return 'processIntentQueueViaRelayer';
    case 'FILL':
      return 'processFillQueueViaRelayer';
    case 'SETTLEMENT':
      return 'processSettlementQueueViaRelayer';
    default:
      throw new UnknownQueueType(type);
  }
};

export const getTypeHash = (type: QueueType): string => {
  switch (type) {
    case 'INTENT':
      return PROCESS_INTENT_VIA_RELAYER_TYPEHASH;
    case 'FILL':
      return PROCESS_FILL_VIA_RELAYER_TYPEHASH;
    case 'SETTLEMENT':
      return PROCESS_SETTLEMENT_VIA_RELAYER_TYPEHASH;
    default:
      throw new UnknownQueueType(type);
  }
};

export const PROCESS_INTENT_VIA_RELAYER_TYPEHASH = '0x8104c8a42e1531612796e696e327ea52a475d9583ee6d64ffdefcafad22c0b24';

export const PROCESS_FILL_VIA_RELAYER_TYPEHASH = '0x0afae807991f914b71165fd92589f1dc28648cb9fb1f8558f3a6c7507d56deff';

export const PROCESS_SETTLEMENT_VIA_RELAYER_TYPEHASH =
  '0x9ee676d393dd5facc07ae4ba72101da49596c33d1358807aba1cc4687c098eb9';
