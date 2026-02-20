import { Address, BigInt, Bytes, crypto, ethereum } from '@graphprotocol/graph-ts';
import {
  AssetConfigSet,
  TokenConfigsSet,
  MaxDiscountDbpsSet,
  PrioritizedStrategySet,
  DiscountPerEpochSet,
} from '../../../generated/EverclearHub/EverclearHub';
import { Asset, HubAssetUpdate, HubTokenUpdate, Token } from '../../../generated/schema';
import { generateIdFromTx, generateTxNonce } from '../../common';

enum EverclearStrategy {
  DEFAULT,
  XERC20,
}
const EverclearStrategyStrings = ['DEFAULT', 'XERC20'];

function getOrCreateAsset(id: Bytes, tickerHash: Bytes): Asset {
  let asset = Asset.load(id);
  if (asset == null) {
    asset = new Asset(id);
    asset.assetHash = Bytes.empty();
    asset.adopted = Address.zero();
    asset.approval = true;
    asset.strategy = EverclearStrategyStrings[EverclearStrategy.DEFAULT];
  }
  asset.token = getOrCreateToken(tickerHash).id;
  asset.save();

  return asset;
}

function getOrCreateToken(id: Bytes): Token {
  let token = Token.load(id);
  if (token == null) {
    token = new Token(id);
    token.feeRecipients = [];
    token.feeAmounts = [];
    token.maxDiscountBps = new BigInt(0);
    token.discountPerEpoch = new BigInt(0);
    token.prioritizedStrategy = EverclearStrategyStrings[EverclearStrategy.DEFAULT];
    token.initLastClosedEpochProcessed = false;
    token.save();
  }
  return token;
}

/**
 * Logs a token update event on the hub.
 */
function logHubTokenUpdate(
  kind: string,
  event: ethereum.Event,
  token: Token,
): void {
  logHubTokenUpdateWithId(kind, event, token, generateIdFromTx(event));
}

/**
 * Logs a token update event on the hub with a custom ID.
 * Use this when you need multiple logs in one transaction (e.g., batch operations).
 */
function logHubTokenUpdateWithId(
  kind: string,
  event: ethereum.Event,
  token: Token,
  id: Bytes,
): void {
  const log = new HubTokenUpdate(id);

  log.kind = kind;
  log.token = token.id;

  // Optional snapshots for richer history queries
  if (token.feeRecipients != null) log.feeRecipients = token.feeRecipients;
  if (token.feeAmounts != null) log.feeAmounts = token.feeAmounts;
  log.maxDiscountBps = token.maxDiscountBps;
  log.discountPerEpoch = token.discountPerEpoch;
  log.prioritizedStrategy = token.prioritizedStrategy;

  log.transactionHash = event.transaction.hash;
  log.timestamp = event.block.timestamp;
  log.blockNumber = event.block.number;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();
}

/**
 * Logs an asset update event on the hub.
 */
function logHubAssetUpdate(
  kind: string,
  event: ethereum.Event,
  asset: Asset,
  tokenId: Bytes | null = null,
  tickerHash: Bytes | null = null,
  domain: BigInt | null = null,
): void {
  logHubAssetUpdateWithId(
    kind,
    event,
    asset,
    tokenId,
    tickerHash,
    domain,
    generateIdFromTx(event),
  );
}

/**
 * Logs an asset update event on the hub with a custom ID.
 * Use this when you need multiple logs in one transaction (e.g., batch operations).
 */
function logHubAssetUpdateWithId(
  kind: string,
  event: ethereum.Event,
  asset: Asset,
  tokenId: Bytes | null,
  tickerHash: Bytes | null,
  domain: BigInt | null,
  id: Bytes,
): void {
  const log = new HubAssetUpdate(id);

  log.kind = kind;
  log.asset = asset.id;
  log.token = tokenId;
  log.tickerHash = tickerHash;
  log.domain = domain;

  // Optional snapshots for richer history queries
  log.assetHash = asset.assetHash;
  log.adopted = asset.adopted;
  log.approval = asset.approval;
  log.strategy = asset.strategy;

  log.transactionHash = event.transaction.hash;
  log.timestamp = event.block.timestamp;
  log.blockNumber = event.block.number;
  log.txOrigin = event.transaction.from;
  log.txNonce = generateTxNonce(event);

  log.save();
}

