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
  HubIntent,
  Invoice,
  HubInvoice,
  HubDeposit,
  DepositQueue,
  HyperlaneStatus,
  TIntentStatus,
  ShadowEvent,
  MerkleTree,
  Vote,
  TokenomicsEvent,
  Reward,
  EpochResult,
  EarlyExitEvent,
  NewLockPositionEvent,
  LockPosition,
} from '@chimera-monorepo/utils';
import { toDate } from 'zapatos/db';
import {
  assets,
  balances,
  depositors,
  destination_intents,
  hub_intents,
  intents,
  messages,
  origin_intents,
  settlement_intents,
  queues,
  tokens,
  hub_invoices,
  hub_deposits,
  invoices,
  merkle_trees,
  rewards,
  epoch_results,
  tokenomics,
  lock_positions,
} from 'zapatos/schema';
import { db } from '..';

export function toOriginIntents(originIntent: OriginIntent): origin_intents.Insertable {
  return {
    id: originIntent.id,
    queue_idx: originIntent.queueIdx,
    message_id: originIntent.messageId,
    status: originIntent.status,
    receiver: originIntent.receiver,
    input_asset: originIntent.inputAsset,
    output_asset: originIntent.outputAsset,
    amount: originIntent.amount,
    max_fee: originIntent.maxFee.toString(),
    destinations: originIntent.destinations,
    origin: originIntent.origin,
    nonce: originIntent.nonce,
    data: originIntent.data,
    initiator: originIntent.initiator,
    ttl: originIntent.ttl,

    transaction_hash: originIntent.transactionHash,
    timestamp: originIntent.timestamp,
    block_number: originIntent.blockNumber,
    gas_limit: +originIntent.gasLimit,
    gas_price: +originIntent.gasPrice,
    tx_origin: originIntent.txOrigin,
    tx_nonce: originIntent.txNonce,
  };
}
export function fromOriginIntent(originIntent: origin_intents.JSONSelectable): OriginIntent {
  return {
    initiator: originIntent.initiator,
    id: originIntent.id,
    queueIdx: +originIntent.queue_idx,
    messageId: originIntent.message_id ?? undefined,
    status: originIntent.status as TIntentStatus,
    receiver: originIntent.receiver,
    inputAsset: originIntent.input_asset,
    outputAsset: originIntent.output_asset,
    amount: originIntent.amount,
    maxFee: +originIntent.max_fee,
    destinations: originIntent.destinations,
    origin: originIntent.origin,
    nonce: +originIntent.nonce,
    data: originIntent.data ?? '0x',
    ttl: +originIntent.ttl,

    transactionHash: originIntent.transaction_hash,
    timestamp: +originIntent.timestamp,
    blockNumber: +originIntent.block_number,
    gasLimit: String(originIntent.gas_limit),
    gasPrice: String(originIntent.gas_price),
    txOrigin: originIntent.tx_origin,
    txNonce: +originIntent.tx_nonce,
  };
}

export function originIntentFromIntent(intent: intents.JSONSelectable): OriginIntent {
  // Sanity check: origin intent has been populated in db
  if (!intent.origin_origin) {
    throw new Error(`Origin intent not found for intent ${intent.id}`);
  }
  return {
    initiator: intent.origin_initiator!,
    id: intent.id!,
    queueIdx: +intent.origin_queue_idx!,
    messageId: intent.origin_message_id ?? undefined,
    status: intent.origin_status! as TIntentStatus,
    receiver: intent.origin_receiver!,
    inputAsset: intent.origin_input_asset!,
    outputAsset: intent.origin_output_asset!,
    amount: intent.origin_amount!,
    maxFee: +intent.origin_max_fee!,
    destinations: intent.origin_destinations!,
    origin: intent.origin_origin!,
    nonce: +intent.origin_nonce!,
    data: intent.origin_data ?? '0x',
    ttl: +intent.origin_ttl!,

    transactionHash: intent.origin_transaction_hash!,
    timestamp: +intent.origin_timestamp!,
    blockNumber: +intent.origin_block_number!,
    gasLimit: String(intent.origin_gas_limit!),
    gasPrice: String(intent.origin_gas_price!),
    txOrigin: intent.origin_tx_origin!,
    txNonce: +intent.origin_tx_nonce!,
  };
}

