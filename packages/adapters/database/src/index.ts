import {
  jsonifyError,
  OriginIntent,
  DestinationIntent,
  Asset,
  Balance,
  Message,
  Depositor,
  Queue,
  Token,
  Logger,
  QueueType,
  TIntentStatus,
  HubIntent,
  QueueContents,
  Invoice,
  HubInvoice,
  HubDeposit,
  SettlementIntent,
  ShadowEvent,
  Vote,
  TokenomicsEvent,
  MerkleTree,
  Reward,
  EpochResult,
  NewLockPositionEvent,
  LockPosition,
} from '@chimera-monorepo/utils';
import { Pool } from 'pg';
import { TxnClientForRepeatableRead } from 'zapatos/db';

import {
  saveOriginIntents,
  saveDestinationIntents,
  saveSettlementIntents,
  saveDepositors,
  saveBalances,
  saveMessages,
  saveQueues,
  saveCheckPoint,
  saveAssets,
  saveTokens,
  getTokens,
  saveHubInvoices,
  getCheckPoint,
  getMessageQueues,
  getMessageQueueContents,
  getAllQueuedSettlements,
  saveHubIntents,
  getOriginIntentsByStatus,
  getDestinationIntentsByStatus,
  getMessagesByIntentIds,
  getMessagesByStatus,
  getExpiredIntents,
  getOpenTransfers,
  getHubInvoices,
  getAssets,
  refreshIntentsView,
  refreshInvoicesView,
  saveHubDeposits,
  getAllEnqueuedDeposits,
  getMessagesByIds,
  updateMessageStatus,
  getHubIntentsByStatus,
  getInvoicesByStatus,
  getHubInvoicesByIntentIds,
  getOriginIntentsById,
  getLatestInvoicesByTickerHash,
  getLatestHubInvoicesByTickerHash,
  getLatestTimestamp,
  getShadowEvents,
  getVotes,
  getTokenomicsEvents,
  getSettledIntentsInEpoch,
  saveMerkleTrees,
  saveRewards,
  saveEpochResults,
  getMerkleTrees,
  getLatestMerkleTree,
  getNewLockPositionEvents,
  getLockPositions,
  saveLockPositions,
} from './client';
import { hub_intents, intent_status, message_status } from 'zapatos/schema';

export * as db from 'zapatos/db';

export type Checkpoints = {
  prefix: string;
  checkpoints: { domain: string; checkpoint: number }[];
};

export type IntentMessageUpdate = {
  id: string;
  messageId: string;
  status: TIntentStatus;
};

