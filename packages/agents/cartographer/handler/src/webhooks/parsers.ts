import {
  HubInvoice,
  HubDeposit,
  HubIntent,
  OriginIntent,
  DestinationIntent,
  SettlementIntent,
  Order,
  MessageQueue,
  HubMeta,
  SpokeMeta,
  Asset,
  Token,
  ProtocolUpdateLog,
  HubTokenUpdateLog,
  HubAssetUpdateLog,
  TIntentStatus,
  TMessageType,
  QueueType,
} from '@chimera-monorepo/utils';
import { base64ToHex } from './webhookHandler';

// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------

/**
 * Safely convert base64 byte fields to hex.
 * Only converts if the value looks like base64 (non-hex string).
 */
function maybeBase64ToHex(value: unknown): string {
  if (typeof value !== 'string') return String(value);
  if (value.startsWith('0x')) return value;
  try {
    return base64ToHex(value);
  } catch {
    return value;
  }
}

function toNumber(value: unknown): number {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return parseInt(value, 10) || 0;
  return 0;
}

function toString(value: unknown): string {
  if (typeof value === 'string') return value;
  if (value === null || value === undefined) return '';
  return String(value);
}

function toBigIntString(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '0';
}

/**
 * Parse array fields – Goldsky may send arrays as JSON strings or actual arrays.
 */
function parseArray(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String);
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed.map(String) : [value];
    } catch {
      return value ? [value] : [];
    }
  }
  return [];
}

/**
 * Parse a nested JSON array field that may arrive as a JSON string or native array.
 */
function parseJsonArrayField<T>(value: unknown): T[] | undefined {
  if (value === null || value === undefined) return undefined;
  if (Array.isArray(value)) return value as T[];
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? (parsed as T[]) : undefined;
    } catch {
      return undefined;
    }
  }
  return undefined;
}

// ---------------------------------------------------------------------------
// Parsed message type (used by both hub and spoke message processors)
// The `status` field is added by the processor, not the parser.
// ---------------------------------------------------------------------------

export interface ParsedMessage {
  id: string;
  type: TMessageType;
  domain: string;
  originDomain: string;
  destinationDomain: string;
  quote: string;
  first: number;
  last: number;
  intentIds: string[];
  // OnchainTransactionContext
  transactionHash: string;
  blockNumber: number;
  gasLimit: string;
  gasPrice: string;
  txOrigin: string;
  txNonce: number;
  timestamp: number;
  // Hub-message specific
  settlementDomain: string;
  settlementType: string;
}

// ---------------------------------------------------------------------------
// Depositor event type (processor constructs Depositor + Balance from this)
// ---------------------------------------------------------------------------

export interface ParsedDepositorEvent {
  id: string;
  depositor: string;
  type: string;
  asset: string;
  domain: string;
  amount: string;
  balance: string;
  transactionHash: string;
  blockNumber: number;
  gasLimit: string;
  gasPrice: string;
  txOrigin: string;
  txNonce: number;
  timestamp: number;
}

// ---------------------------------------------------------------------------
// Entity parsers
// ---------------------------------------------------------------------------

export const parseHubInvoice = (payload: Record<string, unknown>): HubInvoice => ({
  id: maybeBase64ToHex(payload.intent || payload.id),
  intentId: maybeBase64ToHex(payload.intent || payload.id),
  amount: toBigIntString(payload.amount),
  tickerHash: maybeBase64ToHex(payload.ticker_hash),
  owner: maybeBase64ToHex(payload.owner),
  entryEpoch: toNumber(payload.entry_epoch),
  enqueuedTxNonce: toNumber(payload.enqueued_tx_nonce || payload.tx_nonce),
  enqueuedTimestamp: toNumber(payload.enqueued_timestamp || payload.timestamp || payload.block_timestamp),
  enqueuedBlockNumber: toNumber(payload.enqueued_block_number || payload.block_number),
  enqueuedTransactionHash: toString(payload.enqueued_transaction_hash || payload.transaction_hash),
});