export function settlementIntentFromIntent(intent: intents.JSONSelectable): SettlementIntent {
  if (!intent.settlement_amount) {
    throw new Error(`Settlement intent not found for intent ${intent.id}`);
  }
  return {
    intentId: intent.id!,
    amount: intent.settlement_amount!,
    asset: intent.settlement_asset!,
    recipient: intent.settlement_recipient!,
    domain: intent.settlement_domain!,
    status: intent.settlement_status as TIntentStatus,

    transactionHash: intent.settlement_transaction_hash!,
    timestamp: +intent.settlement_timestamp!,
    blockNumber: +intent.settlement_block_number!,
    txOrigin: intent.settlement_tx_origin!,
    txNonce: +intent.settlement_tx_nonce!,
    gasLimit: String(intent.settlement_gas_limit),
    gasPrice: String(intent.settlement_gas_price),
  }
}

export function toSettlementIntents(settlementIntent: SettlementIntent): settlement_intents.Insertable {
  return {
    id: settlementIntent.intentId,
    amount: settlementIntent.amount,
    asset: settlementIntent.asset,
    recipient: settlementIntent.recipient,
    domain: settlementIntent.domain,
    status: settlementIntent.status,
    return_data: settlementIntent.returnData,

    transaction_hash: settlementIntent.transactionHash,
    timestamp: settlementIntent.timestamp,
    block_number: settlementIntent.blockNumber,
    tx_origin: settlementIntent.txOrigin,
    tx_nonce: settlementIntent.txNonce,
    gas_limit: +settlementIntent.gasLimit,
    gas_price: +settlementIntent.gasPrice,
  };
}

export function fromSettlementIntents(record: settlement_intents.JSONSelectable): SettlementIntent {
  return {
    intentId: record.id,
    amount: record.amount,
    asset: record.asset,
    recipient: record.recipient,
    domain: record.domain,
    status: record.status as TIntentStatus,
    returnData: record.return_data ?? undefined,

    transactionHash: record.transaction_hash,
    timestamp: +record.timestamp,
    blockNumber: +record.block_number,
    txOrigin: record.tx_origin,
    txNonce: +record.tx_nonce,
    gasLimit: String(record.gas_limit),
    gasPrice: String(record.gas_price),
  };
}

export function toDestinationIntents(destinationIntent: DestinationIntent): destination_intents.Insertable {
  return {
    id: destinationIntent.id,
    queue_idx: destinationIntent.queueIdx,
    message_id: destinationIntent.messageId,
    status: destinationIntent.status,
    initiator: destinationIntent.initiator,
    receiver: destinationIntent.receiver,
    solver: destinationIntent.solver,
    input_asset: destinationIntent.inputAsset,
    output_asset: destinationIntent.outputAsset,
    amount: destinationIntent.amount,
    fee: destinationIntent.fee,
    origin: destinationIntent.origin,
    destinations: destinationIntent.destinations,
    filled_domain: destinationIntent.destination,
    nonce: destinationIntent.nonce,
    data: destinationIntent.data,
    max_fee: destinationIntent.maxFee.toString(),
    ttl: destinationIntent.ttl,
    return_data: destinationIntent.returnData,

    transaction_hash: destinationIntent.transactionHash,
    timestamp: destinationIntent.timestamp,
    block_number: destinationIntent.blockNumber,
    gas_limit: +destinationIntent.gasLimit,
    gas_price: +destinationIntent.gasPrice,
    tx_origin: destinationIntent.txOrigin,
    tx_nonce: destinationIntent.txNonce,
  };
}

