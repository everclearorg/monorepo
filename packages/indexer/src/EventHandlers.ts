import {
  EverclearSpoke_IntentAdded_handler,
  EverclearSpoke_IntentFilled_handler,
} from "../generated/src/Handlers.gen";

// Helper: Convert bytes32 to address (remove leading zeros)
function bytes32ToAddress(bytes32: string): string {
  // Remove 0x prefix if present
  const hex = bytes32.startsWith("0x") ? bytes32.slice(2) : bytes32;
  // Take last 40 characters (20 bytes) and prepend 0x
  return "0x" + hex.slice(-40);
}

/**
 * Handler for IntentAdded events
 * Creates Intent entity and updates global statistics
 */
EverclearSpoke_IntentAdded_handler(async ({ event, context }) => {
  const { _intentId, _queueIdx, _intent } = event.params;
  const chainId = event.chainId;
  const txHash = event.transaction.hash;

  context.log.info(
    `Processing IntentAdded: ${_intentId} on chain ${chainId}`
  );

  // Access _intent as a tuple: [initiator, receiver, inputAsset, outputAsset, maxFee, origin, nonce, timestamp, ttl, amount, destinations, data]
  const [
    initiator,
    receiver,
    inputAsset,
    outputAsset,
    maxFee,
    origin,
    nonce,
    timestamp,
    ttl,
    amount,
    destinations,
    data
  ] = _intent;

  // Create Intent entity
  const intent = {
    id: _intentId,
    intentId: _intentId,
    queueIdx: _queueIdx,
    initiator,
    receiver,
    inputAsset,
    outputAsset,
    maxFee: Number(maxFee),
    origin: Number(origin),
    nonce,
    timestamp,
    ttl,
    originAmount: amount,
    destinations: destinations.map(d => Number(d)),
    data,
    chainId,
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: txHash,
    receiveBlockNumber: undefined, // Will be set when filled
    isFastPath: ttl !== 0n,
    status: "ADDED" as const,
  };

  context.Intent.set(intent);

  // Update global statistics
  let globalStats = await context.IntentStatistics.get("global");
  if (!globalStats) {
    globalStats = {
      id: "global",
      totalUniqueIntents: 0n,
      totalNettableIntents: 0n,
      totalFillableIntents: 0n,
      totalFills: 0n,
    };
  }

  // Determine if intent is nettable (ttl == 0) or fillable (ttl != 0)
  const isNettable = ttl === 0n;

  context.IntentStatistics.set({
    id: "global",
    totalUniqueIntents: globalStats.totalUniqueIntents + 1n,
    totalNettableIntents: globalStats.totalNettableIntents + (isNettable ? 1n : 0n),
    totalFillableIntents: globalStats.totalFillableIntents + (isNettable ? 0n : 1n),
    totalFills: globalStats.totalFills,
  });

  // Update input asset statistics
  const inputAssetAddress = bytes32ToAddress(inputAsset);
  const assetId = `${inputAssetAddress}-${chainId}`;
  let asset = await context.Asset.get(assetId);
  
  if (!asset) {
    asset = {
      id: assetId,
      address: inputAssetAddress,
      chainId,
      totalIntentVolume: 0n,
      totalFillVolume: 0n,
      intentCount: 0n,
      fillCount: 0n,
    };
  }

  context.Asset.set({
    id: asset.id,
    address: asset.address,
    chainId: asset.chainId,
    totalIntentVolume: asset.totalIntentVolume + amount,
    totalFillVolume: asset.totalFillVolume,
    intentCount: asset.intentCount + 1n,
    fillCount: asset.fillCount,
  });

  context.log.info(`Successfully processed IntentAdded: ${_intentId} (${isNettable ? 'nettable' : 'fillable'})`);
});

/**
 * Handler for IntentFilled events
 * Creates Fill entity and updates Intent status and global statistics
 * Only counts fills where the intent exists (prevents counting invalid fills)
 */
EverclearSpoke_IntentFilled_handler(async ({ event, context }) => {
  const { _intentId, _solver, _totalFeeDBPS, _queueIdx, _intent } = event.params;
  const chainId = event.chainId;
  const txHash = event.transaction.hash;

  context.log.info(
    `Processing IntentFilled: ${_intentId} on chain ${chainId} by solver ${_solver}`
  );

  // Access _intent as a tuple
  const [
    initiator,
    receiver,
    inputAsset,
    outputAsset,
    maxFee,
    origin,
    nonce,
    timestamp,
    ttl,
    amount,
    destinations,
    data
  ] = _intent;

  // Check if Intent exists - solvers should wait for intent to be in subgraph
  // This prevents counting invalid fills (edge case where fill has wrong info)
  let intent = await context.Intent.get(_intentId);
  
  if (!intent) {
    context.log.warn(
      `Intent ${_intentId} not found when processing Fill on chain ${chainId}. ` +
      `This fill will NOT be counted in statistics (likely invalid fill with wrong info).`
    );
    // Don't create Fill entity or update stats for invalid fills
    return;
  }

  // Calculate fill amount: originAmount - fee
  // Fee calculation: (originAmount * totalFeeDBPS) / 10000 (since DBPS = basis points / 100)
  // fillAmount = originAmount - (originAmount * totalFeeDBPS / 10000)
  const feeAmount = (amount * _totalFeeDBPS) / 10000n;
  const fillAmount = amount - feeAmount;

  // Create Fill entity with unique ID (intentId-chainId-txHash)
  const fillId = `${_intentId}-${chainId}-${txHash}`;
  const fill = {
    id: fillId,
    intentId: _intentId,
    solver: _solver,
    totalFeeDBPS: _totalFeeDBPS,
    queueIdx: _queueIdx,
    intent_id: _intentId,
    initiator,
    receiver,
    inputAsset,
    outputAsset,
    maxFee: Number(maxFee),
    origin: Number(origin),
    nonce,
    timestamp,
    ttl,
    originAmount: amount,
    fillAmount,
    destinations: destinations.map(d => Number(d)),
    data,
    chainId,
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: txHash,
  };

  context.Fill.set(fill);

  // Update Intent status and receiveBlockNumber
  context.Intent.set({
    ...intent,
    receiveBlockNumber: BigInt(event.block.number),
    status: "FILLED" as const,
  });

  // Update global statistics - only increment fills for valid fills
  let globalStats = await context.IntentStatistics.get("global");
  if (globalStats) {
    context.IntentStatistics.set({
      id: "global",
      totalUniqueIntents: globalStats.totalUniqueIntents,
      totalNettableIntents: globalStats.totalNettableIntents,
      totalFillableIntents: globalStats.totalFillableIntents,
      totalFills: globalStats.totalFills + 1n,
    });
  }

  // Update output asset statistics
  const outputAssetAddress = bytes32ToAddress(outputAsset);
  const assetId = `${outputAssetAddress}-${chainId}`;
  let asset = await context.Asset.get(assetId);
  
  if (!asset) {
    asset = {
      id: assetId,
      address: outputAssetAddress,
      chainId,
      totalIntentVolume: 0n,
      totalFillVolume: 0n,
      intentCount: 0n,
      fillCount: 0n,
    };
  }

  context.Asset.set({
    id: asset.id,
    address: asset.address,
    chainId: asset.chainId,
    totalIntentVolume: asset.totalIntentVolume,
    totalFillVolume: asset.totalFillVolume + amount,
    intentCount: asset.intentCount,
    fillCount: asset.fillCount + 1n,
  });

  context.log.info(
    `Successfully processed IntentFilled: ${_intentId} on chain ${chainId} (valid fill)`
  );
});