export type Database = {
  saveOriginIntents: (originIntents: OriginIntent[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  saveDestinationIntents: (
    destinationIntents: DestinationIntent[],
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<void>;
  saveSettlementIntents: (
    setttlementIntents: SettlementIntent[],
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<void>;
  saveHubIntents: (
    hubIntents: HubIntent[],
    _updateColumns: hub_intents.Column[],
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<void>;
  saveHubInvoices: (hubInvoices: HubInvoice[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  saveHubDeposits: (deposits: HubDeposit[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  getAllEnqueuedDeposits: (domains: string[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<HubDeposit[]>;
  saveMessages: (
    messages: Message[],
    originUpdates: IntentMessageUpdate[],
    destinationUpdates: IntentMessageUpdate[],
    hubUpdates: (IntentMessageUpdate & { settlementDomain: string })[],
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<void>;
  saveQueues: (queues: Queue[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  saveAssets: (assets: Asset[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  saveTokens: (tokens: Token[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  saveDepositors: (depositors: Depositor[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  saveBalances: (balances: Balance[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  saveCheckPoint: (check: string, point: number, _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  getCheckPoint: (check: string, _pool?: Pool | TxnClientForRepeatableRead) => Promise<number>;
  getMessageQueues: (type: QueueType, domains: string[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<Queue[]>;
  getMessageQueueContents: <T extends QueueType>(
    type: T,
    domains: string[],
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<Map<string, QueueContents[T][]>>;
  getMessagesByIds: (ids: string[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<Message[]>;
  getMessagesByStatus: (
    status: message_status[],
    offset: number,
    limit: number,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<Message[]>;
  updateMessageStatus: (
    messageId: string,
    status: message_status,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<void>;
  // FIXME: used by monitor, should be removed and used with above queue functions
  getAllQueuedSettlements: (
    domain: string,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<Map<string, HubIntent[]>>;
  getOriginIntentsByStatus: (
    status: intent_status,
    domains: string[],
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<OriginIntent[]>;
  getDestinationIntentsByStatus: (
    status: intent_status,
    domains: string[],
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<DestinationIntent[]>;
  getMessagesByIntentIds: (ids: string[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<Message[]>;
  getExpiredIntents: (
    hubDomain: string,
    spokes: string[],
    expiryBuffer: string,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<OriginIntent[]>;
  getSettledIntentsInEpoch: (
    settlementDomain: string,
    fromTimestamp: number,
    toTimestamp: number,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<
    Map<
      string,
      {
        originIntent: OriginIntent;
        settlementIntent: SettlementIntent;
      }
    >
  >;
  getOpenTransfers: (
    chains: string[],
    startTimestamp: number,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<OriginIntent[]>;
  getHubInvoices: (ids: string[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<HubInvoice[]>;
  getAssets: (ids: string[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<Asset[]>;
  refreshIntentsView: (_pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  refreshInvoicesView: (_pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  getHubIntentsByStatus: (
    status: intent_status,
    domains: string[],
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<HubIntent[]>;
  getInvoicesByStatus: (status: intent_status, _pool?: Pool | TxnClientForRepeatableRead) => Promise<Invoice[]>;
  getHubInvoicesByIntentIds: (intentIds: string[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<HubInvoice[]>;
  getOriginIntentsById: (id: string, _pool?: Pool | TxnClientForRepeatableRead) => Promise<OriginIntent | undefined>;
  getLatestInvoicesByTickerHash: (
    tickerHashes: string[],
    status: TIntentStatus[],
    limit: number,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<Map<string, Invoice[]>>; // `limit` records keyed on `tickerHash`
  getLatestHubInvoicesByTickerHash: (
    tickerHashes: string[],
    limit: number,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<Map<string, HubInvoice[]>>; // `limit` records keyed on `tickerHash`
  getTokens: (tickerHashes: string[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<Token[]>;
  getLatestTimestamp: (
    tables: string[],
    timestampColumnName: string,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<Date>;
  getShadowEvents: (
    table: string,
    from: Date,
    limit: number,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<ShadowEvent[]>;
  getVotes: (epoch: number, _pool?: Pool | TxnClientForRepeatableRead) => Promise<Vote[]>;
  getTokenomicsEvents: (
    table: string,
    from: Date,
    limit: number,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<TokenomicsEvent[]>;
  getMerkleTrees: (epochEnd: number, _pool?: Pool | TxnClientForRepeatableRead) => Promise<MerkleTree[]>;
  getLatestMerkleTree: (asset: string, epochEndMillis: number, _pool?: Pool | TxnClientForRepeatableRead) => Promise<MerkleTree[]>;
  saveMerkleTrees: (merkleTree: MerkleTree[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  saveRewards: (rewards: Reward[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  saveEpochResults: (epochResult: EpochResult[], _pool?: Pool | TxnClientForRepeatableRead) => Promise<void>;
  getNewLockPositionEvents: (
    vidFrom: number,
    limit?: number,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<NewLockPositionEvent[]>;
  getLockPositions: (
    user?: string,
    expiryFrom?: number,
    startBefore?: number,
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<LockPosition[]>;
  saveLockPositions: (
    check: string,
    point: number,
    lockPositions: LockPosition[],
    _pool?: Pool | TxnClientForRepeatableRead,
  ) => Promise<void>;
};

export let pool: Pool;

export const getDatabase = async (databaseUrl: string, logger: Logger): Promise<Database> => {
  pool = new Pool({ connectionString: databaseUrl, idleTimeoutMillis: 3000, allowExitOnIdle: true });

  // don't let a pg restart kill your app
  pool.on('error', (err: Error) => logger.error('Database error', undefined, undefined, jsonifyError(err)));

  try {
    await pool.query('SELECT NOW()');
  } catch (e: unknown) {
    logger.error('Database connection error', undefined, undefined, jsonifyError(e as Error));
    throw new Error('Database connection error');
  }
  return {
    saveOriginIntents,
    saveDestinationIntents,
    saveSettlementIntents,
    saveHubIntents,
    saveDepositors,
    saveBalances,
    saveMessages,
    saveQueues,
    saveCheckPoint,
    saveAssets,
    saveTokens,
    saveHubInvoices,
    getCheckPoint,
    getMessageQueues,
    getMessageQueueContents,
    getAllQueuedSettlements,
    getOriginIntentsByStatus,
    getDestinationIntentsByStatus,
    getMessagesByIntentIds,
    getExpiredIntents,
    getSettledIntentsInEpoch,
    getOpenTransfers,
    getHubInvoices,
    refreshIntentsView,
    refreshInvoicesView,
    saveHubDeposits,
    getAllEnqueuedDeposits,
    getAssets,
    getMessagesByIds,
    getMessagesByStatus,
    updateMessageStatus,
    getHubIntentsByStatus,
    getInvoicesByStatus,
    getHubInvoicesByIntentIds,
    getOriginIntentsById,
    getLatestInvoicesByTickerHash,
    getLatestHubInvoicesByTickerHash,
    getTokens,
    getLatestTimestamp,
    getShadowEvents,
    getVotes,
    getTokenomicsEvents,
    getMerkleTrees,
    getLatestMerkleTree,
    saveMerkleTrees,
    saveRewards,
    saveEpochResults,
    getNewLockPositionEvents,
    getLockPositions,
    saveLockPositions,
  };
};

// Overload to close the given pool as well
export const closeDatabase = async (_pool?: Pool): Promise<void> => {
  await pool.end();
  if (_pool) {
    await _pool.end();
  }
};