export function fromDestinationIntent(destinationIntent: destination_intents.JSONSelectable): DestinationIntent {
  return {
    id: destinationIntent.id,
    queueIdx: +destinationIntent.queue_idx,
    messageId: destinationIntent.message_id ?? undefined,
    status: destinationIntent.status as TIntentStatus,
    initiator: destinationIntent.initiator,
    receiver: destinationIntent.receiver,
    solver: destinationIntent.solver,
    inputAsset: destinationIntent.input_asset,
    outputAsset: destinationIntent.output_asset,
    amount: destinationIntent.amount,
    fee: destinationIntent.fee,
    origin: destinationIntent.origin,
    destinations: destinationIntent.destinations,
    destination: destinationIntent.filled_domain,
    nonce: +destinationIntent.nonce,
    data: destinationIntent.data ?? '0x',
    maxFee: +destinationIntent.max_fee,
    ttl: +destinationIntent.ttl,
    returnData: destinationIntent.return_data ?? undefined,

    transactionHash: destinationIntent.transaction_hash,
    timestamp: +destinationIntent.timestamp,
    blockNumber: +destinationIntent.block_number,
    gasLimit: String(destinationIntent.gas_limit),
    gasPrice: String(destinationIntent.gas_price),
    txOrigin: destinationIntent.tx_origin,
    txNonce: +destinationIntent.tx_nonce,
  };
}

export function toHubIntents(hubIntent: HubIntent): hub_intents.Insertable {
  return {
    id: hubIntent.id,
    status: hubIntent.status,
    domain: hubIntent.domain,
    queue_idx: hubIntent.queueIdx ?? undefined,
    message_id: hubIntent.messageId ?? undefined,
    settlement_domain: hubIntent.settlementDomain ?? undefined,
    settlement_amount: hubIntent.settlementAmount ?? undefined,

    added_timestamp: hubIntent.addedTimestamp ?? undefined,
    added_tx_nonce: hubIntent.addedTxNonce ?? undefined,
    filled_timestamp: hubIntent.filledTimestamp ?? undefined,
    filled_tx_nonce: hubIntent.filledTxNonce ?? undefined,
    settlement_enqueued_timestamp: hubIntent.settlementEnqueuedTimestamp ?? undefined,
    settlement_enqueued_tx_nonce: hubIntent.settlementEnqueuedTxNonce ?? undefined,
    settlement_enqueued_block_number: hubIntent.settlementEnqueuedBlockNumber ?? undefined,
    settlement_epoch: hubIntent.settlementEpoch ?? undefined,
    update_virtual_balance: hubIntent.updateVirtualBalance ?? undefined,
  };
}

export function fromHubIntent(hubIntent: hub_intents.JSONSelectable): HubIntent {
  return {
    id: hubIntent.id,
    status: hubIntent.status as TIntentStatus,
    domain: hubIntent.domain,
    queueIdx: hubIntent.queue_idx ? +hubIntent.queue_idx : undefined,
    messageId: hubIntent.message_id ?? undefined,
    settlementDomain: hubIntent.settlement_domain ?? undefined,
    settlementAmount: (hubIntent.settlement_amount ?? undefined) as `${number}` | undefined,

    addedTimestamp: hubIntent.added_timestamp ? +hubIntent.added_timestamp : undefined,
    addedTxNonce: hubIntent.added_tx_nonce ? +hubIntent.added_tx_nonce : undefined,
    filledTimestamp: hubIntent.filled_timestamp ? +hubIntent.filled_timestamp : undefined,
    filledTxNonce: hubIntent.filled_tx_nonce ? +hubIntent.filled_tx_nonce : undefined,
    settlementEnqueuedTimestamp: hubIntent.settlement_enqueued_timestamp ? +hubIntent.settlement_enqueued_timestamp : undefined,
    settlementEnqueuedTxNonce: hubIntent.settlement_enqueued_tx_nonce ? +hubIntent.settlement_enqueued_tx_nonce : undefined,
    settlementEnqueuedBlockNumber: hubIntent.settlement_enqueued_block_number ? +hubIntent.settlement_enqueued_block_number : undefined,
    settlementEpoch: hubIntent.settlement_epoch ? +hubIntent.settlement_epoch : undefined,
    updateVirtualBalance: hubIntent.update_virtual_balance ?? undefined,
  };
}

export function toHubInvoices(hubInvoice: HubInvoice): hub_invoices.Insertable {
  return {
    id: hubInvoice.id,
    intent_id: hubInvoice.intentId,
    amount: hubInvoice.amount,
    ticker_hash: hubInvoice.tickerHash,
    owner: hubInvoice.owner,
    entry_epoch: hubInvoice.entryEpoch,

    enqueued_timestamp: hubInvoice.enqueuedTimestamp,
    enqueued_tx_nonce: hubInvoice.enqueuedTxNonce,
    enqueued_block_number: hubInvoice.enqueuedBlockNumber,
    enqueued_transaction_hash: hubInvoice.enqueuedTransactionHash,
  };
}