export const parseHubDeposit = (payload: Record<string, unknown>, type: 'enqueued' | 'processed'): HubDeposit => ({
  id: maybeBase64ToHex(payload.id),
  intentId: maybeBase64ToHex(payload.intent_id || payload.intent),
  amount: toBigIntString(payload.amount),
  tickerHash: maybeBase64ToHex(payload.ticker_hash),
  domain: toString(payload.domain),
  epoch: toNumber(payload.epoch),
  enqueuedTxNonce: toNumber(payload.enqueued_tx_nonce || payload.tx_nonce),
  enqueuedTimestamp: toNumber(payload.enqueued_timestamp || payload.timestamp || payload.block_timestamp),
  processedTxNonce: type === 'processed' ? toNumber(payload.processed_tx_nonce || payload.tx_nonce) : undefined,
  processedTimestamp:
    type === 'processed'
      ? toNumber(payload.processed_timestamp || payload.timestamp || payload.block_timestamp)
      : undefined,
});

export const parseOriginIntent = (payload: Record<string, unknown>): OriginIntent => ({
  id: maybeBase64ToHex(payload.id),
  queueIdx: toNumber(payload.queue_idx),
  status: toString(payload.status) as TIntentStatus,
  // IntentSchema
  initiator: maybeBase64ToHex(payload.initiator),
  receiver: maybeBase64ToHex(payload.receiver),
  inputAsset: maybeBase64ToHex(payload.input_asset),
  outputAsset: maybeBase64ToHex(payload.output_asset),
  amount: toBigIntString(payload.amount),
  origin: toString(payload.origin),
  destinations: parseArray(payload.destinations),
  nonce: toNumber(payload.nonce),
  timestamp: toNumber(payload.timestamp || payload.block_timestamp),
  data: toString(payload.data),
  amountOutMin: toBigIntString(payload.amount_out_min),
  ttl: toNumber(payload.ttl),
  // OnchainTransactionContext
  transactionHash: toString(payload.transaction_hash),
  blockNumber: toNumber(payload.block_number),
  gasLimit: toBigIntString(payload.gas_limit),
  gasPrice: toBigIntString(payload.gas_price),
  txOrigin: toString(payload.tx_origin),
  txNonce: toNumber(payload.tx_nonce),
  // OriginIntent optional fields
  nativeFee: payload.native_fee !== undefined ? toBigIntString(payload.native_fee) : undefined,
  tokenFee: payload.token_fee !== undefined ? toBigIntString(payload.token_fee) : undefined,
  feeAdapterInitiator: payload.fee_adapter_initiator ? maybeBase64ToHex(payload.fee_adapter_initiator) : undefined,
  orderId: payload.order_id ? maybeBase64ToHex(payload.order_id) : undefined,
  isSwap: undefined, // Computed by processor
});

export const parseDestinationIntent = (payload: Record<string, unknown>): DestinationIntent => ({
  id: maybeBase64ToHex(payload.id),
  queueIdx: toNumber(payload.queue_idx),
  status: toString(payload.status) as TIntentStatus,
  destination: toString(payload.destination || payload.filled_domain),
  solver: maybeBase64ToHex(payload.solver || payload.filler),
  fee: toBigIntString(payload.fee),
  amountOut: toBigIntString(payload.amount_out),
  // IntentSchema
  initiator: maybeBase64ToHex(payload.initiator),
  receiver: maybeBase64ToHex(payload.receiver),
  inputAsset: maybeBase64ToHex(payload.input_asset),
  outputAsset: maybeBase64ToHex(payload.output_asset),
  amount: toBigIntString(payload.amount),
  origin: toString(payload.origin),
  destinations: parseArray(payload.destinations),
  nonce: toNumber(payload.nonce),
  timestamp: toNumber(payload.timestamp || payload.block_timestamp),
  data: toString(payload.data),
  amountOutMin: toBigIntString(payload.amount_out_min),
  ttl: toNumber(payload.ttl),
  // OnchainTransactionContext
  transactionHash: toString(payload.transaction_hash),
  blockNumber: toNumber(payload.block_number),
  gasLimit: toBigIntString(payload.gas_limit),
  gasPrice: toBigIntString(payload.gas_price),
  txOrigin: toString(payload.tx_origin),
  txNonce: toNumber(payload.tx_nonce),
  // Optional
  returnData: payload.return_data ? toString(payload.return_data) : undefined,
});

