import { Address, BigInt, Bytes } from '@graphprotocol/graph-ts';
import {
  GatewayUpdated,
  LighthouseUpdated,
  MessageReceiverUpdated,
  ModuleSetForStrategy,
  StrategySetForAsset,
} from '../../../generated/EverclearSpoke/EverclearSpoke';
import { FeeRecipientUpdated as FeeRecipientUpdatedEvent } from '../../../generated/FeeAdapter/FeeAdapter';
import { Meta, ModuleForStrategy, StrategyForAsset, FeeRecipientUpdated } from '../../../generated/schema';
import { BigIntToBytes, getChainId, generateIdFromTx, generateTxNonce } from '../../common';

const SPOKE_META_ID = 'SPOKE_META_ID';

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

    meta.save();
  }

  return meta;
}

/**
 * Creates subgraph records when Paused events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handlePaused(): void {
  const meta = getOrCreateMeta();
  meta.paused = true;
  meta.save();
}

/**
 * Creates subgraph records when Unpaused events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleUnpaused(): void {
  const meta = getOrCreateMeta();
  meta.paused = false;
  meta.save();
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
}

/**
 * Creates subgraph records when ModuleSetForStrategy events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleModuleSetForStrategy(event: ModuleSetForStrategy): void {
  const strategyKey = BigIntToBytes(BigInt.fromI32(event.params._strategy));
  let entity = ModuleForStrategy.load(strategyKey);
  if (entity == null) {
    entity = new ModuleForStrategy(strategyKey);
  }

  entity.strategy = BigInt.fromI32(event.params._strategy);
  entity.module = event.params._module;
  entity.save();
}

/**
 * Creates subgraph records when FeeRecipientUpdated events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleFeeRecipientUpdated(event: FeeRecipientUpdatedEvent): void {
  // Create the FeeRecipientUpdated entity
  const log = new FeeRecipientUpdated(generateIdFromTx(event));

  log.updated = event.params._updated;
  log.previous = event.params._previous;

  // Add transaction info
  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.gasPrice = event.transaction.gasPrice;
  log.gasLimit = event.transaction.gasLimit;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();

  // Update the Meta entity with the new fee adapter recipient
  const meta = getOrCreateMeta();
  meta.feeAdapterRecipient = event.params._updated;
  meta.save();
}
