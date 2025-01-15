import * as converters from './lib/converters';
import {
  OriginIntent,
  DestinationIntent,
  SettlementIntent,
  Message,
  Queue,
  Asset,
  Token,
  Balance,
  Depositor,
  QueueType,
  TIntentStatus,
  HubIntent,
  HubInvoice,
  getNtpTimeSeconds,
  QueueContents,
  HubDeposit,
  Invoice,
  MerkleTree,
  Reward,
  EpochResult,
  LockPosition,
} from '@chimera-monorepo/utils';

import { BigNumber } from 'ethers';

import * as pg from 'pg';
import { Pool } from 'pg';
import * as db from 'zapatos/db';
import type * as s from 'zapatos/schema';

import { IntentMessageUpdate, pool } from './index';

// This switches node-postgres’s JSON parsing to use the json-custom-numbers package,
//  and return as strings any values that aren’t representable as a JS number.
db.enableCustomJSONParsingForLargeNumbers(pg);

export const saveOriginIntents = async (
  _intents: OriginIntent[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const intents = _intents.map(converters.toOriginIntents);
  await db.upsert('origin_intents', intents, ['id'], { noNullUpdateColumns: ['message_id'] }).run(poolToUse);
};

export const saveDestinationIntents = async (
  _intents: DestinationIntent[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const intents = _intents.map(converters.toDestinationIntents);
  await db.upsert('destination_intents', intents, ['id'], { noNullUpdateColumns: ['message_id'] }).run(poolToUse);
};

export const saveSettlementIntents = async (
  _intents: SettlementIntent[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const intents = _intents.map(converters.toSettlementIntents);
  await db.upsert('settlement_intents', intents, ['id']).run(poolToUse);
};

export const saveHubIntents = async (
  _intents: HubIntent[],
  _updateColumns: s.hub_intents.Column[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const intents = _intents.map(converters.toHubIntents);
  await db
    .upsert('hub_intents', intents, ['id'], {
      updateColumns: _updateColumns,
      noNullUpdateColumns: ['message_id'],
    })
    .run(poolToUse);
};

export const saveHubDeposits = async (
  _deposits: HubDeposit[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const deposits = _deposits.map(converters.toHubDeposits);
  await db
    .upsert('hub_deposits', deposits, ['id'], {
      noNullUpdateColumns: ['id', 'intent_id'],
    })
    .run(poolToUse);
};

export const getAllEnqueuedDeposits = async (
  domains: string[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<HubDeposit[]> => {
  const poolToUse = _pool ?? pool;
  const result = await db
    .select('hub_deposits', {
      processed_tx_nonce: db.conditions.isNull,
      processed_timestamp: db.conditions.isNull,
      domain: db.conditions.isIn(domains),
    })
    .run(poolToUse);

  return result.map(converters.fromHubDeposits);
};

export const saveHubInvoices = async (
  _invoices: HubInvoice[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const invoices = _invoices.map(converters.toHubInvoices);
  await db
    .upsert('hub_invoices', invoices, ['id'], {
      noNullUpdateColumns: ['id'],
    })
    .run(poolToUse);
};

export const saveMessages = async (
  _messages: Message[],
  _originUpdates: IntentMessageUpdate[],
  _destinationUpdates: IntentMessageUpdate[],
  _hubUpdates: (IntentMessageUpdate & { settlementDomain: string })[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const messages = _messages.map(converters.toMessages);
  await db.upsert('messages', messages, ['id']).run(poolToUse);

  await Promise.all(
    _originUpdates.map(async (update) => {
      await db
        .update('origin_intents', { message_id: update.messageId, status: update.status }, { id: update.id })
        .run(poolToUse);
    }),
  );

  await Promise.all(
    _destinationUpdates.map(async (update) => {
      await db
        .update('destination_intents', { message_id: update.messageId, status: update.status }, { id: update.id })
        .run(poolToUse);
    }),
  );

  await Promise.all(
    _hubUpdates.map(async (update) => {
      await db
        .update(
          'hub_intents',
          { message_id: update.messageId, settlement_domain: update.settlementDomain, status: update.status },
          { id: update.id },
        )
        .run(poolToUse);
    }),
  );
};

export const saveQueues = async (_queues: Queue[], _pool?: Pool | db.TxnClientForRepeatableRead): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const queues = _queues.map(converters.toQueues);
  await db.upsert('queues', queues, ['id']).run(poolToUse);
};

export const saveAssets = async (_assets: Asset[], _pool?: Pool | db.TxnClientForRepeatableRead): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const assets = _assets.map(converters.toAssets);
  await db.upsert('assets', assets, ['id']).run(poolToUse);
};

export const getAssets = async (
  tickerHashes: string[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<Asset[]> => {
  const poolToUse = _pool ?? pool;
  const result = await db
    .select('assets', { token_id: db.conditions.isIn(tickerHashes.map((id) => id.toLowerCase())) })
    .run(poolToUse);
  return result.map(converters.fromAsset);
};

export const getHubInvoices = async (
  ids: string[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<HubInvoice[]> => {
  const poolToUse = _pool ?? pool;
  const result = await db
    .select('hub_invoices', { id: db.conditions.isIn(ids.map((id) => id.toLowerCase())) })
    .run(poolToUse);
  return result.map(converters.fromHubInvoices);
};

export const getHubInvoicesByIntentIds = async (
  intentIds: string[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<HubInvoice[]> => {
  const poolToUse = _pool ?? pool;
  const result = await db
    .select('hub_invoices', { intent_id: db.conditions.isIn(intentIds.map((id) => id.toLowerCase())) })
    .run(poolToUse);
  return result.map(converters.fromHubInvoices);
};

export const saveTokens = async (_tokens: Token[], _pool?: Pool | db.TxnClientForRepeatableRead): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const tokens = _tokens.map(converters.toTokens);
  await db.upsert('tokens', tokens, ['id']).run(poolToUse);
};

export const getTokens = async (_tokens: string[], _pool?: Pool | db.TxnClientForRepeatableRead): Promise<Token[]> => {
  const poolToUse = _pool ?? pool;
  const result = await db
    .select('tokens', { id: db.conditions.isIn(_tokens.map((t) => t.toLowerCase())) })
    .run(poolToUse);
  return result.map(converters.fromToken);
};

export const saveDepositors = async (
  _depositors: Depositor[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const depositors = _depositors.map(converters.toDepositors);
  await db.upsert('depositors', depositors, ['id']).run(poolToUse);
};

export const saveBalances = async (
  _balances: Balance[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const balances = _balances.map(converters.toBalances);
  await db.upsert('balances', balances, ['id']).run(poolToUse);
};

export const getBalancesByAccount = async (
  account: string,
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<Balance[]> => {
  const poolToUse = _pool ?? pool;
  const result = await db.select('balances', { account: account.toLowerCase() }).run(poolToUse);
  return result.map(converters.fromBalance);
};

export const saveCheckPoint = async (
  check: string,
  point: number,
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const checkpoint = { check_name: check, check_point: point };

  await db.upsert('checkpoints', checkpoint, ['check_name']).run(poolToUse);
};

export const getCheckPoint = async (
  check_name: string,
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<number> => {
  const poolToUse = _pool ?? pool;

  const result = await db.selectOne('checkpoints', { check_name }).run(poolToUse);
  return BigNumber.from(result?.check_point ?? 0).toNumber();
};

export const getMessageQueues = async (
  type: QueueType,
  domains: string[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  const result = await db.select('queues', { type, domain: db.conditions.isIn(domains) }).run(poolToUse);
  return result.map(converters.fromQueue);
};

export const getMessageQueueContents = async <T extends QueueType>(
  type: T,
  domains: string[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<Map<string, QueueContents[T][]>> => {
  const poolToUse = _pool ?? pool;
  let intents: { spoke: string }[] = [];
  if (type === 'FILL') {
    const results = await db
      .select('destination_intents', {
        filled_domain: db.conditions.isIn(domains),
        status: TIntentStatus.Added,
      })
      .run(poolToUse);
    intents = results.map((r) => ({
      ...converters.fromDestinationIntent(r),
      spoke: r.filled_domain,
    }));
  } else if (type === 'SETTLEMENT') {
    const results = await db
      .select('hub_intents', {
        settlement_domain: db.conditions.isIn(domains),
        status: TIntentStatus.Settled,
      })
      .run(poolToUse);
    intents = results.map((r) => ({
      ...converters.fromHubIntent(r),
      spoke: r.settlement_domain!,
    }));
  } else if (type === 'INTENT') {
    const results = await db
      .select('origin_intents', {
        origin: db.conditions.isIn(domains),
        status: TIntentStatus.Added,
      })
      .run(poolToUse);
    intents = results.map((r) => ({
      ...converters.fromOriginIntent(r),
      spoke: r.origin,
    }));
  } else {
    throw new Error('Unsupported message queue type: ' + type);
  }
  const map = new Map<string, QueueContents[T][]>();
  domains.forEach((domain) => {
    const relevant = intents.filter((i) => i.spoke === domain);
    const toStore = relevant.map((r) => {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { spoke, ...rest } = r;
      return rest;
    }) as QueueContents[T][];
    map.set(domain, toStore);
  });
  return map;
};

// Should return only intents inserted into the settlement queue
export const getAllQueuedSettlements = async (
  domain: string,
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<Map<string, HubIntent[]>> => {
  const poolToUse = _pool ?? pool;
  const destinationMap = new Map<string, HubIntent[]>();

  const results = await db.select('hub_intents', { domain, status: TIntentStatus.Settled }).run(poolToUse);
  const hubIntents = results.map(converters.fromHubIntent);

  for (const h of hubIntents) {
    if (!h.settlementDomain) continue;
    if (!destinationMap.has(h.settlementDomain)) {
      destinationMap.set(h.settlementDomain, []);
    }

    destinationMap.get(h.settlementDomain)!.push(h);
  }
  return destinationMap;
};

export const getOriginIntentsByStatus = async (
  status: s.intent_status,
  origins: string[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  const result = await db.select('origin_intents', { origin: db.conditions.isIn(origins), status }).run(poolToUse);
  return result.map(converters.fromOriginIntent);
};

export const getOriginIntentsById = async (id: string, _pool?: Pool | db.TxnClientForRepeatableRead) => {
  const poolToUse = _pool ?? pool;
  const result = await db.selectOne('origin_intents', { id }).run(poolToUse);
  return result ? converters.fromOriginIntent(result) : undefined;
};

export const getDestinationIntentsByStatus = async (
  status: s.intent_status,
  destinations: string[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  const result = await db
    .select('destination_intents', { filled_domain: db.conditions.isIn(destinations), status })
    .run(poolToUse);
  return result.map(converters.fromDestinationIntent);
};

export const getHubIntentsByStatus = async (
  status: s.intent_status,
  domains: string[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  const result = await db.select('hub_intents', { domain: db.conditions.isIn(domains), status }).run(poolToUse);
  return result.map(converters.fromHubIntent);
};

export const getInvoicesByStatus = async (status: s.intent_status, _pool?: Pool | db.TxnClientForRepeatableRead) => {
  const poolToUse = _pool ?? pool;
  const result = await db.select('invoices', { hub_status: status }).run(poolToUse);
  return result.map(converters.fromInvoices);
};

export const getSettlementIntentsByStatus = async (
  status: s.intent_status,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  const result = await db.select('settlement_intents', { status }).run(poolToUse);
  return result.map(converters.fromSettlementIntents);
};

export const getMessagesByIntentIds = async (intentIds: string[], _pool?: Pool | db.TxnClientForRepeatableRead) => {
  const poolToUse = _pool ?? pool;
  const result = await db.sql<s.messages.SQL>`
    SELECT * 
      FROM ${'messages'} 
      WHERE ${'intent_ids'}::text[] && ${db.param(intentIds)}
  `.run(poolToUse);
  return result.map(converters.fromMessages);
};

export const getMessagesByIds = async (ids: string[], _pool?: Pool | db.TxnClientForRepeatableRead) => {
  const poolToUse = _pool ?? pool;
  const result = await db.select('messages', { id: db.conditions.isIn(ids) }).run(poolToUse);
  return result.map(converters.fromMessages);
};

export const getMessagesByStatus = async (
  status: s.message_status[],
  offset: number,
  limit: number,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  const result = await db
    .select(
      'messages',
      { message_status: db.conditions.isIn(status) },
      { offset, limit, order: { by: 'timestamp', direction: 'ASC' } },
    )
    .run(poolToUse);
  return result.map(converters.fromMessages);
};

export const updateMessageStatus = async (
  messageId: string,
  status: s.message_status,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  await db.update('messages', { message_status: status }, { id: messageId }).run(poolToUse);
};

export const getExpiredIntents = async (
  hubDomain: string,
  spokes: string[],
  expiryBuffer: string,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  // Calculate the most recent timestamp that could be expired
  const time = getNtpTimeSeconds();
  const ceil = time - Number(expiryBuffer);
  const result = await db
    .select('intents', {
      hub_status: db.conditions.isIn([TIntentStatus.DepositProcessed]),
      hub_domain: hubDomain,
      origin_origin: db.conditions.isIn(spokes),
      origin_ttl: db.conditions.gt(0),
      origin_timestamp: db.conditions.lt(ceil),
    })
    .run(poolToUse);
  // Account for individual ttl
  const filtered = result.filter((r) => time >= +r.origin_timestamp! + +r.origin_ttl! + Number(expiryBuffer));
  return filtered.map(converters.originIntentFromIntent);
};

export const getSettledIntentsInEpoch = async (
  settlementDomain: string,
  fromTimestamp: number,
  toTimestamp: number,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  const result = await db
    .select('intents', {
      settlement_status: TIntentStatus.Settled,
      settlement_domain: settlementDomain,
      origin_timestamp: db.conditions.and(db.conditions.lt(toTimestamp), db.conditions.gte(fromTimestamp)),
    })
    .run(poolToUse);
  return new Map(
    result.map((r) => [
      r.id!,
      {
        originIntent: converters.originIntentFromIntent(r),
        settlementIntent: converters.settlementIntentFromIntent(r),
      },
    ]),
  );
};

export const getOpenTransfers = async (
  chains: string[],
  startTimestamp: number = 0,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;

  const result = await db
    .select(
      'origin_intents',
      { origin: db.conditions.isIn(chains), timestamp: db.conditions.gt(startTimestamp) },
      {
        lateral: {
          destination_intents: db.select('destination_intents', { id: db.parent('id') }),
        },
      },
    )
    .run(poolToUse);

  return result.map(converters.fromOriginIntent);
};

export const getLatestInvoicesByTickerHash = async (
  tickerHashes: string[],
  status: TIntentStatus[] = [],
  perTickerLimit: number = 10, // per-ticker
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<Map<string, Invoice[]>> => {
  const poolToUse = _pool ?? pool;

  // Get the latest hub invoices by the ticker hash
  const records = await Promise.all(
    tickerHashes.map(async (t) => {
      const where =
        status.length !== 0
          ? {
              hub_invoice_ticker_hash: t.toLowerCase(),
              hub_status: db.conditions.isIn(status),
            }
          : {
              hub_invoice_ticker_hash: t.toLowerCase(),
            };
      const ret = await db
        .select('invoices', where, {
          order: { by: 'hub_invoice_enqueued_tx_nonce', direction: 'DESC' },
          limit: perTickerLimit,
        })
        .run(poolToUse);

      return { tickerHash: t, invoices: ret.map(converters.fromInvoices) };
    }),
  );

  return new Map(records.map((r) => [r.tickerHash, r.invoices]));
};

export const getLatestHubInvoicesByTickerHash = async (
  tickerHashes: string[],
  perTickerLimit: number = 10, // per-ticker
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<Map<string, HubInvoice[]>> => {
  const poolToUse = _pool ?? pool;

  // Get the latest hub invoices by the ticker hash
  const records = await Promise.all(
    tickerHashes.map(async (t) => {
      const ret = await db
        .select(
          'hub_invoices',
          {
            ticker_hash: t.toLowerCase(),
          },
          { order: { by: 'enqueued_tx_nonce', direction: 'DESC' }, limit: perTickerLimit },
        )
        .run(poolToUse);

      return { tickerHash: t, invoices: ret.map(converters.fromHubInvoices) };
    }),
  );

  return new Map(records.map((r) => [r.tickerHash, r.invoices]));
};

export const refreshIntentsView = async (_pool?: Pool | db.TxnClientForRepeatableRead) => {
  const poolToUse = _pool ?? pool;
  await db.sql`REFRESH MATERIALIZED VIEW intents`.run(poolToUse);
};

export const refreshInvoicesView = async (_pool?: Pool | db.TxnClientForRepeatableRead) => {
  const poolToUse = _pool ?? pool;
  await db.sql`REFRESH MATERIALIZED VIEW invoices`.run(poolToUse);
};

export const getLatestTimestamp = async (
  tables: string[],
  timestampColumnName: string,
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<Date> => {
  const poolToUse = _pool ?? pool;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const promises: Promise<any[]>[] = [];
  for (const table of tables)
    promises.push(db.sql`SELECT MAX(${timestampColumnName as db.SQL}) FROM ${table as s.Table}`.run(poolToUse));
  const results = await Promise.allSettled(promises);
  let latestTimestamp = new Date(0);
  results.forEach((result) => {
    if (result.status === 'fulfilled' && result.value && result.value.length) {
      const timestamp = new Date(result.value[0].max);
      if (latestTimestamp < timestamp) latestTimestamp = timestamp;
    }
  });

  return latestTimestamp;
};

export const getShadowEvents = async (
  table: string,
  from: Date,
  limit: number = 100,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  return (
    await db
      .select(
        table as s.Table,
        {
          timestamp: db.conditions.gt(db.toString(from, 'timestamptz') as db.TimestampString),
        },
        {
          order: { by: 'timestamp', direction: 'ASC' },
          limit,
        },
      )
      .run(poolToUse)
  ).map(converters.fromShadowEvent);
};

export const getVotes = async (epoch: number, _pool?: Pool | db.TxnClientForRepeatableRead) => {
  const poolToUse = _pool ?? pool;
  return (
    await db
      .select(
        'tokenomics.vote_cast',
        {
          epoch,
        },
        {
          columns: ['domain'],
          groupBy: 'domain',
          extras: {
            // NOTE: force cast sum as TEXT as zapatos make all aggreate function returns number by default
            // see https://github.com/jawj/zapatos/issues/140
            voteCount: db.sql<s.tokenomics.vote_cast.SQL>`sum(${'votes'})::TEXT`,
          },
        },
      )
      .run(poolToUse)
  ).map(converters.fromVote);
};

export const getTokenomicsEvents = async (
  table: string,
  from: Date,
  limit: number = 100,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  return (
    await db
      .select(
        ('tokenomics.' + table) as s.Table,
        {
          insert_timestamp: db.conditions.gt(db.toString(from, 'timestamptz') as db.TimestampString),
        },
        {
          order: { by: 'insert_timestamp', direction: 'ASC' },
          limit,
        },
      )
      .run(poolToUse)
  ).map(converters.fromTokenomicsEvent);
};

export const getMerkleTrees = async (
  epochEnd: number,
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<MerkleTree[]> => {
  const poolToUse = _pool ?? pool;
  const epochTimestamp = new Date(epochEnd * 1000);
  const result = await db
    .select('merkle_trees', { epoch_end_timestamp: db.toString(epochTimestamp, 'timestamp:UTC') as db.TimestampString })
    .run(poolToUse);

  return result.map(converters.fromMerkleTree);
};

export const getLatestMerkleTree = async (
  asset: string,
  epochEndMillis: number,
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<MerkleTree[]> => {
  const poolToUse = _pool ?? pool;
  const result = await db
    .select(
      'merkle_trees',
      {
        asset,
        epoch_end_timestamp: db.conditions.gt(
          db.toString(new Date(epochEndMillis), 'timestamp:UTC') as db.TimestampString,
        ),
      },
      {
        order: { by: 'epoch_end_timestamp', direction: 'DESC' },
        limit: 1,
      },
    )
    .run(poolToUse);

  return result.map(converters.fromMerkleTree);
};

export const saveMerkleTrees = async (
  _trees: MerkleTree[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const trees = _trees.map(converters.toMerkleTree);
  await db.insert('merkle_trees', trees).run(poolToUse);
};

export const saveRewards = async (_rewards: Reward[], _pool?: Pool | db.TxnClientForRepeatableRead): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const rewards = _rewards.map(converters.toReward);
  await db.insert('rewards', rewards).run(poolToUse);
};

export const saveEpochResults = async (
  _epochResults: EpochResult[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
): Promise<void> => {
  const poolToUse = _pool ?? pool;
  const epochResults = _epochResults.map(converters.toEpochResult);
  await db.insert('epoch_results', epochResults).run(poolToUse);
};

export const getNewLockPositionEvents = async (
  vidFrom: number,
  limit: number = 100,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  return (
    await db
      .select(
        'tokenomics.new_lock_position',
        {
          vid: db.conditions.gt(vidFrom),
        },
        {
          order: { by: 'vid', direction: 'ASC' },
          limit,
        },
      )
      .run(poolToUse)
  ).map(converters.fromNewLockPositionEvent);
};

export const getLockPositions = async (
  user?: string,
  expiryFrom?: number,
  startBefore?: number,
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  let conditions = {};
  if (user) {
    conditions = { user, ...conditions };
  }
  if (expiryFrom) {
    conditions = { expiry: db.conditions.gt(expiryFrom), ...conditions };
  }
  if (startBefore) {
    conditions = { start: db.conditions.lt(startBefore), ...conditions };
  }
  return (
    await db
      .select('lock_positions', conditions, {
        order: { by: 'start', direction: 'ASC' },
      })
      .run(poolToUse)
  ).map(converters.fromLockPosition);
};

export const saveLockPositions = async (
  check: string,
  point: number,
  lockPositions: LockPosition[],
  _pool?: Pool | db.TxnClientForRepeatableRead,
) => {
  const poolToUse = _pool ?? pool;
  const toRemove = lockPositions.filter((lockPosition) => {
    return BigNumber.from(lockPosition.amountLocked).eq(BigNumber.from(0));
  });
  const toAdd = lockPositions.filter((lockPosition) => {
    return BigNumber.from(lockPosition.amountLocked).gt(BigNumber.from(0));
  });
  await db.transaction(poolToUse, db.IsolationLevel.Serializable, async (client) => {
    await saveCheckPoint(check, point, client);
    for (const pos of toRemove) {
      await db.deletes('lock_positions', { user: pos.user, start: pos.start }).run(client);
    }
    await db.upsert('lock_positions', toAdd.map(converters.toLockPosition), ['user', 'start']).run(client);
    return true;
  });
};