export const parseHubIntent = (payload: Record<string, unknown>): HubIntent => ({
  id: maybeBase64ToHex(payload.id),
  status: toString(payload.status) as TIntentStatus,
  domain: toString(payload.domain),
  addedTimestamp: payload.added_timestamp !== undefined ? toNumber(payload.added_timestamp) : undefined,
  addedTxNonce: payload.added_tx_nonce !== undefined ? toNumber(payload.added_tx_nonce) : undefined,
  filledTimestamp: payload.filled_timestamp !== undefined ? toNumber(payload.filled_timestamp) : undefined,
  filledTxNonce: payload.filled_tx_nonce !== undefined ? toNumber(payload.filled_tx_nonce) : undefined,
  settlementEnqueuedTimestamp:
    payload.settlement_enqueued_timestamp !== undefined ? toNumber(payload.settlement_enqueued_timestamp) : undefined,
  settlementEnqueuedTxNonce:
    payload.settlement_enqueued_tx_nonce !== undefined ? toNumber(payload.settlement_enqueued_tx_nonce) : undefined,
  settlementEnqueuedBlockNumber:
    payload.settlement_enqueued_block_number !== undefined
      ? toNumber(payload.settlement_enqueued_block_number)
      : undefined,
  settlementDomain: payload.settlement_domain !== undefined ? toString(payload.settlement_domain) : undefined,
  settlementAmount: payload.settlement_amount !== undefined ? toBigIntString(payload.settlement_amount) : undefined,
  settlementEpoch: payload.settlement_epoch !== undefined ? toNumber(payload.settlement_epoch) : undefined,
  queueIdx: payload.queue_idx !== undefined ? toNumber(payload.queue_idx) : undefined,
});

export const parseSettlementIntent = (payload: Record<string, unknown>): SettlementIntent => ({
  intentId: maybeBase64ToHex(payload.intent_id || payload.id),
  amount: toBigIntString(payload.amount),
  asset: maybeBase64ToHex(payload.asset),
  recipient: maybeBase64ToHex(payload.recipient),
  domain: toString(payload.domain),
  status: toString(payload.status) as TIntentStatus,
  returnData: payload.return_data ? toString(payload.return_data) : undefined,
  // OnchainTransactionContext
  transactionHash: toString(payload.transaction_hash),
  blockNumber: toNumber(payload.block_number),
  gasLimit: toBigIntString(payload.gas_limit),
  gasPrice: toBigIntString(payload.gas_price),
  txOrigin: toString(payload.tx_origin),
  txNonce: toNumber(payload.tx_nonce),
  timestamp: toNumber(payload.timestamp || payload.block_timestamp),
});

export const parseOrder = (payload: Record<string, unknown>): Order => ({
  id: maybeBase64ToHex(payload.id),
  tokenFee: toBigIntString(payload.token_fee),
  nativeFee: toBigIntString(payload.native_fee),
  intentIds: parseArray(payload.intent_ids),
  initiator: maybeBase64ToHex(payload.initiator),
  // OnchainTransactionContext
  transactionHash: toString(payload.transaction_hash),
  blockNumber: toNumber(payload.block_number),
  gasLimit: toBigIntString(payload.gas_limit),
  gasPrice: toBigIntString(payload.gas_price),
  txOrigin: toString(payload.tx_origin),
  txNonce: toNumber(payload.tx_nonce),
  timestamp: toNumber(payload.timestamp || payload.block_timestamp),
});

export const parseMessage = (payload: Record<string, unknown>): ParsedMessage => ({
  id: maybeBase64ToHex(payload.id),
  type: toString(payload.type) as TMessageType,
  domain: toString(payload.origin_domain || payload.domain),
  originDomain: toString(payload.origin_domain || payload.domain),
  destinationDomain: toString(payload.destination_domain),
  quote: toBigIntString(payload.quote),
  first: toNumber(payload.first_idx || payload.first),
  last: toNumber(payload.last_idx || payload.last),
  intentIds: parseArray(payload.intent_ids),
  // OnchainTransactionContext
  transactionHash: toString(payload.transaction_hash),
  blockNumber: toNumber(payload.block_number),
  gasLimit: toBigIntString(payload.gas_limit),
  gasPrice: toBigIntString(payload.gas_price),
  txOrigin: toString(payload.tx_origin),
  txNonce: toNumber(payload.tx_nonce),
  timestamp: toNumber(payload.timestamp || payload.block_timestamp),
  // Hub-message specific
  settlementDomain: toString(payload.settlement_domain),
  settlementType: toString(payload.settlement_type),
});

