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

// keccak256('function processIntentQueueViaRelayer(uint32 _domain, Intent[] memory _intents, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _dynamicGasLimit)')
export const PROCESS_INTENT_VIA_RELAYER_TYPEHASH = '0xf3f51acca0066ef7defe3ea640de2b9e07d96fade5fb959604a014440ab3d7cc';

// keccak256('function processFillQueueViaRelayer(uint32 _domain, uint32 _amount, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _dynamicGasLimit)')
export const PROCESS_FILL_VIA_RELAYER_TYPEHASH = '0xce1faaeef1bc26cbe90f4e1a23cfed5940bbac04f28982812ae07a8d0ad23c39';

export const PROCESS_SETTLEMENT_VIA_RELAYER_TYPEHASH =
  '0x9ee676d393dd5facc07ae4ba72101da49596c33d1358807aba1cc4687c098eb9';
