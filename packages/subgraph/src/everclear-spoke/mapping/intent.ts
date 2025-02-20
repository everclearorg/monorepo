import { Address, BigInt, Bytes } from '@graphprotocol/graph-ts';
import {
  FillQueueProcessed,
  IntentAdded,
  IntentFilled,
  IntentQueueProcessed,
  Settled,
  ExternalCalldataExecuted,
  AssetTransferFailed,
  AssetMintFailed,
} from '../../../generated/EverclearSpoke/EverclearSpoke';
import {
  Balance,
  DestinationIntent,
  FillQueueMapping,
  IntentAddEvent,
  IntentFillEvent,
  IntentQueueMapping,
  IntentSettleEvent,
  Message,
  OriginIntent,
  Queue,
  UnclaimedBalance,
  ExternalCalldataExecutedEvent,
  SettlementIntent,
  AssetMintFailedEvent,
  AssetTransferFailedEvent,
} from '../../../generated/schema';
import { BigIntToBytes, Bytes32ToAddress, generateIdFromTx, generateTxNonce } from '../../common';

const EverclearStrategyStrings = ['DEFAULT', 'XERC20'];

function getOrCreateQueue(type: string): Queue {
  const id = Bytes.fromUTF8(type);
  let queue = Queue.load(id);
  if (queue == null) {
    queue = new Queue(id);
    queue.type = type;
    queue.lastProcessed = BigInt.zero();
    queue.first = BigInt.fromI32(1);
    queue.last = BigInt.zero();
    queue.size = BigInt.zero();
    queue.save();
  }

  return queue;
}

// eslint-disable-next-line @typescript-eslint/ban-types
function getOrCreateIntentQueueMapping(queueIdx: BigInt): IntentQueueMapping {
  let mapping = IntentQueueMapping.load(BigIntToBytes(queueIdx));
  if (mapping == null) {
    mapping = new IntentQueueMapping(BigIntToBytes(queueIdx));
    mapping.intentId = Bytes.empty();
    mapping.save();
  }
  return mapping;
}

// eslint-disable-next-line @typescript-eslint/ban-types
function getOrCreateFillQueueMapping(queueIdx: BigInt): FillQueueMapping {
  let mapping = FillQueueMapping.load(BigIntToBytes(queueIdx));
  if (mapping == null) {
    mapping = new FillQueueMapping(BigIntToBytes(queueIdx));
    mapping.intentId = Bytes.empty();
    mapping.save();
  }
  return mapping;
}