export function fromInvoices(invoice: invoices.JSONSelectable): Invoice {
  return {
    id: invoice.hub_invoice_id!,
    originIntent: {
      initiator: invoice.origin_initiator!,
      id: invoice.id!,
      queueIdx: +invoice.origin_queue_idx!,
      messageId: invoice.origin_message_id ?? undefined,
      status: invoice.origin_status! as TIntentStatus,
      receiver: invoice.origin_receiver!,
      inputAsset: invoice.origin_input_asset!,
      outputAsset: invoice.origin_output_asset!,
      amount: invoice.origin_amount!,
      maxFee: +invoice.origin_max_fee!,
      destinations: invoice.origin_destinations!,
      origin: invoice.origin_origin!,
      nonce: +invoice.origin_nonce!,
      data: invoice.origin_data ?? '0x',
      ttl: +invoice.origin_ttl!,
  
      transactionHash: invoice.origin_transaction_hash!,
      timestamp: +invoice.origin_timestamp!,
      blockNumber: +invoice.origin_block_number!,
      gasLimit: String(invoice.origin_gas_limit!),
      gasPrice: String(invoice.origin_gas_price!),
      txOrigin: invoice.origin_tx_origin!,
      txNonce: +invoice.origin_tx_nonce!,
    },
    hubInvoiceId: invoice.hub_invoice_id!,
    hubInvoiceIntentId: invoice.hub_invoice_intent_id!,
    hubInvoiceAmount: invoice.hub_invoice_amount!,
    hubInvoiceTickerHash: invoice.hub_invoice_ticker_hash!,
    hubInvoiceOwner: invoice.hub_invoice_owner!,
    hubInvoiceEntryEpoch: +invoice.hub_invoice_entry_epoch!,
    hubInvoiceEnqueuedTimestamp: +invoice.hub_invoice_enqueued_timestamp!,
    hubInvoiceEnqueuedTxNonce: +invoice.hub_invoice_enqueued_tx_nonce!,
    hubStatus: invoice.hub_status as TIntentStatus,
    hubSettlementEpoch: invoice.hub_settlement_epoch ? +invoice.hub_settlement_epoch : undefined,
  }
}

export function fromHubInvoices(hubInvoice: hub_invoices.JSONSelectable): HubInvoice {
  return {
    id: hubInvoice.id,
    intentId: hubInvoice.intent_id,
    amount: hubInvoice.amount,
    tickerHash: hubInvoice.ticker_hash,
    owner: hubInvoice.owner,
    entryEpoch: +hubInvoice.entry_epoch,

    enqueuedTimestamp: +hubInvoice.enqueued_timestamp!,
    enqueuedTxNonce: +hubInvoice.enqueued_tx_nonce!,
    enqueuedBlockNumber: +hubInvoice.enqueued_block_number,
    enqueuedTransactionHash: hubInvoice.enqueued_transaction_hash,
  };
}

export function toMessages(message: Message): messages.Insertable {
  return {
    id: message.id,
    type: message.type,
    domain: message.domain,
    origin_domain: message.originDomain,
    destination_domain: message.destinationDomain ?? '',
    quote: message.quote,
    first: message.first ?? 0,
    last: message.last ?? 0,
    intent_ids: message.intentIds,
    message_status: message.status,
    tx_origin: message.txOrigin,
    transaction_hash: message.transactionHash,
    timestamp: message.timestamp,
    block_number: message.blockNumber,
    tx_nonce: message.txNonce,
    gas_limit: +message.gasLimit,
    gas_price: +message.gasPrice,
  };
}
export function fromMessages(message: messages.JSONSelectable): Message {
  return {
    id: message.id,
    type: message.type,
    domain: message.domain,
    originDomain: message.domain,
    destinationDomain: message.destination_domain ?? "",
    quote: message.quote ?? undefined,
    first: +message.first,
    last: +message.last,
    intentIds: message.intent_ids,
    status: message.message_status ? (message.message_status as HyperlaneStatus) : HyperlaneStatus.none,
    txOrigin: message.tx_origin,
    transactionHash: message.transaction_hash,
    timestamp: +message.timestamp,
    blockNumber: +message.block_number,
    txNonce: +message.tx_nonce,
    gasLimit: String(message.gas_limit),
    gasPrice: String(message.gas_price),
  };
}

