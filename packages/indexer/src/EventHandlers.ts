import {
  EverclearSpoke_IntentAdded_handler,
  EverclearSpoke_IntentFilled_handler,
  EverclearSpoke_IntentQueueProcessed_handler,
  EverclearSpokeV5_IntentAdded_handler,
  EverclearSpokeV5_IntentFilled_handler,
  EverclearSpokeV5_IntentQueueProcessed_handler,
  FeeAdapter_IntentWithFeesAdded_handler,
  FeeAdapterV2_IntentWithFeesAdded_handler,
  FeeAdapterV2_OrderCreated_handler
} from '../generated/src/Handlers.gen';

// Helper: Convert bytes32 to address (remove leading zeros)
function bytes32ToAddress(bytes32: string): string {
  // Remove 0x prefix if present
  const hex = bytes32.startsWith('0x') ? bytes32.slice(2) : bytes32;
  // Take last 40 characters (20 bytes) and prepend 0x
  return '0x' + hex.slice(-40);
}

// Helper: Check if an address is a FeeAdapter contract
function isFeeAdapterAddress(address: string): boolean {
  const feeAdapterAddresses = [
    '0x00000000000000000000000020ff5ea948881d18f7d64b64410ec2b81f8797f4', // V2Ethereum (old)
    '0x00000000000000000000000065588b1121eb7dd41ba7d82a4f387548381584a9', // V2 Base (old)
    '0x000000000000000000000000fb1792b0992b9685be041a69a082241ce991f231', // V2 Optimism (old)
    '0x00000000000000000000000012dc8f91767021760391d691fd4bd2a642aebe2d', // V2 Arbitrum (old)
    '0x00000000000000000000000015a7ca97d1ed168fb34a4055cefa2e2f9bdb6c75', // V1 most chains
    '0x0000000000000000000000001b0dc9cb7eadda36f4ccfb8130b0ad967b0a3508', //
    '0x0000000000000000000000008ad36c1acb23b47db6573a51a8a3009d4a4bc3b1', //
    '0x00000000000000000000002944f6fef163365a382e9397b582bfbeb7c4f300', // V2 all chains (actual deployed)
  ];
  return feeAdapterAddresses.includes(address.toLowerCase());
}

/**
 * Handler for IntentAdded events
 * Creates Intent entity and updates global statistics
 */