// eslint-disable-next-line @typescript-eslint/ban-types
function getAssetHashFromAddress(address: Bytes, domain: BigInt): Bytes {
  const params = new ethereum.Tuple();
  params.push(ethereum.Value.fromBytes(address));
  params.push(ethereum.Value.fromUnsignedBigInt(domain));

  const encoded = ethereum.encode(ethereum.Value.fromTuple(params))!;
  return Bytes.fromByteArray(crypto.keccak256(encoded));
}

/**
 * Creates subgraph records when AssetConfigSet events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleAssetConfigSet(event: AssetConfigSet): void {
  const id = getAssetHashFromAddress(event.params._config.tickerHash, event.params._config.domain);
  const asset = getOrCreateAsset(id, event.params._config.tickerHash);

  asset.assetHash = getAssetHashFromAddress(event.params._config.adopted, event.params._config.domain);
  asset.adopted = event.params._config.adopted;
  asset.approval = event.params._config.approval;
  asset.domain = event.params._config.domain;
  asset.strategy = EverclearStrategyStrings[event.params._config.strategy];

  asset.save();

  logHubAssetUpdate(
    'ASSET_CONFIG_SET',
    event,
    asset,
    asset.token,
    event.params._config.tickerHash,
    event.params._config.domain,
  );
}

/**
 * Creates subgraph records when TokenConfigsSet events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleTokenConfigsSet(event: TokenConfigsSet): void {
  for (let i = 0; i < event.params._configs.length; i++) {
    const config = event.params._configs[i];

    const token = getOrCreateToken(config.tickerHash);
    const feeRecipients: Bytes[] = [];
    // eslint-disable-next-line @typescript-eslint/ban-types
    const feeAmounts: BigInt[] = [];
    for (let j = 0; j < config.fees.length; j++) {
      feeRecipients.push(config.fees[j].recipient);
      feeAmounts.push(BigInt.fromI32(config.fees[j].fee));
    }
    token.feeAmounts = feeAmounts;
    token.feeRecipients = feeRecipients;
    token.maxDiscountBps = BigInt.fromI32(config.maxDiscountDbps);
    token.discountPerEpoch = BigInt.fromI32(config.discountPerEpoch);
    token.prioritizedStrategy = EverclearStrategyStrings[config.prioritizedStrategy];
    token.save();

    const tokenLogId = generateIdFromTx(event).concatI32(i);
    logHubTokenUpdateWithId('TOKEN_CONFIGS_SET', event, token, tokenLogId);

    for (let j = 0; j < config.adoptedForAssets.length; j++) {
      const assetId = getAssetHashFromAddress(config.tickerHash, config.adoptedForAssets[j].domain);
      const asset = getOrCreateAsset(assetId, config.tickerHash);
      asset.assetHash = getAssetHashFromAddress(config.adoptedForAssets[j].adopted, config.adoptedForAssets[j].domain);
      asset.adopted = config.adoptedForAssets[j].adopted;
      asset.approval = config.adoptedForAssets[j].approval;
      asset.domain = config.adoptedForAssets[j].domain;
      asset.strategy = EverclearStrategyStrings[config.adoptedForAssets[j].strategy];

      asset.save();

      const assetLogId = generateIdFromTx(event).concatI32(i).concatI32(j);
      logHubAssetUpdateWithId(
        'TOKEN_CONFIGS_SET_ASSET',
        event,
        asset,
        token.id,
        config.tickerHash,
        config.adoptedForAssets[j].domain,
        assetLogId,
      );
    }
  }
}

/**
 * Creates subgraph records when MaxDiscountDbpsSet events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleMaxDiscountDbpsSet(event: MaxDiscountDbpsSet): void {
  const config = getOrCreateToken(event.params._tickerHash);
  config.maxDiscountBps = BigInt.fromI32(event.params._newMaxDiscountDbps);
  config.save();

  logHubTokenUpdate('MAX_DISCOUNT_DBPS_SET', event, config);
}

/**
 * Creates subgraph records when PrioritizedStrategySet events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handlePrioritizedStrategySet(event: PrioritizedStrategySet): void {
  const config = getOrCreateToken(event.params._tickerHash);
  config.prioritizedStrategy = EverclearStrategyStrings[event.params._strategy];
  config.save();

  logHubTokenUpdate('PRIORITIZED_STRATEGY_SET', event, config);
}

/**
 * Creates subgraph records when DiscountPerEpochSet events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleDiscountPerEpochSet(event: DiscountPerEpochSet): void {
  const config = getOrCreateToken(event.params._tickerHash);
  config.discountPerEpoch = BigInt.fromI32(event.params._newDiscountPerEpoch);
  config.save();

  logHubTokenUpdate('DISCOUNT_PER_EPOCH_SET', event, config);
}