export const parseQueue = (payload: Record<string, unknown>, queueType: QueueType): MessageQueue => ({
  id: toString(payload.id),
  domain: toString(payload.domain),
  size: toNumber(payload.size),
  first: toNumber(payload.first),
  last: toNumber(payload.last),
  lastProcessed: payload.last_processed !== undefined ? toNumber(payload.last_processed) : undefined,
  type: queueType,
});

export const parseHubMeta = (payload: Record<string, unknown>): HubMeta => ({
  id: toString(payload.id || payload.domain),
  domain: toString(payload.domain),
  paused: payload.paused !== undefined ? Boolean(payload.paused) : undefined,
  owner: payload.owner ? maybeBase64ToHex(payload.owner) : undefined,
  proposedOwner: payload.proposed_owner ? maybeBase64ToHex(payload.proposed_owner) : undefined,
  proposedOwnershipTimestamp: payload.proposed_ownership_timestamp
    ? toString(payload.proposed_ownership_timestamp)
    : undefined,
  gateway: payload.gateway ? maybeBase64ToHex(payload.gateway) : undefined,
  watchtower: payload.watchtower ? maybeBase64ToHex(payload.watchtower) : undefined,
  manager: payload.manager ? maybeBase64ToHex(payload.manager) : undefined,
  settler: payload.settler ? maybeBase64ToHex(payload.settler) : undefined,
  minSolverSupportedDomains: payload.min_solver_supported_domains
    ? toString(payload.min_solver_supported_domains)
    : undefined,
  expiryTimeBuffer: payload.expiry_time_buffer ? toString(payload.expiry_time_buffer) : undefined,
  discountPerEpoch: payload.discount_per_epoch ? toString(payload.discount_per_epoch) : undefined,
  epochLength: payload.epoch_length ? toString(payload.epoch_length) : undefined,
  mailbox: payload.mailbox ? maybeBase64ToHex(payload.mailbox) : undefined,
  securityModule: payload.security_module ? maybeBase64ToHex(payload.security_module) : undefined,
  acceptanceDelay: payload.acceptance_delay ? toString(payload.acceptance_delay) : undefined,
  supportedDomains: parseJsonArrayField(payload.supported_domains),
  chainGateways: parseJsonArrayField(payload.chain_gateways),
});

export const parseSpokeMeta = (payload: Record<string, unknown>): SpokeMeta => ({
  id: toString(payload.id || payload.domain),
  domain: toString(payload.domain),
  paused: payload.paused !== undefined ? Boolean(payload.paused) : undefined,
  gateway: payload.gateway ? maybeBase64ToHex(payload.gateway) : undefined,
  lighthouse: payload.lighthouse ? maybeBase64ToHex(payload.lighthouse) : undefined,
  messageReceiver: payload.message_receiver ? maybeBase64ToHex(payload.message_receiver) : undefined,
  watchtower: payload.watchtower ? maybeBase64ToHex(payload.watchtower) : undefined,
  messageGasLimit: payload.message_gas_limit ? toString(payload.message_gas_limit) : undefined,
  feeAdapter: payload.fee_adapter ? maybeBase64ToHex(payload.fee_adapter) : undefined,
  feeAdapterRecipient: payload.fee_adapter_recipient ? maybeBase64ToHex(payload.fee_adapter_recipient) : undefined,
  fillSigner: payload.fill_signer ? maybeBase64ToHex(payload.fill_signer) : undefined,
  feeSigner: payload.fee_signer ? maybeBase64ToHex(payload.fee_signer) : undefined,
  mailbox: payload.mailbox ? maybeBase64ToHex(payload.mailbox) : undefined,
  securityModule: payload.security_module ? maybeBase64ToHex(payload.security_module) : undefined,
  moduleForStrategies: parseJsonArrayField(payload.module_for_strategies),
});