/**
 * Creates subgraph records when IntentAdded events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleIntentAdded(event: IntentAdded): void {
  const intentId = event.params._intentId;
  let intent = OriginIntent.load(intentId);
  if (intent == null) {
    intent = new OriginIntent(intentId);
  }

  intent.origin = event.params._intent.origin;
  intent.initiator = event.params._intent.initiator;
  intent.receiver = event.params._intent.receiver;
  intent.inputAsset = event.params._intent.inputAsset;
  intent.outputAsset = event.params._intent.outputAsset;
  intent.amount = event.params._intent.amount;
  intent.destinations = event.params._intent.destinations;
  intent.nonce = event.params._intent.nonce;
  intent.data = event.params._intent.data;
  intent.queueIdx = event.params._queueIdx;
  intent.maxFee = BigInt.fromI32(event.params._intent.maxFee);
  intent.status = 'ADDED';
  intent.timestamp = event.params._intent.timestamp;
  intent.ttl = event.params._intent.ttl;

  // Add Transaction
  const log = new IntentAddEvent(generateIdFromTx(event));

  log.intent = intentId;
  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.gasPrice = event.transaction.gasPrice;
  log.gasLimit = event.transaction.gasLimit;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  intent.addEvent = log.id;
  intent.save();

  // Update unclaimed balance
  const asset: Address = Bytes32ToAddress(intent.inputAsset);
  let unclaimedBalance = UnclaimedBalance.load(asset);
  if (unclaimedBalance == null) {
    unclaimedBalance = new UnclaimedBalance(asset);
    unclaimedBalance.amount = new BigInt(0);
  }
  unclaimedBalance.amount = unclaimedBalance.amount.plus(intent.amount);
  unclaimedBalance.save();

  // Update Intent Queue
  const queue = getOrCreateQueue('INTENT');
  queue.last = queue.last.plus(BigInt.fromI32(1));
  queue.size = queue.size.plus(BigInt.fromI32(1));
  queue.save();

  // Update Intent-Queue Mapping
  const intentQueueMapping = getOrCreateIntentQueueMapping(intent.queueIdx);
  intentQueueMapping.intentId = intent.id;
  intentQueueMapping.save();
}

/**
 * Creates subgraph records when IntentFilled events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleIntentFilled(event: IntentFilled): void {
  const intentId = event.params._intentId;
  let intent = DestinationIntent.load(intentId);
  if (intent == null) {
    intent = new DestinationIntent(intentId);
  }

  intent.initiator = event.params._intent.initiator;
  intent.receiver = event.params._intent.receiver;
  intent.inputAsset = event.params._intent.inputAsset;
  intent.outputAsset = event.params._intent.outputAsset;
  intent.maxFee = BigInt.fromI32(event.params._intent.maxFee);
  intent.origin = event.params._intent.origin;
  intent.nonce = event.params._intent.nonce;
  intent.timestamp = event.params._intent.timestamp;
  intent.ttl = event.params._intent.ttl;
  intent.amount = event.params._intent.amount;
  intent.destinations = event.params._intent.destinations;
  intent.data = event.params._intent.data;
  intent.queueIdx = event.params._queueIdx;
  intent.status = 'ADDED';

  // Update ExternalCalldataExecutedEvent if exist
  const executedEvent = ExternalCalldataExecutedEvent.load(intentId);
  if (executedEvent != null) {
    intent.calldataExecutedEvent = executedEvent.id;
  }

  // Add Fill Transaction
  const log = new IntentFillEvent(generateIdFromTx(event));

  log.intent = intentId;
  log.solver = event.params._solver;
  log.fee = event.params._totalFeeDBPS;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.gasPrice = event.transaction.gasPrice;
  log.gasLimit = event.transaction.gasLimit;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  intent.fillEvent = log.id;
  intent.save();

  // Update Fill Queue
  const queue = getOrCreateQueue('FILL');
  queue.last = queue.last.plus(BigInt.fromI32(1));
  queue.size = queue.size.plus(BigInt.fromI32(1));
  queue.save();

  // Update Fill-Queue Mapping
  const fillQueueMapping = getOrCreateFillQueueMapping(intent.queueIdx);
  fillQueueMapping.intentId = intent.id;
  fillQueueMapping.save();
}

export function handleExternalCalldataExecuted(event: ExternalCalldataExecuted): void {
  // Get the intent id
  const intentId = event.params._intentId;
  // Create the event
  const log = new ExternalCalldataExecutedEvent(intentId);
  log.returnData = event.params._returnData;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.gasPrice = event.transaction.gasPrice;
  log.gasLimit = event.transaction.gasLimit;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  // Update the settlement intent record when executeIntentCalldata
  const intent = SettlementIntent.load(intentId);
  if (intent != null) {
    // If it is settled, the calldata is executed using `executeIntentCalldata`
    // Otherwise, it will be executed on a fill transaction
    intent.status = 'SETTLED_AND_MANUALLY_EXECUTED';
    intent.calldataExecutedEvent = log.id;
    intent.save();
  }
}

/**
 * Creates subgraph records when IntentQueueProcessed events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleIntentQueueProcessed(event: IntentQueueProcessed): void {
  const messageId = event.params._messageId;

  // Update Origin Intent Status
  const intentIds: Bytes[] = [];
  const length = event.params._lastIdx.minus(event.params._firstIdx).toI32();
  for (let idx = 0; idx < length; idx++) {
    const mapping = IntentQueueMapping.load(BigIntToBytes(event.params._firstIdx.plus(BigInt.fromI32(idx))));
    const intentId = mapping!.intentId;
    const intent = OriginIntent.load(intentId);
    if (intent != null) {
      intent.status = 'DISPATCHED';
      intent.message = messageId;
      intent.save();
    }
    intentIds.push(intentId);
  }

  // message is immutable
  const message = new Message(messageId);

  message.type = 'INTENT';
  message.quote = event.params._quote;
  message.firstIdx = event.params._firstIdx;
  message.lastIdx = event.params._lastIdx;
  message.intentIds = intentIds;

  message.blockNumber = event.block.number;
  message.timestamp = event.block.timestamp;
  message.transactionHash = event.transaction.hash;
  message.txOrigin = event.transaction.from;
  message.gasLimit = event.transaction.gasLimit;
  message.gasPrice = event.transaction.gasPrice;
  message.txNonce = generateTxNonce(event);

  message.save();

  // Update Intent Queue
  const queue = getOrCreateQueue('INTENT');
  queue.first = message.lastIdx;
  queue.size = queue.size.minus(message.lastIdx.minus(message.firstIdx));
  queue.lastProcessed = event.block.timestamp;
  queue.save();
}

/**
 * Creates subgraph records when FillQueueProcessed events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleFillQueueProcessed(event: FillQueueProcessed): void {
  const messageId = event.params._messageId;

  // Update Destination Intent Status
  const intentIds: Bytes[] = [];
  const length = event.params._lastIdx.minus(event.params._firstIdx).toI32();
  for (let idx = 0; idx < length; idx++) {
    const mapping = FillQueueMapping.load(BigIntToBytes(event.params._firstIdx.plus(BigInt.fromI32(idx))));
    const intentId = mapping!.intentId;
    const intent = DestinationIntent.load(intentId);
    if (intent != null) {
      intent.status = 'DISPATCHED';
      intent.message = messageId;
      intent.save();
    }
    intentIds.push(intentId);
  }

  // message is immutable
  const message = new Message(messageId);

  message.type = 'FILL';
  message.quote = event.params._quote;
  message.firstIdx = event.params._firstIdx;
  message.lastIdx = event.params._lastIdx;
  message.intentIds = intentIds;

  message.txOrigin = event.transaction.from;
  message.gasLimit = event.transaction.gasLimit;
  message.gasPrice = event.transaction.gasPrice;
  message.blockNumber = event.block.number;
  message.timestamp = event.block.timestamp;
  message.transactionHash = event.transaction.hash;
  message.txNonce = generateTxNonce(event);

  message.save();

  // Update Fill Queue
  const queue = getOrCreateQueue('FILL');
  queue.first = message.lastIdx;
  queue.size = queue.size.minus(message.lastIdx.minus(message.firstIdx));
  queue.lastProcessed = event.block.timestamp;
  queue.save();
}

/**
 * Creates subgraph records when Settled events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleSettled(event: Settled): void {
  const intentId = event.params._intentId;
  const account = event.params._account;
  const asset = event.params._asset;
  const amount = event.params._amount;

  // Create Spoke Settlement
  const settlement = new SettlementIntent(intentId);
  settlement.status = 'SETTLED';
  settlement.recipient = account;
  settlement.asset = asset;
  settlement.amount = amount;

  // Settlement Transaction
  const log = new IntentSettleEvent(generateIdFromTx(event));

  log.intentId = intentId;
  log.settlement = settlement.id;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.gasPrice = event.transaction.gasPrice;
  log.gasLimit = event.transaction.gasLimit;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  settlement.settlementEvent = log.id;
  settlement.save();

  // Update OriginIntent or DestinationIntent statuses if they exist
  const originIntent = OriginIntent.load(intentId);
  if (originIntent != null) {
    originIntent.status = 'SETTLED';
    originIntent.settlement = settlement.id;
    originIntent.save();
  }

  const destinationIntent = DestinationIntent.load(intentId);
  if (destinationIntent != null) {
    destinationIntent.status = 'SETTLED';
    destinationIntent.settlement = settlement.id;
    destinationIntent.save();
  }

  // Update unclaimed balance
  const unclaimedBalance = UnclaimedBalance.load(asset);
  if (unclaimedBalance != null) {
    unclaimedBalance.amount = unclaimedBalance.amount.minus(amount);
    unclaimedBalance.save();
  }

  // Update balance
  const balanceId = account.concat(asset);
  let balance = Balance.load(balanceId);
  if (balance == null) {
    balance = new Balance(balanceId);
    balance.account = account;
    balance.asset = asset;
    balance.amount = new BigInt(0);
  }

  // Update balance amount and save
  balance.amount = balance.amount.plus(event.params._amount);
  balance.save();
}

/**
 * Creates subgraph records when AssetMintFailed events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleAssetMintFailed(event: AssetMintFailed): void {
  const log = new AssetMintFailedEvent(generateIdFromTx(event));
  log.asset = event.params._asset;
  log.recipient = event.params._recipient;
  log.amount = event.params._amount;
  log.strategy = EverclearStrategyStrings[event.params._strategy];

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.gasPrice = event.transaction.gasPrice;
  log.gasLimit = event.transaction.gasLimit;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();
}

/**
 * Creates subgraph records when AssetTransferFailed events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleAssetTransferFailed(event: AssetTransferFailed): void {
  const log = new AssetTransferFailedEvent(generateIdFromTx(event));
  log.asset = event.params._asset;
  log.recipient = event.params._recipient;
  log.amount = event.params._amount;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.gasPrice = event.transaction.gasPrice;
  log.gasLimit = event.transaction.gasLimit;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();
}
