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

// keccak256('function processIntentQueueViaRelayer(uint32 _domain, Intent[] memory _intents, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _dynamicGasLimit, bytes memory _signature)')
export const PROCESS_INTENT_VIA_RELAYER_TYPEHASH = '0x87c42ffc42ddf0cd52b5e8a0b1fa6c45338db7d6e7c93f9d2943eb42b2706aca';

// keccak256('function processFillQueueViaRelayer(uint32 _domain, uint32 _amount, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _dynamicGasLimit, bytes memory _signature)')
export const PROCESS_FILL_VIA_RELAYER_TYPEHASH = '0xfff2306b4d1a2b16ba8a4ba32d8ed8136d2cc882aea58ada6b2baedcde647f57';

export const PROCESS_SETTLEMENT_VIA_RELAYER_TYPEHASH =
  '0x9ee676d393dd5facc07ae4ba72101da49596c33d1358807aba1cc4687c098eb9';
