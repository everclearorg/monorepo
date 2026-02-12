import { QueueType, SOLANA_CHAINID, setTriageToolHandlers } from '@chimera-monorepo/utils';
import { getContext } from './context';
import { getCustodiedAssetsFromHubContract, getCurrentEpoch, getLastSolanaIntentNonce, getMessageStatus } from './helpers';

const queueFamilyToType: Record<string, QueueType | undefined> = {
  intent: QueueType.Intent,
  execution: QueueType.Fill,
};

const toStringArg = (value: unknown, field: string): string => {
  if (typeof value === 'string' && value.length > 0) {
    return value;
  }
  throw new Error(`Missing required tool arg: ${field}`);
};

export const configureTriageToolHandlers = () => {
  setTriageToolHandlers({
    check_rpc_health: async (args) => {
      const domain = toStringArg(args.domain, 'domain');
      const rpcOrigin = typeof args.rpcOrigin === 'string' ? args.rpcOrigin : undefined;
      const { adapters } = getContext();
      const block = await adapters.chainreader.getBlock(+domain, 'latest');
      return {
        domain,
        rpcOrigin,
        healthy: true,
        blockNumber: block.number,
        timestamp: block.timestamp,
      };
    },
    get_gas_balance: async (args) => {
      const domain = toStringArg(args.domain, 'domain');
      const address = toStringArg(args.address, 'address');
      const { adapters } = getContext();
      const balance = await adapters.chainreader.getBalance(+domain, address);
      return {
        domain,
        address,
        balanceWei: balance.toString(),
      };
    },
    get_block_numbers: async (args) => {
      const domain = toStringArg(args.domain, 'domain');
      const { adapters } = getContext();
      const [rpcBlock, subgraphMap] = await Promise.all([
        adapters.chainreader.getBlockNumber(+domain),
        adapters.subgraph.getLatestBlockNumber([domain]),
      ]);
      return {
        domain,
        rpcBlockNumber: rpcBlock,
        subgraphBlockNumber: subgraphMap.get(domain) ?? 0,
        lagBlocks: rpcBlock - (subgraphMap.get(domain) ?? 0),
      };
    },
    get_queue_depth: async (args) => {
      const queueFamily = toStringArg(args.queueFamily, 'queueFamily').toLowerCase();
      const domain = toStringArg(args.domain, 'domain');
      const { adapters, config } = getContext();
      if (queueFamily === 'deposit') {
        const deposits = await adapters.database.getAllEnqueuedDeposits([domain]);
        return {
          queueFamily,
          domain,
          depth: deposits.length,
          oldestTimestamp: deposits.reduce((min, deposit) => {
            if (deposit.enqueuedTimestamp === 0) return min;
            return min === 0 ? deposit.enqueuedTimestamp : Math.min(min, deposit.enqueuedTimestamp);
          }, 0),
        };
      }
      if (queueFamily === 'settlement') {
        const settlements = await adapters.database.getAllQueuedSettlements(config.hub.domain);
        const matching = settlements.get(domain) ?? [];
        return {
          queueFamily,
          domain,
          depth: matching.length,
          oldestTimestamp: matching.reduce((min, settlement) => {
            const ts = settlement.settlementEnqueuedTimestamp ?? 0;
            if (ts === 0) return min;
            return min === 0 ? ts : Math.min(min, ts);
          }, 0),
        };
      }
      const queueType = queueFamilyToType[queueFamily];
      if (!queueType) {
        throw new Error(`Unsupported queue family: ${queueFamily}`);
      }
      const queueMap = await adapters.database.getMessageQueueContents(queueType, [domain]);
      const entries = queueMap.get(domain) ?? [];
      return {
        queueFamily,
        domain,
        depth: entries.length,
      };
    },
    get_custodied_balance: async (args) => {
      const assetHash = toStringArg(args.assetHash, 'assetHash');
      const balance = await getCustodiedAssetsFromHubContract(assetHash);
      return {
        assetHash,
        custodiedBalance: balance,
      };
    },
    get_current_epoch: async () => {
      const epoch = await getCurrentEpoch();
      return {
        epoch,
      };
    },
    get_hyperlane_message_status: async (args) => {
      const messageId = toStringArg(args.messageId, 'messageId');
      const status = await getMessageStatus(messageId);
      return {
        messageId,
        ...status,
      };
    },
    get_solana_nonce_status: async (args) => {
      const checkpointKey = typeof args.checkpointKey === 'string' ? args.checkpointKey : 'solana_intent_nonce';
      const { adapters } = getContext();
      const [chainNonce, localNonce, checkpoint] = await Promise.all([
        getLastSolanaIntentNonce(),
        adapters.database.getOriginIntentsLastNonce(SOLANA_CHAINID),
        adapters.database.getCheckPoint(checkpointKey),
      ]);
      return {
        chainNonce,
        localNonce,
        checkpoint,
        isDelayed: chainNonce !== localNonce,
      };
    },
  });
};