export const parseDepositorEvent = (payload: Record<string, unknown>): ParsedDepositorEvent => ({
  id: toString(payload.id),
  depositor: maybeBase64ToHex(payload.depositor),
  type: toString(payload.type),
  asset: maybeBase64ToHex(payload.asset),
  domain: toString(payload.domain),
  amount: toBigIntString(payload.amount),
  balance: toBigIntString(payload.balance),
  transactionHash: toString(payload.transaction_hash),
  blockNumber: toNumber(payload.block_number),
  gasLimit: toBigIntString(payload.gas_limit),
  gasPrice: toBigIntString(payload.gas_price),
  txOrigin: toString(payload.tx_origin),
  txNonce: toNumber(payload.tx_nonce),
  timestamp: toNumber(payload.timestamp || payload.block_timestamp),
});

export const parseToken = (payload: Record<string, unknown>): Token => ({
  id: maybeBase64ToHex(payload.id),
  feeRecipients: parseArray(payload.fee_recipients),
  feeAmounts: parseArray(payload.fee_amounts),
  maxDiscountBps: toNumber(payload.max_discount_bps),
  discountPerEpoch: toNumber(payload.discount_per_epoch),
  prioritizedStrategy: toString(payload.prioritized_strategy),
});

export const parseAsset = (payload: Record<string, unknown>): Asset => ({
  id: maybeBase64ToHex(payload.id),
  token: maybeBase64ToHex(payload.token || payload.ticker_hash),
  domain: toString(payload.domain),
  adopted: maybeBase64ToHex(payload.adopted),
  approval: payload.approval !== undefined ? Boolean(payload.approval) : true,
  strategy: toString(payload.strategy),
});

export const parseProtocolUpdateLog = (payload: Record<string, unknown>): ProtocolUpdateLog => ({
  id: toString(payload.id),
  domain: toString(payload.domain),
  chainId: toString(payload.chain_id || payload.domain),
  event: toString(payload.kind || payload.event || payload.type),
  key: toString(payload.key),
  updated: toString(payload.value_bytes || payload.value_big_int || payload.value || payload.updated),
  transactionHash: toString(payload.transaction_hash || payload.tx_hash),
  timestamp: toNumber(payload.timestamp || payload.block_timestamp),
  blockNumber: toNumber(payload.block_number),
  txOrigin: toString(payload.tx_origin || payload.caller),
  txNonce: toNumber(payload.tx_nonce),
});

export const parseHubTokenUpdateLog = (payload: Record<string, unknown>): HubTokenUpdateLog => ({
  id: toString(payload.id),
  domain: toString(payload.domain),
  tickerHash: maybeBase64ToHex(payload.ticker_hash || payload.token),
  kind: toString(payload.kind || payload.field),
  feeRecipients: parseArray(payload.fee_recipients),
  feeAmounts: parseArray(payload.fee_amounts),
  maxDiscountBps: toNumber(payload.max_discount_bps),
  discountPerEpoch: toNumber(payload.discount_per_epoch),
  prioritizedStrategy: toString(payload.prioritized_strategy),
  transactionHash: toString(payload.transaction_hash || payload.tx_hash),
  timestamp: toNumber(payload.timestamp || payload.block_timestamp),
  blockNumber: toNumber(payload.block_number),
  txOrigin: toString(payload.tx_origin || payload.caller),
  txNonce: toNumber(payload.tx_nonce),
});

export const parseHubAssetUpdateLog = (payload: Record<string, unknown>): HubAssetUpdateLog => ({
  id: toString(payload.id),
  domain: toString(payload.domain),
  assetId: maybeBase64ToHex(payload.asset_id || payload.asset),
  tokenId: payload.token_id ? maybeBase64ToHex(payload.token_id) : undefined,
  tickerHash: maybeBase64ToHex(payload.ticker_hash),
  assetDomain: toString(payload.asset_domain || payload.domain),
  kind: toString(payload.kind || payload.field),
  assetHash: maybeBase64ToHex(payload.asset_hash),
  adopted: toString(payload.adopted),
  approval: payload.approval !== undefined ? Boolean(payload.approval) : false,
  strategy: toString(payload.strategy),
  transactionHash: toString(payload.transaction_hash || payload.tx_hash),
  timestamp: toNumber(payload.timestamp || payload.block_timestamp),
  blockNumber: toNumber(payload.block_number),
  txOrigin: toString(payload.tx_origin || payload.caller),
  txNonce: toNumber(payload.tx_nonce),
});
