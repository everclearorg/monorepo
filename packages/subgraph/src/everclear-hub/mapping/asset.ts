import { Address, BigInt, Bytes, crypto, ethereum } from '@graphprotocol/graph-ts';
import {
  AssetConfigSet,
  TokenConfigsSet,
  MaxDiscountDbpsSet,
  PrioritizedStrategySet,
  DiscountPerEpochSet,
} from '../../../generated/EverclearHub/EverclearHub';
import { Asset, Token } from '../../../generated/schema';

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

    for (let j = 0; j < config.adoptedForAssets.length; j++) {
      const assetId = getAssetHashFromAddress(config.tickerHash, config.adoptedForAssets[j].domain);
      const asset = getOrCreateAsset(assetId, config.tickerHash);
      asset.assetHash = getAssetHashFromAddress(config.adoptedForAssets[j].adopted, config.adoptedForAssets[j].domain);
      asset.adopted = config.adoptedForAssets[j].adopted;
      asset.approval = config.adoptedForAssets[j].approval;
      asset.domain = config.adoptedForAssets[j].domain;
      asset.strategy = EverclearStrategyStrings[config.adoptedForAssets[j].strategy];

      asset.save();
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
}
