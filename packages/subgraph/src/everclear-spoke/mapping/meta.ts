import { Address, BigInt, Bytes, ethereum } from '@graphprotocol/graph-ts';
import {
  GatewayUpdated,
  LighthouseUpdated,
  MessageReceiverUpdated,
  ModuleSetForStrategy,
  StrategySetForAsset,
  Paused as PausedEvent,
  Unpaused as UnpausedEvent,
  FeeAdapterUpdated,
  MessageGasLimitUpdated,
  WatchtowerUpdated,
  FillSignerUpdated,
} from '../../../generated/EverclearSpoke/EverclearSpoke';
import {
  FeeRecipientUpdated as FeeRecipientUpdatedEvent,
  FeeSignerUpdated as FeeSignerUpdatedEvent,
} from '../../../generated/FeeAdapter/FeeAdapter';
import { Meta, ModuleForStrategy, SpokeMetaUpdate, StrategyForAsset } from '../../../generated/schema';
import { BigIntToBytes, generateIdFromTx, generateTxNonce, getChainId } from '../../common';

const SPOKE_META_ID = 'SPOKE_META_ID';

/**
 * Logs a meta update event for the spoke subgraph.
 *
 * @param kind - High-level kind identifier (e.g., 'PAUSED', 'GATEWAY_UPDATED')
 * @param event - The contract event
 * @param key - Optional key being updated (e.g., 'gateway', 'lighthouse')
 * @param valueBytes - Optional Bytes value snapshot
 * @param valueBigInt - Optional BigInt value snapshot
 */
function logSpokeMetaUpdate(
  kind: string,
  event: ethereum.Event,
  key: string | null = null,
  valueBytes: Bytes | null = null,
  valueBigInt: BigInt | null = null,
): void {
  const log = new SpokeMetaUpdate(generateIdFromTx(event));
  log.kind = kind;
  log.key = key;
  log.valueBytes = valueBytes;
  log.valueBigInt = valueBigInt;
  log.transactionHash = event.transaction.hash;
  log.timestamp = event.block.timestamp;
  log.blockNumber = event.block.number;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);
  log.save();
}

export function getOrCreateMeta(): Meta {
  const id = Bytes.fromUTF8(SPOKE_META_ID);
  let meta = Meta.load(id);
  if (meta == null) {
    meta = new Meta(id);

    meta.domain = getChainId();
    meta.paused = false;
    meta.gateway = Address.zero();
    meta.lighthouse = Address.zero();
    meta.messageReceiver = Address.zero();
    meta.watchtower = Address.zero();
    meta.messageGasLimit = BigInt.fromI32(0);
    meta.feeAdapter = Address.zero();
    meta.feeAdapterRecipient = Address.zero();
    meta.fillSigner = Address.zero();
    meta.feeSigner = Address.zero();
    meta.mailbox = Address.zero();
    meta.securityModule = Address.zero();

    meta.save();
  }

  return meta;
}

