import { BigInt, Bytes } from '@graphprotocol/graph-ts';
import {
  DepositEnqueued,
  DepositProcessed,
  ExpiredIntentsHandled,
  FeesWithdrawn,
  FillProcessed,
  IntentProcessed,
  InvoiceEnqueued,
  ReturnUnsupportedIntent,
  SettlementEnqueued,
  SettlementQueueProcessed,
} from '../../../generated/EverclearHub/EverclearHub';
import {
  Deposit,
  DepositEnqueuedEvent,
  DepositProcessedEvent,
  DepositQueue,
  HubIntent,
  IntentAddEvent,
  IntentFillEvent,
  Invoice,
  InvoiceEnqueuedEvent,
  HubSettlement,
  SettlementEnqueuedEvent,
  SettlementMessage,
  SettlementQueue,
  SettlementQueueMapping,
  FeesWithdrawnEvent,
} from '../../../generated/schema';
import { BigIntToBytes, ConcatBigIntsToBytes, generateIdFromTx, generateTxNonce } from '../../common';
import { getOrCreateMeta } from './meta';

enum HubIntentStatus {
  NONE,
  ADDED,
  DEPOSIT_PROCESSED,
  FILLED,
  ADDED_AND_FILLED,
  INVOICED,
  SETTLED,
  SETTLED_AND_MANUALLY_EXECUTED,
  UNSUPPORTED,
  UNSUPPORTED_RETURNED,
}
const HubIntentStatusStrings = [
  'NONE',
  'ADDED',
  'DEPOSIT_PROCESSED',
  'FILLED',
  'ADDED_AND_FILLED',
  'INVOICED',
  'SETTLED',
  'SETTLED_AND_MANUALLY_EXECUTED',
  'UNSUPPORTED',
  'UNSUPPORTED_RETURNED',
];

enum SettlementMessageType {
  SETTLED,
  UNSUPPORTED_RETURNED,
}
const SettlementMessageTypeStrings = ['SETTLED', 'UNSUPPORTED_RETURNED'];

function getOrCreateHubIntent(id: Bytes): HubIntent {
  let intent = HubIntent.load(id);
  if (intent == null) {
    intent = new HubIntent(id);

    intent.status = HubIntentStatusStrings[HubIntentStatus.NONE];
    intent.save();
  }

  return intent;
}

function getOrCreateSettlement(intentId: Bytes, eventId: Bytes): HubSettlement {
  let settlement = HubSettlement.load(intentId);
  if (settlement == null) {
    settlement = new HubSettlement(intentId);
    settlement.intent = intentId;
    settlement.queueIdx = BigInt.zero();
    settlement.amount = BigInt.zero();
    settlement.asset = Bytes.empty();
    settlement.updateVirtualBalance = false;
    settlement.recipient = Bytes.empty();
    settlement.domain = BigInt.zero();
    settlement.enqueuedEvent = eventId;
    settlement.entryEpoch = BigInt.zero();
    settlement.save();
  }

  return settlement;
}

// eslint-disable-next-line @typescript-eslint/ban-types
function getOrCreateSettlementQueue(domain: BigInt): SettlementQueue {
  let queue = SettlementQueue.load(BigIntToBytes(domain));
  if (queue == null) {
    queue = new SettlementQueue(BigIntToBytes(domain));
    queue.first = BigInt.fromI32(1);
    queue.last = BigInt.zero();
    queue.size = BigInt.zero();
    queue.domain = domain;
    queue.save();
  }

  return queue;
}

// eslint-disable-next-line @typescript-eslint/ban-types
function getOrCreateSettlementQueueMapping(domain: BigInt, queueIdx: BigInt): SettlementQueueMapping {
  const id = ConcatBigIntsToBytes(domain, queueIdx);
  let mapping = SettlementQueueMapping.load(id);
  if (mapping == null) {
    mapping = new SettlementQueueMapping(id);
    mapping.intentId = Bytes.empty();
    mapping.save();
  }
  return mapping;
}

// eslint-disable-next-line @typescript-eslint/ban-types
function getOrCreateDeposit(id: Bytes, amount: BigInt, epoch: BigInt, domain: BigInt, tickerHash: Bytes): Deposit {
  let deposit = Deposit.load(id);
  if (deposit == null) {
    deposit = new Deposit(id);
    deposit.intent = getOrCreateHubIntent(id).id;
    deposit.amount = amount;
    deposit.domain = domain;
    deposit.epoch = epoch;
    deposit.tickerHash = tickerHash;
    deposit.save();
  }

  return deposit;
}

// eslint-disable-next-line @typescript-eslint/ban-types
function getOrCreateDepositQueue(epoch: BigInt, domain: BigInt, tickerHash: Bytes): DepositQueue {
  const id = Bytes.fromByteArray(Bytes.fromBigInt(epoch).concat(Bytes.fromBigInt(domain))).concat(tickerHash);
  let queue = DepositQueue.load(id);
  if (queue == null) {
    queue = new DepositQueue(id);
    queue.domain = domain;
    queue.epoch = epoch;
    queue.tickerHash = tickerHash;
    queue.first = BigInt.fromI32(1);
    queue.last = BigInt.zero();
    queue.size = BigInt.zero();
    queue.save();
  }
  return queue;
}