export function toQueues(queue: Queue | DepositQueue): queues.Insertable {
  return {
    id: queue.id,
    domain: queue.domain,
    last_processed: queue.lastProcessed,
    size: queue.size,
    first: queue.first,
    last: queue.last,
    type: queue.type,
    ticker_hash: (queue as DepositQueue).tickerHash ?? undefined,
    epoch: (queue as DepositQueue).epoch ?? undefined,
  };
}

export function fromQueue(queue: queues.JSONSelectable): Queue {
  return {
    id: queue.id,
    domain: queue.domain,
    lastProcessed: queue.last_processed ? +queue.last_processed : undefined,
    size: +queue.size,
    first: +queue.first,
    last: +queue.last,
    type: queue.type,
  };
}

export function toAssets(asset: Asset): assets.Insertable {
  return {
    id: asset.id,
    token_id: asset.token,
    domain: asset.domain,
    adopted: asset.adopted,
    approval: asset.approval,
    strategy: asset.strategy,
  };
}

export function fromAsset(asset: assets.JSONSelectable): Asset {
  return {
    id: asset.id,
    token: asset.token_id ?? '',
    domain: asset.domain ?? '',
    adopted: asset.adopted,
    approval: asset.approval,
    strategy: asset.strategy,
  };
}

export function toTokens(token: Token): tokens.Insertable {
  return {
    id: token.id,
    fee_recipients: token.feeRecipients,
    fee_amounts: token.feeAmounts,
    max_discount_bps: token.maxDiscountBps,
    discount_per_epoch: token.discountPerEpoch,
    prioritized_strategy: token.prioritizedStrategy,
  };
}

export function fromToken(token: tokens.JSONSelectable): Token {
  return {
    id: token.id,
    feeRecipients: token.fee_recipients || [],
    feeAmounts: token.fee_amounts || [],
    maxDiscountBps: +token.max_discount_bps,
    discountPerEpoch: +token.discount_per_epoch,
    prioritizedStrategy: token.prioritized_strategy,
  };
}

export function toBalances(balance: Balance): balances.Insertable {
  return {
    id: balance.id,
    account: balance.account,
    asset: balance.asset,
    amount: balance.amount,
  };
}

export function fromBalance(balance: balances.JSONSelectable): Balance {
  return {
    id: balance.id,
    account: balance.account.trim(),
    asset: balance.asset.trim(),
    amount: balance.amount,
  };
}

export function toDepositors(depositor: Depositor): depositors.Insertable {
  return {
    id: depositor.id,
  };
}

export function toHubDeposits(deposit: HubDeposit): hub_deposits.Insertable {
  return {
    id: deposit.id,
    intent_id: deposit.id,
    epoch: deposit.epoch,
    ticker_hash: deposit.tickerHash,
    domain: deposit.domain,
    amount: deposit.amount,
    enqueued_tx_nonce: deposit.enqueuedTxNonce,
    enqueued_timestamp: deposit.enqueuedTimestamp,
    processed_tx_nonce: deposit.processedTxNonce,
    processed_timestamp: deposit.processedTimestamp,
  };
}

export function fromHubDeposits(deposit: hub_deposits.JSONSelectable): HubDeposit {
  return {
    id: deposit.id,
    intentId: deposit.intent_id,
    epoch: +deposit.epoch,
    tickerHash: deposit.ticker_hash,
    domain: deposit.domain,
    amount: deposit.amount,
    enqueuedTxNonce: +deposit.enqueued_tx_nonce,
    enqueuedTimestamp: +deposit.enqueued_timestamp,
    processedTxNonce: deposit.processed_tx_nonce ? +deposit.processed_tx_nonce : undefined,
    processedTimestamp: deposit.processed_timestamp ? +deposit.processed_timestamp : undefined,
  };
}