/**
 * Creates subgraph records when Paused events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handlePaused(event: PausedEvent): void {
  const meta = getOrCreateMeta();
  meta.paused = true;
  meta.save();

  logSpokeMetaUpdate('PAUSED', event, 'paused', null, BigInt.fromI32(1));
}

/**
 * Creates subgraph records when Unpaused events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleUnpaused(event: UnpausedEvent): void {
  const meta = getOrCreateMeta();
  meta.paused = false;
  meta.save();

  logSpokeMetaUpdate('UNPAUSED', event, 'paused', null, BigInt.fromI32(0));
}

/**
 * Creates subgraph records when GatewayUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleGatewayUpdated(event: GatewayUpdated): void {
  const meta = getOrCreateMeta();
  meta.gateway = event.params._newGateway;
  meta.save();

  logSpokeMetaUpdate('GATEWAY_UPDATED', event, 'gateway', event.params._newGateway, null);
}

/**
 * Creates subgraph records when LighthouseUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleLighthouseUpdated(event: LighthouseUpdated): void {
  const meta = getOrCreateMeta();
  meta.lighthouse = event.params._newLightHouse;
  meta.save();

  logSpokeMetaUpdate('LIGHTHOUSE_UPDATED', event, 'lighthouse', event.params._newLightHouse, null);
}

/**
 * Creates subgraph records when MessageReceiverUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleMessageReceiverUpdated(event: MessageReceiverUpdated): void {
  const meta = getOrCreateMeta();
  meta.messageReceiver = event.params._newMessageReceiver;
  meta.save();

  logSpokeMetaUpdate('MESSAGE_RECEIVER_UPDATED', event, 'messageReceiver', event.params._newMessageReceiver, null);
}

/**
 * Creates subgraph records when StrategySetForAsset events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleStrategySetForAsset(event: StrategySetForAsset): void {
  const asset = event.params._asset;
  let entity = StrategyForAsset.load(asset);
  if (entity == null) {
    entity = new StrategyForAsset(asset);
  }

  entity.asset = event.params._asset;
  entity.strategy = BigInt.fromI32(event.params._strategy);
  entity.save();

  logSpokeMetaUpdate(
    'STRATEGY_SET_FOR_ASSET',
    event,
    'strategyForAsset',
    event.params._asset,
    BigInt.fromI32(event.params._strategy),
  );
}

/**
 * Creates subgraph records when ModuleSetForStrategy events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleModuleSetForStrategy(event: ModuleSetForStrategy): void {
  const meta = getOrCreateMeta();
  const strategyKey = BigIntToBytes(BigInt.fromI32(event.params._strategy));
  let entity = ModuleForStrategy.load(strategyKey);
  if (entity == null) {
    entity = new ModuleForStrategy(strategyKey);
  }

  entity.meta = meta.id;
  entity.strategy = BigInt.fromI32(event.params._strategy);
  entity.module = event.params._module;
  entity.save();

  logSpokeMetaUpdate(
    'MODULE_SET_FOR_STRATEGY',
    event,
    'moduleForStrategy',
    event.params._module,
    BigInt.fromI32(event.params._strategy),
  );
}

/**
 * Creates subgraph records when FeeRecipientUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleFeeRecipientUpdated(event: FeeRecipientUpdatedEvent): void {
  // Update the Meta entity with the new fee adapter recipient
  const meta = getOrCreateMeta();
  meta.feeAdapterRecipient = event.params._updated;
  meta.save();

  logSpokeMetaUpdate('FEE_RECIPIENT_UPDATED', event, 'feeAdapterRecipient', event.params._updated, null);
}

/**
 * Creates subgraph records when FeeAdapterUpdated events are emitted (Spoke).
 */
export function handleFeeAdapterUpdated(event: FeeAdapterUpdated): void {
  const meta = getOrCreateMeta();
  meta.feeAdapter = event.params._newFeeAdapter;
  meta.save();

  logSpokeMetaUpdate('FEE_ADAPTER_UPDATED', event, 'feeAdapter', event.params._newFeeAdapter, null);
}

/**
 * Creates subgraph records when MessageGasLimitUpdated events are emitted.
 */
export function handleMessageGasLimitUpdated(event: MessageGasLimitUpdated): void {
  const meta = getOrCreateMeta();
  meta.messageGasLimit = event.params._newGasLimit;
  meta.save();

  logSpokeMetaUpdate('MESSAGE_GAS_LIMIT_UPDATED', event, 'messageGasLimit', null, event.params._newGasLimit);
}

/**
 * Creates subgraph records when WatchtowerUpdated events are emitted.
 */
export function handleWatchtowerUpdated(event: WatchtowerUpdated): void {
  const meta = getOrCreateMeta();
  meta.watchtower = event.params._newWatchtower;
  meta.save();

  logSpokeMetaUpdate('WATCHTOWER_UPDATED', event, 'watchtower', event.params._newWatchtower, null);
}

/**
 * Creates subgraph records when FillSignerUpdated events are emitted (Spoke).
 */
export function handleFillSignerUpdated(event: FillSignerUpdated): void {
  const meta = getOrCreateMeta();
  meta.fillSigner = event.params._newFillSigner;
  meta.save();

  logSpokeMetaUpdate('FILL_SIGNER_UPDATED', event, 'fillSigner', event.params._newFillSigner, null);
}

/**
 * Creates subgraph records when FeeSignerUpdated events are emitted (FeeAdapter).
 */
export function handleFeeSignerUpdated(event: FeeSignerUpdatedEvent): void {
  const meta = getOrCreateMeta();
  meta.feeSigner = event.params._updated;
  meta.save();

  logSpokeMetaUpdate('FEE_SIGNER_UPDATED', event, 'feeSigner', event.params._updated, null);
}