/**
 * Creates subgraph records when IntentProcessed events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleIntentProcessed(event: IntentProcessed): void {
  const intentId = event.params._intentId;
  const intent = getOrCreateHubIntent(intentId);

  intent.status = HubIntentStatusStrings[event.params._status];

  // Add Transaction
  const log = new IntentAddEvent(generateIdFromTx(event));

  log.intent = intentId;
  log.status = intent.status;
  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  intent.addEvent = log.id;
  intent.save();
}

/**
 * Creates subgraph records when FillProcessed events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleFillProcessed(event: FillProcessed): void {
  const intentId = event.params._intentId;
  const intent = getOrCreateHubIntent(intentId);

  intent.status = HubIntentStatusStrings[event.params._status];

  // Fill Transaction
  const log = new IntentFillEvent(generateIdFromTx(event));

  log.intent = intentId;
  log.status = intent.status;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  intent.fillEvent = log.id;
  intent.save();
}

/**
 * Creates subgraph records when SettlementEnqueued events are emitted.
 * This event signifies a settlement has been created from a given deposit, and the
 * message is ready to be sent to the settlement domain spoke.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleSettlementEnqueued(event: SettlementEnqueued): void {
  const intentId = event.params._intentId;
  const domain = event.params._domain;

  // Update Settlement Queue
  const queue = getOrCreateSettlementQueue(event.params._domain);
  queue.last = queue.last.plus(BigInt.fromI32(1));
  queue.size = queue.size.plus(BigInt.fromI32(1));
  queue.save();

  // Update Settlement-Queue Mapping
  // TODO: Do we need to emit the queueIdx in the event like we do on the spokes? Otherwise assumes
  // ordered processing of events in calculation of queueIdx
  const settlementQueueMapping = getOrCreateSettlementQueueMapping(domain, queue.last);
  settlementQueueMapping.intentId = intentId;
  settlementQueueMapping.save();

  // Update the HubSettlement. Create if not exist
  const settlement = getOrCreateSettlement(intentId, generateIdFromTx(event));
  settlement.amount = event.params._amount;
  settlement.asset = event.params._asset;
  settlement.updateVirtualBalance = event.params._updateVirtualBalance;
  settlement.recipient = event.params._owner;
  settlement.intent = intentId;
  settlement.domain = event.params._domain;
  settlement.queueIdx = queue.last;
  settlement.entryEpoch = event.params._entryEpoch;

  // Update Hub Intent. Create if not exist
  const intent = getOrCreateHubIntent(intentId);
  intent.settlement = settlement.id;
  intent.status = HubIntentStatusStrings[HubIntentStatus.SETTLED];
  intent.save();

  // Enqueued Transaction
  const log = new SettlementEnqueuedEvent(generateIdFromTx(event));
  log.intent = intent.id;
  log.settlement = settlement.id;
  log.queue = queue.id;
  // See above re queue idx
  log.queueIdx = queue.last;
  log.domain = queue.domain;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  settlement.enqueuedEvent = log.id;
  settlement.save();
}

/**
 * Creates subgraph records when SettlementQueueProcessed events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleSettlementQueueProcessed(event: SettlementQueueProcessed): void {
  // Get message id
  const messageId = event.params._messageId;

  // Update the Settlement queue
  const queue = getOrCreateSettlementQueue(event.params._domain);

  // Update the Settlements in the queue
  const intentIds: Bytes[] = [];
  const length = event.params._amount.toI32();
  for (let idx = 0; idx < length; idx++) {
    const mapping = SettlementQueueMapping.load(
      ConcatBigIntsToBytes(event.params._domain, queue.first.plus(BigInt.fromI32(idx))),
    );
    const intentId = mapping!.intentId;
    const intent = HubIntent.load(intentId);
    if (intent != null) {
      intent.message = messageId;
      intent.save();
    }
    intentIds.push(intentId);
  }

  // Create Message (immutable)
  const message = new SettlementMessage(messageId);
  message.domain = event.params._domain;
  message.quote = event.params._quote;
  message.type = SettlementMessageTypeStrings[SettlementMessageType.SETTLED];

  message.blockNumber = event.block.number;
  message.timestamp = event.block.timestamp;
  message.transactionHash = event.transaction.hash;
  message.txOrigin = event.transaction.from;
  message.gasLimit = event.transaction.gasLimit;
  message.gasPrice = event.transaction.gasPrice;
  message.txNonce = generateTxNonce(event);
  message.intentIds = intentIds;
  message.save();

  // Update the settlement queue
  queue.first = queue.first.plus(event.params._amount);
  queue.size = queue.size.minus(event.params._amount);
  queue.lastProcessed = event.block.timestamp;
  queue.save();
}

/**
 * Creates subgraph records when ExpiredIntentsHandled events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleExpiredIntentsHandled(event: ExpiredIntentsHandled): void {
  for (let i = 0; i < event.params._intentIds.length; i++) {
    const intentId = event.params._intentIds[i];
    const intent = HubIntent.load(intentId);

    if (intent != null) {
      // TODO
    }
  }
}

/**
 * Creates subgraph records when ReturnUnsupportedIntent events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleReturnUnsupportedIntent(event: ReturnUnsupportedIntent): void {
  const messageId = event.params._messageId;

  const message = new SettlementMessage(messageId);
  message.quote = event.transaction.value;
  message.domain = event.params._domain;
  message.intentIds = [event.params._intentId];
  message.type = 'UNSUPPORTED_RETURNED';

  message.blockNumber = event.block.number;
  message.timestamp = event.block.timestamp;
  message.transactionHash = event.transaction.hash;
  message.txOrigin = event.transaction.from;
  message.gasLimit = event.transaction.gasLimit;
  message.gasPrice = event.transaction.gasPrice;
  message.txNonce = generateTxNonce(event);

  message.save();

  const intent = HubIntent.load(event.params._intentId);

  if (intent != null) {
    intent.settlement = messageId;
    intent.status = HubIntentStatusStrings[HubIntentStatus.UNSUPPORTED_RETURNED];
    intent.save();
  }
}

/**
 * Creates subgraph records when InvoiceEnqueued events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleInvoiceEnqueued(event: InvoiceEnqueued): void {
  const intentId = event.params._intentId;

  const meta = getOrCreateMeta();

  const id = generateIdFromTx(event);
  let invoice = Invoice.load(id);
  if (invoice == null) {
    invoice = new Invoice(id);
  }
  invoice.amount = event.params._amount;
  invoice.tickerHash = event.params._tickerHash;
  invoice.owner = event.params._owner;
  invoice.intent = intentId;
  invoice.entryEpoch = event.params._entryEpoch;

  // Update Hub Intent. Create if not exist
  const intent = getOrCreateHubIntent(intentId);
  intent.status = HubIntentStatusStrings[HubIntentStatus.INVOICED];
  intent.save();

  // Enqueued Transaction
  const log = new InvoiceEnqueuedEvent(generateIdFromTx(event));
  log.intent = intent.id;
  log.invoice = id;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  invoice.enqueuedEvent = log.id;
  invoice.save();
}

/**
 * Creates subgraph records when DepositEnqueued events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleDepositEnqueued(event: DepositEnqueued): void {
  const intentId = event.params._intentId;

  // Update Deposit Queue
  const queue = getOrCreateDepositQueue(event.params._epoch, event.params._domain, event.params._tickerHash);
  queue.last = queue.last.plus(BigInt.fromI32(1));
  queue.size = queue.size.plus(BigInt.fromI32(1));
  queue.save();

  // Update the Deposit. Create if not exist
  const deposit = getOrCreateDeposit(
    intentId,
    event.params._amount,
    event.params._epoch,
    event.params._domain,
    event.params._tickerHash,
  );

  // Enqueued Transaction
  const log = new DepositEnqueuedEvent(generateIdFromTx(event));
  log.intent = intentId;
  log.deposit = deposit.id;
  log.queue = queue.id;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  deposit.enqueuedEvent = log.id;
  deposit.save();
}

/**
 * Creates subgraph records when DepositProcessed events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleDepositProcessed(event: DepositProcessed): void {
  // Update the Deposit queue
  const queueId = Bytes.fromByteArray(
    Bytes.fromBigInt(event.params._epoch).concat(Bytes.fromBigInt(event.params._domain)),
  ).concat(event.params._tickerHash);
  const existing = DepositQueue.load(queueId) != null;
  const queue = getOrCreateDepositQueue(event.params._epoch, event.params._domain, event.params._tickerHash);

  // Processed Transaction
  const intentId = event.params._intentId;

  // Intent Status
  const intent = getOrCreateHubIntent(intentId);
  intent.status = HubIntentStatusStrings[HubIntentStatus.DEPOSIT_PROCESSED];
  intent.save();

  // Deposit
  const deposit = getOrCreateDeposit(
    intentId,
    event.params._amountAndRewards,
    event.params._epoch,
    event.params._domain,
    event.params._tickerHash,
  );

  const log = new DepositProcessedEvent(generateIdFromTx(event));
  log.intent = event.params._intentId;
  log.deposit = deposit.id;
  log.queue = queue.id;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  deposit.processedEvent = log.id;
  deposit.save();

  // Update the deposit queue
  if (existing) {
    queue.first = queue.first.plus(BigInt.fromI32(1));
    queue.size = queue.size.minus(BigInt.fromI32(1));
    queue.lastProcessed = event.block.timestamp;
    queue.save();
  }
}

/**
 * Creates subgraph records when FeesWithdrawn events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleFeesWithdrawn(event: FeesWithdrawn): void {
  const log = new FeesWithdrawnEvent(generateIdFromTx(event));
  log.withdrawer = event.params._withdrawer;
  log.recipient = event.params._feeRecipient;
  log.paymentId = event.params._paymentId;
  log.tickerHash = event.params._tickerHash;
  log.amount = event.params._amount;

  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();
}