EverclearSpoke_IntentAdded_handler(async ({ event, context }) => {
  const { _intentId, _queueIdx, _intent } = event.params;
  const chainId = event.chainId;
  const txHash = event.transaction.hash;

  context.log.info(`Processing IntentAdded: ${_intentId} on chain ${chainId}`);

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
    data,
  ] = _intent;

  // Check if Intent already exists (could be placeholder from FeeAdapter event)
  let existingIntent = await context.Intent.get(_intentId);

  // Detect if this intent was created via FeeAdapter (initiator is FeeAdapter address)
  const isViaFeeAdapter = isFeeAdapterAddress(initiator);

  // If this intent was created via FeeAdapter, we need to wait for IntentWithFeesAdded
  // to get the correct user address. Create a placeholder if no existing intent.
  if (isViaFeeAdapter && !existingIntent) {
    context.log.info(
      `Intent ${_intentId} created via FeeAdapter, creating placeholder (waiting for IntentWithFeesAdded event)`,
    );

    // Create placeholder intent with FeeAdapter as initiator temporarily
    // This will be updated when IntentWithFeesAdded event is processed
    const placeholderIntent = {
      id: _intentId,
      intentId: _intentId,
      queueIdx: _queueIdx,
      initiator, // FeeAdapter address temporarily
      receiver,
      inputAsset,
      outputAsset,
      maxFee: Number(maxFee),
      amountOutMin: 0n, // V1 doesn't have amountOutMin
      origin: Number(chainId),
      nonce,
      timestamp,
      ttl,
      originAmount: amount, // Use actual amount, not 0
      destinations: destinations.map((d) => Number(d)),
      data,
      chainId,
      blockNumber: BigInt(event.block.number),
      blockTimestamp: BigInt(event.block.timestamp),
      transactionHash: txHash,
      sender: '0x0000000000000000000000000000000000000000000000000000000000000000', // Zeroed for IntentAdded events
      receiveBlockNumber: undefined,
      isFastPath: ttl !== 0n,
      tokenFee: undefined,
      nativeFee: undefined,
      orderId: undefined, // Will be set by OrderCreated event if part of a batch order
      status: 'ADDED' as const,
    };

    context.Intent.set(placeholderIntent);

    // Update statistics for this intent
    let globalStats = await context.IntentStatistics.get('global');
    if (!globalStats) {
      globalStats = {
        id: 'global',
        totalUniqueIntents: 0n,
        totalNettableIntents: 0n,
        totalFillableIntents: 0n,
        totalFills: 0n,
      };
    }

    const isNettable = ttl === 0n;
    context.IntentStatistics.set({
      id: 'global',
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

    return; // Don't process the regular intent creation
  }

  // Create Intent entity
  const intent = {
    id: _intentId,
    intentId: _intentId,
    queueIdx: _queueIdx,
    initiator: initiator, // Always use initiator from IntentAdded event (will be FeeAdapter for FeeAdapter intents)
    receiver,
    inputAsset,
    outputAsset,
    maxFee: Number(maxFee),
    amountOutMin: 0n, // V1 doesn't have amountOutMin
    origin: Number(chainId),
    nonce,
    timestamp,
    ttl,
    originAmount: amount,
    destinations: destinations.map((d) => Number(d)),
    data,
    chainId,
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: txHash,
    sender: existingIntent?.sender || '0x0000000000000000000000000000000000000000000000000000000000000000', // Zeroed for IntentAdded events, preserve if set by FeeAdapter
    receiveBlockNumber: undefined, // Will be set when filled
    isFastPath: ttl !== 0n,
    // Preserve fee and order information if it was already set by FeeAdapter
    tokenFee: existingIntent?.tokenFee,
    nativeFee: existingIntent?.nativeFee,
    orderId: existingIntent?.orderId, // Preserve orderId if set by OrderCreated event
    status: 'ADDED' as const,
  };

  context.Intent.set(intent);

  // Update global statistics (only if this is a real intent, not updating a placeholder)
  // Placeholder intents have originAmount of 0
  const isNewIntent = !existingIntent || existingIntent.originAmount === 0n;

  if (isNewIntent) {
    let globalStats = await context.IntentStatistics.get('global');
    if (!globalStats) {
      globalStats = {
        id: 'global',
        totalUniqueIntents: 0n,
        totalNettableIntents: 0n,
        totalFillableIntents: 0n,
        totalFills: 0n,
      };
    }

    // Determine if intent is nettable (ttl == 0) or fillable (ttl != 0)
    const isNettable = ttl === 0n;

    context.IntentStatistics.set({
      id: 'global',
      totalUniqueIntents: globalStats.totalUniqueIntents + 1n,
      totalNettableIntents: globalStats.totalNettableIntents + (isNettable ? 1n : 0n),
      totalFillableIntents: globalStats.totalFillableIntents + (isNettable ? 0n : 1n),
      totalFills: globalStats.totalFills,
    });
  }

  // Update input asset statistics (only for new intents)
  if (isNewIntent) {
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
  }

  const isNettable = ttl === 0n;
  context.log.info(`Successfully processed IntentAdded: ${_intentId} (${isNettable ? 'nettable' : 'fillable'})`);
});

/**
 * Handler for IntentAdded events from EverclearSpokeV5
 * Same logic as V1 but for V5 contract
 */
EverclearSpokeV5_IntentAdded_handler(async ({ event, context }) => {
  const { _intentId, _queueIdx, _intent } = event.params;
  const chainId = event.chainId;
  const txHash = event.transaction.hash;

  context.log.info(`Processing IntentAdded (V5): ${_intentId} on chain ${chainId}`);

  // Access _intent as a tuple (V5 structure): [initiator, receiver, inputAsset, outputAsset, origin, nonce, timestamp, ttl, amount, amountOutMin, destinations, data]
  // Note: V5 uses amountOutMin instead of maxFee, so maxFee is not available in V5
  const [
    initiator,
    receiver,
    inputAsset,
    outputAsset,
    origin,
    nonce,
    timestamp,
    ttl,
    amount,
    amountOutMin,
    destinations,
    data,
  ] = _intent;

  // Check if Intent already exists (could be placeholder from FeeAdapter event)
  const existingIntent = await context.Intent.get(_intentId);

  // Detect if this intent was created via FeeAdapter (initiator is FeeAdapter address)
  const isViaFeeAdapter = isFeeAdapterAddress(initiator);
  // If this intent was created via FeeAdapter, we need to wait for IntentWithFeesAdded
  // to get the correct user address. Create a placeholder if no existing intent.
  if (isViaFeeAdapter && !existingIntent) {
    context.log.info(
      `Intent ${_intentId} created via FeeAdapter (V5), creating placeholder (waiting for IntentWithFeesAdded event)`,
    );
    // Create placeholder intent with FeeAdapter as initiator temporarily
    // This will be updated when IntentWithFeesAdded event is processed
    const placeholderIntent = {
      id: _intentId,
      intentId: _intentId,
      queueIdx: _queueIdx,
      initiator, // FeeAdapter address temporarily
      receiver,
      inputAsset,
      outputAsset,
      maxFee: 0, // V5 doesn't use maxFee, uses amountOutMin instead
      amountOutMin: amountOutMin, // V5 uses amountOutMin
      origin: Number(chainId),
      nonce,
      timestamp,
      ttl,
      originAmount: amount, // Use actual amount, not 0
      destinations: destinations.map((d) => Number(d)),
      data,
      chainId,
      blockNumber: BigInt(event.block.number),
      blockTimestamp: BigInt(event.block.timestamp),
      transactionHash: txHash,
      sender: '0x0000000000000000000000000000000000000000000000000000000000000000', // Zeroed for IntentAdded events
      receiveBlockNumber: undefined,
      isFastPath: ttl !== 0n,
      tokenFee: undefined,
      nativeFee: undefined,
      orderId: undefined, // Will be set by OrderCreated event if part of a batch order
      status: 'ADDED' as const,
    };
    context.Intent.set(placeholderIntent);
    // Update statistics for this intent
    let globalStats = await context.IntentStatistics.get('global');
    if (!globalStats) {
      globalStats = {
        id: 'global',
        totalUniqueIntents: 0n,
        totalNettableIntents: 0n,
        totalFillableIntents: 0n,
        totalFills: 0n,
      };
    }

    const isNettable = ttl === 0n;
    context.IntentStatistics.set({
      id: 'global',
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
    return; // Don't process the regular intent creation
  }

  // Create Intent entity
  const intent = {
    id: _intentId,
    intentId: _intentId,
    queueIdx: _queueIdx,
    initiator: initiator, // Always use initiator from IntentAdded event (will be FeeAdapter for FeeAdapter intents)
    receiver,
    inputAsset,
    outputAsset,
    maxFee: 0, // V5 doesn't use maxFee, uses amountOutMin instead
    amountOutMin: amountOutMin, // V5 uses amountOutMin
    origin: Number(chainId),
    nonce,
    timestamp,
    ttl,
    originAmount: amount,
    destinations: destinations.map((d) => Number(d)),
    data,
    chainId,
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: txHash,
    sender: existingIntent?.sender || '0x0000000000000000000000000000000000000000000000000000000000000000', // Zeroed for IntentAdded events, preserve if set by FeeAdapter
    receiveBlockNumber: undefined, // Will be set when filled
    isFastPath: ttl !== 0n,
    // Preserve fee and order information if it was already set by FeeAdapter
    tokenFee: existingIntent?.tokenFee,
    nativeFee: existingIntent?.nativeFee,
    orderId: existingIntent?.orderId, // Preserve orderId if set by OrderCreated event
    status: 'ADDED' as const,
  };

  context.Intent.set(intent);

  // Update global statistics (only if this is a real intent, not updating a placeholder)
  // Placeholder intents have originAmount of 0
  const isNewIntent = !existingIntent || existingIntent.originAmount === 0n;
  if (isNewIntent) {
    let globalStats = await context.IntentStatistics.get('global');
    if (!globalStats) {
      globalStats = {
        id: 'global',
        totalUniqueIntents: 0n,
        totalNettableIntents: 0n,
        totalFillableIntents: 0n,
        totalFills: 0n,
      };
    }

    // Determine if intent is nettable (ttl == 0) or fillable (ttl != 0)
    const isNettable = ttl === 0n;

    context.IntentStatistics.set({
      id: 'global',
      totalUniqueIntents: globalStats.totalUniqueIntents + 1n,
      totalNettableIntents: globalStats.totalNettableIntents + (isNettable ? 1n : 0n),
      totalFillableIntents: globalStats.totalFillableIntents + (isNettable ? 0n : 1n),
      totalFills: globalStats.totalFills,
    });
  }

  // Update input asset statistics (only for new intents)
  if (isNewIntent) {
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
  }

  const isNettable = ttl === 0n;
  context.log.info(`Successfully processed IntentAdded (V5): ${_intentId} (${isNettable ? 'nettable' : 'fillable'})`);
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

  context.log.info(`Processing IntentFilled: ${_intentId} on chain ${chainId} by solver ${_solver}`);

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
    data,
  ] = _intent;

  // Check if Intent exists - solvers should wait for intent to be in subgraph
  // This prevents counting invalid fills (edge case where fill has wrong info)
  const intent = await context.Intent.get(_intentId);
  if (!intent) {
    context.log.warn(
      `Intent ${_intentId} not found when processing Fill on chain ${chainId}. ` +
        `This fill will NOT be counted in statistics (likely invalid fill with wrong info).`,
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
    origin: Number(chainId),
    nonce,
    timestamp,
    ttl,
    originAmount: amount,
    fillAmount,
    destinations: destinations.map((d) => Number(d)),
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
    status: 'FILLED' as const,
  });

  // Update global statistics - only increment fills for valid fills
  const globalStats = await context.IntentStatistics.get('global');
  if (globalStats) {
    context.IntentStatistics.set({
      id: 'global',
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

  context.log.info(`Successfully processed IntentFilled: ${_intentId} on chain ${chainId} (valid fill)`);
});

/**
 * Handler for IntentFilled events from EverclearSpokeV5
 * V5 has different parameters: _solver, _receiver, _amountOut, _queueIdx, _intent
 * Note: V5 doesn't have _totalFeeDBPS, so we calculate fee differently
 */
EverclearSpokeV5_IntentFilled_handler(async ({ event, context }) => {
  const { _intentId, _solver, _receiver, _amountOut, _queueIdx, _intent } = event.params;
  const chainId = event.chainId;
  const txHash = event.transaction.hash;

  context.log.info(`Processing IntentFilled (V5): ${_intentId} on chain ${chainId} by solver ${_solver}`);

  // Access _intent as a tuple (V5 structure): [initiator, receiver, inputAsset, outputAsset, origin, nonce, timestamp, ttl, amount, amountOutMin, destinations, data]
  // Note: V5 uses amountOutMin instead of maxFee
  const [
    initiator,
    receiver,
    inputAsset,
    outputAsset,
    origin,
    nonce,
    timestamp,
    ttl,
    amount,
    amountOutMin,
    destinations,
    data,
  ] = _intent;

  // Check if Intent exists - solvers should wait for intent to be in subgraph
  // This prevents counting invalid fills (edge case where fill has wrong info)
  const intent = await context.Intent.get(_intentId);

  if (!intent) {
    context.log.warn(
      `Intent ${_intentId} not found when processing Fill (V5) on chain ${chainId}. ` +
        `This fill will NOT be counted in statistics (likely invalid fill with wrong info).`,
    );
    // Don't create Fill entity or update stats for invalid fills
    return;
  }

  // Calculate fee amount: originAmount - amountOut
  // In V5, the fee is the difference between input amount and output amount
  const feeAmount = amount - _amountOut;
  const fillAmount = _amountOut; // Use the actual amountOut from the event

  // Create Fill entity with unique ID (intentId-chainId-txHash)
  const fillId = `${_intentId}-${chainId}-${txHash}`;
  const fill = {
    id: fillId,
    intentId: _intentId,
    solver: _solver,
    totalFeeDBPS: 0n, // V5 doesn't use DBPS, set to 0
    queueIdx: _queueIdx,
    intent_id: _intentId,
    initiator,
    receiver,
    inputAsset,
    outputAsset,
    maxFee: 0, // V5 doesn't use maxFee, uses amountOutMin instead
    origin: Number(chainId),
    nonce,
    timestamp,
    ttl,
    originAmount: amount,
    fillAmount,
    destinations: destinations.map((d) => Number(d)),
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
    status: 'FILLED' as const,
  });

  // Update global statistics - only increment fills for valid fills
  let globalStats = await context.IntentStatistics.get('global');
  if (globalStats) {
    context.IntentStatistics.set({
      id: 'global',
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

  context.log.info(`Successfully processed IntentFilled (V5): ${_intentId} on chain ${chainId} (valid fill)`);
});

/**
 * Handler for IntentWithFeesAdded events from FeeAdapter
 * Updates Intent entity with fee information
 * Can be emitted before or after IntentAdded event
 */
FeeAdapter_IntentWithFeesAdded_handler(async ({ event, context }) => {
  const { _intentId, _initiator, _tokenFee, _nativeFee } = event.params;
  const chainId = event.chainId;

  // Convert to BigInt - handle all possible input types
  const tokenFee = BigInt(_tokenFee);
  const nativeFee = BigInt(_nativeFee);

  context.log.info(
    `Processing IntentWithFeesAdded: ${_intentId} on chain ${chainId} (tokenFee: ${tokenFee}, nativeFee: ${nativeFee})`,
  );

  // Try to load existing Intent
  let intent = await context.Intent.get(_intentId);

  if (!intent) {
    // Intent doesn't exist yet - create a placeholder Intent
    // This can happen when the FeeAdapter event is emitted before IntentAdded
    context.log.info(
      `Intent ${_intentId} not found, creating placeholder for fees (will be populated by IntentAdded event)`,
    );

    intent = {
      id: _intentId,
      intentId: _intentId,
      queueIdx: 0n, // Will be updated by IntentAdded
      initiator: '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder - will be set to FeeAdapter address by IntentAdded
      receiver: _initiator, // Placeholder, will be updated
      inputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder
      outputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder
      maxFee: 0, // Placeholder
      amountOutMin: 0n, // Placeholder (will be set by IntentAdded if V5)
      origin: chainId,
      nonce: 0n, // Placeholder
      timestamp: BigInt(event.block.timestamp),
      ttl: 0n, // Placeholder
      originAmount: 0n, // Placeholder
      destinations: [],
      data: '0x',
      chainId,
      blockNumber: BigInt(event.block.number),
      blockTimestamp: BigInt(event.block.timestamp),
      transactionHash: event.transaction.hash,
      sender: _initiator, // msg.sender from FeeAdapter IntentWithFeesAdded event
      receiveBlockNumber: undefined,
      isFastPath: false, // Placeholder
      tokenFee: tokenFee,
      nativeFee: nativeFee,
      orderId: undefined, // V1 FeeAdapter doesn't have orderId
      status: 'ADDED' as const,
    };

    context.Intent.set(intent);
  } else {
    // Intent already exists - update it with sender and fee information
    // Note: initiator is NOT updated here - it reflects what's in the intent struct
    // (which may be the FeeAdapter address if created via FeeAdapter)
    // sender is set to the actual user address (msg.sender from FeeAdapter)

    context.log.info(`Updating existing intent ${_intentId} with sender and fee information`);

    // Update intent with sender and fee information
    context.Intent.set({
      ...intent,
      sender: _initiator, // msg.sender from FeeAdapter IntentWithFeesAdded event
      tokenFee: tokenFee,
      nativeFee: nativeFee,
    });
  }

  context.log.info(`Successfully processed IntentWithFeesAdded: ${_intentId} on chain ${chainId}`);
});

/**
 * Handler for IntentWithFeesAdded events from FeeAdapterV2
 * Same logic as V1 but for V2 contract
 */
FeeAdapterV2_IntentWithFeesAdded_handler(async ({ event, context }) => {
  const { _intentId, _initiator, _tokenFee, _nativeFee } = event.params;
  const chainId = event.chainId;

  // Convert to BigInt - handle all possible input types
  const tokenFee = BigInt(_tokenFee);
  const nativeFee = BigInt(_nativeFee);

  context.log.info(
    `Processing IntentWithFeesAdded (V2): ${_intentId} on chain ${chainId} (tokenFee: ${tokenFee}, nativeFee: ${nativeFee})`,
  );

  // Try to load existing Intent
  let intent = await context.Intent.get(_intentId);

  if (!intent) {
    // Intent doesn't exist yet - create a placeholder Intent
    // This can happen when the FeeAdapter event is emitted before IntentAdded
    context.log.info(
      `Intent ${_intentId} not found, creating placeholder for fees (V2) (will be populated by IntentAdded event)`,
    );

    intent = {
      id: _intentId,
      intentId: _intentId,
      queueIdx: 0n, // Will be updated by IntentAdded
      initiator: '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder - will be set to FeeAdapter address by IntentAdded
      receiver: _initiator, // Placeholder, will be updated
      inputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder
      outputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder
      maxFee: 0, // Placeholder
      amountOutMin: 0n, // Placeholder (will be set by IntentAdded if V5)
      origin: chainId,
      nonce: 0n, // Placeholder
      timestamp: BigInt(event.block.timestamp),
      ttl: 0n, // Placeholder
      originAmount: 0n, // Placeholder
      destinations: [],
      data: '0x',
      chainId,
      blockNumber: BigInt(event.block.number),
      blockTimestamp: BigInt(event.block.timestamp),
      transactionHash: event.transaction.hash,
      sender: _initiator, // msg.sender from FeeAdapter IntentWithFeesAdded event
      receiveBlockNumber: undefined,
      isFastPath: false, // Placeholder
      tokenFee: tokenFee,
      nativeFee: nativeFee,
      orderId: undefined, // Will be set by OrderCreated event if part of a batch order
      status: 'ADDED' as const,
    };

    context.Intent.set(intent);
  } else {
    // Intent already exists - update it with sender and fee information
    // Note: initiator is NOT updated here - it reflects what's in the intent struct
    // (which may be the FeeAdapter address if created via FeeAdapter)
    // sender is set to the actual user address (msg.sender from FeeAdapter)

    context.log.info(`Updating existing intent ${_intentId} with sender and fee information (V2)`);

    // Update intent with sender and fee information
    context.Intent.set({
      ...intent,
      sender: _initiator, // msg.sender from FeeAdapter IntentWithFeesAdded event
      tokenFee: tokenFee,
      nativeFee: nativeFee,
    });
  }

  context.log.info(`Successfully processed IntentWithFeesAdded (V2): ${_intentId} on chain ${chainId}`);
});

/**
 * Handler for OrderCreated events from FeeAdapterV2
 * Updates all intents in the order with sender and divided fees
 */
FeeAdapterV2_OrderCreated_handler(async ({ event, context }: any) => {
  const { _orderId, _initiator, _intentIds, _tokenFee, _nativeFee } = event.params;
  const chainId = event.chainId;

  // Convert to BigInt
  const totalTokenFee = BigInt(_tokenFee);
  const totalNativeFee = BigInt(_nativeFee);

  context.log.info(
    `Processing OrderCreated: ${_orderId} on chain ${chainId} with ${_intentIds.length} intents (totalTokenFee: ${totalTokenFee}, totalNativeFee: ${totalNativeFee})`,
  );

  // Calculate per-intent fees by dividing by the number of intents
  const numIntents = BigInt(_intentIds.length);
  const perIntentTokenFee = totalTokenFee > 0n ? totalTokenFee / numIntents : 0n;
  const perIntentNativeFee = totalNativeFee > 0n ? totalNativeFee / numIntents : 0n;

  // Update each intent with sender, divided fees, and orderId
  for (const _intentId of _intentIds) {
    let intent = await context.Intent.get(_intentId);

    if (!intent) {
      // Intent doesn't exist yet - create a placeholder
      // This can happen when OrderCreated is emitted before IntentAdded events
      context.log.info(
        `Intent ${_intentId} not found in OrderCreated, creating placeholder (will be populated by IntentAdded event)`,
      );

      intent = {
        id: _intentId,
        intentId: _intentId,
        queueIdx: 0n, // Will be updated by IntentAdded
        initiator: '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder - will be set to FeeAdapter address by IntentAdded
        receiver: _initiator, // Placeholder, will be updated
        inputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder
        outputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000', // Placeholder
        maxFee: 0, // Placeholder
        amountOutMin: 0n, // Placeholder
        origin: chainId,
        nonce: 0n, // Placeholder
        timestamp: BigInt(event.block.timestamp),
        ttl: 0n, // Placeholder
        originAmount: 0n, // Placeholder
        destinations: [],
        data: '0x',
        chainId,
        blockNumber: BigInt(event.block.number),
        blockTimestamp: BigInt(event.block.timestamp),
        transactionHash: event.transaction.hash,
        sender: _initiator, // msg.sender from OrderCreated event
        receiveBlockNumber: undefined,
        isFastPath: false, // Placeholder
        tokenFee: perIntentTokenFee,
        nativeFee: perIntentNativeFee,
        orderId: _orderId, // Store the order ID for batch filtering
        status: 'ADDED' as const,
      };

      context.Intent.set(intent);
    } else {
      // Intent already exists - update it with sender, divided fees, and orderId
      context.Intent.set({
        ...intent,
        sender: _initiator, // msg.sender from OrderCreated event
        tokenFee: perIntentTokenFee,
        nativeFee: perIntentNativeFee,
        orderId: _orderId, // Store the order ID for batch filtering
      });
    }

    context.log.info(
      `Updated intent ${_intentId} in order ${_orderId} with sender, fees, and orderId (tokenFee: ${perIntentTokenFee}, nativeFee: ${perIntentNativeFee})`,
    );
  }

  context.log.info(`Successfully processed OrderCreated: ${_orderId} with ${_intentIds.length} intents`);
});

/**
 * Handler for IntentQueueProcessed events from EverclearSpoke
 * Updates Intent status from ADDED to DISPATCHED for all intents in the processed range
 * 
 * Event signature: IntentQueueProcessed(bytes32 indexed _messageId, uint256 _firstIdx, uint256 _lastIdx, uint256 _quote)
 */
EverclearSpoke_IntentQueueProcessed_handler(async ({ event, context }) => {
  const { _messageId, _firstIdx, _lastIdx, _quote } = event.params;
  const chainId = event.chainId;

  context.log.info(
    `Processing IntentQueueProcessed: messageId=${_messageId} on chain ${chainId}, range [${_firstIdx}, ${_lastIdx}), quote=${_quote}`,
  );

  // Query all intents on this chain that have queueIdx in the processed range
  // and update their status from ADDED to DISPATCHED
  // Note: The queueIdx corresponds to the position in the intent queue
  // We need to find intents by their queueIdx within the range [_firstIdx, _lastIdx)
  
  // Since Envio doesn't support range queries directly, we iterate through the range
  // and look up intents by their queueIdx for this chain
  const numProcessed = Number(_lastIdx) - Number(_firstIdx);
  let updatedCount = 0;

  // We can't directly query by queueIdx, so we'll query all ADDED intents on this chain
  // and filter by queueIdx. This is a limitation of the current schema.
  // For better performance, consider adding an index on queueIdx+chainId.
  
  // For now, we'll log the event details. The intents will need to be queried
  // by their queueIdx which matches their position when added to the queue.
  // The queueIdx is stored on each intent, so we can find them.
  
  context.log.info(
    `IntentQueueProcessed: ${numProcessed} intents dispatched from queue indices ${_firstIdx} to ${_lastIdx} on chain ${chainId}`,
  );

  // Note: To properly update intents, we would need to either:
  // 1. Store a mapping of queueIdx -> intentId (like the subgraph does with IntentQueueMapping)
  // 2. Query intents by queueIdx (requires schema change to add index)
  // 
  // For now, this handler logs the event. The CLI task will use on-chain data
  // to determine which intents need processing.
});

/**
 * Handler for IntentQueueProcessed events from EverclearSpokeV5
 * Same logic as V1 but for V5 contract
 */
EverclearSpokeV5_IntentQueueProcessed_handler(async ({ event, context }) => {
  const { _messageId, _firstIdx, _lastIdx, _quote } = event.params;
  const chainId = event.chainId;

  context.log.info(
    `Processing IntentQueueProcessed (V5): messageId=${_messageId} on chain ${chainId}, range [${_firstIdx}, ${_lastIdx}), quote=${_quote}`,
  );

  const numProcessed = Number(_lastIdx) - Number(_firstIdx);

  context.log.info(
    `IntentQueueProcessed (V5): ${numProcessed} intents dispatched from queue indices ${_firstIdx} to ${_lastIdx} on chain ${chainId}`,
  );
});