export function fromShadowEvent(event: any): ShadowEvent {
  return {
    address: event.address,
    blockHash: event.block_hash,
    blockNumber: event.block_number,
    blockTimestamp: event.block_timestamp,
    chain: event.chain,
    network: event.network,
    topic0: event.topic_0,
    transactionHash: event.transaction_hash,
    transactionIndex: event.transaction_index,
    transactionLogIndex: event.transaction_log_index,
    timestamp: event.timestamp,
    latency: event.latency,
  };
}

export function fromMerkleTree(merkleTree: merkle_trees.JSONSelectable): MerkleTree {
  return {
    asset: merkleTree.asset,
    epochEndTimestamp: toDate(merkleTree.epoch_end_timestamp, 'UTC'),
    merkleTree: merkleTree.merkle_tree,
    root: merkleTree.root,
    proof: merkleTree.proof,
  }
}

export function toMerkleTree(merkleTree: MerkleTree): merkle_trees.Insertable {
  return {
    asset: merkleTree.asset,
    epoch_end_timestamp: db.toString(merkleTree.epochEndTimestamp, 'timestamp:UTC'),
    merkle_tree: merkleTree.merkleTree,
    root: merkleTree.root,
    proof: merkleTree.proof,
  };
}

export function fromVote(vote: {
  domain: number | `${number}`;
  voteCount: any;
}): Vote {
  return {
    domain: +vote.domain,
    votes: vote.voteCount,
  };
}

export function fromTokenomicsEvent(event: any): TokenomicsEvent {
  return {
    blockNumber: event.block_number,
    blockTimestamp: event.block_timestamp,
    transactionHash: event.transaction_hash.replace('\\', '0'),
    insertTimestamp: event.insert_timestamp,
  };
}

export function toReward(reward: Reward): rewards.Insertable {
  return {
    account: reward.account,
    asset: reward.asset,
    merkle_root: reward.merkleRoot,
    proof: JSON.stringify(reward.proof),
    stake_apy: reward.stakeApy,
    stake_rewards: reward.stakeRewards,
    total_clear_staked: reward.totalClearStaked,
    protocol_rewards: reward.protocolRewards,
    cumulative_rewards: reward.cumulativeRewards,
    epoch_timestamp: db.toString(reward.epochTimestamp, 'timestamp:UTC'),
  }
}

export function toEpochResult(epochResult: EpochResult): epoch_results.Insertable {
  return {
    account: epochResult.account,
    domain: epochResult.domain,
    user_volume: epochResult.userVolume,
    total_volume: epochResult.totalVolume,
    clear_emissions: epochResult.clearEmissions,
    cumulative_rewards: epochResult.cumulativeRewards,
    epoch_timestamp: db.toString(epochResult.epochTimestamp, 'timestamp:UTC'),
  }
}

export function fromNewLockPositionEvent(newLockPosition: tokenomics.new_lock_position.JSONSelectable): NewLockPositionEvent {
  return {
    vid: +newLockPosition.vid,
    // the database format is in `\\x00000000000000000000000039096a17ba70fe5c1eddb923f940b2e6deae5c3b`
    // cast it to address by ignoring the starting zeros
    user: '0x'+newLockPosition.user.slice(26),
    // NOTE: zapatos only converts number having precision issues to string, and this allows numbers
    // appear in form of `4.5e+23`, which cannot be directly converted with `toString`
    newTotalAmountLocked: newLockPosition.new_total_amount_locked.toLocaleString('fullwide',  { useGrouping: false }),
    blockTimestamp: +newLockPosition.block_timestamp,
    expiry: +newLockPosition.expiry,
  };
}

export function fromLockPosition(lockPosition: lock_positions.JSONSelectable): LockPosition {
  return {
    user: lockPosition.user,
    amountLocked: lockPosition.amount_locked,
    start: +lockPosition.start,
    expiry: +lockPosition.expiry,
  };
}

export function toLockPosition(lockPosition: LockPosition): lock_positions.JSONSelectable {
  return {
    user: lockPosition.user,
    amount_locked: lockPosition.amountLocked,
    start: +lockPosition.start,
    expiry: +lockPosition.expiry,
  };
}
