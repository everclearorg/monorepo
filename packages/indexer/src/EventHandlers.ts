import {
  EverclearSpoke_IntentAdded_handler,
  EverclearSpoke_IntentFilled_handler,
  EverclearSpoke_IntentQueueProcessed_handler,
  EverclearSpoke_Deposited_handler,
  EverclearSpoke_Withdrawn_handler,
  EverclearSpoke_Settled_handler,
  EverclearSpoke_FillQueueProcessed_handler,
  EverclearSpoke_ExternalCalldataExecuted_handler,
  EverclearSpoke_AssetTransferFailed_handler,
  EverclearSpoke_AssetMintFailed_handler,
  EverclearSpokeV5_IntentAdded_handler,
  EverclearSpokeV5_IntentFilled_handler,
  EverclearSpokeV5_IntentQueueProcessed_handler,
  EverclearSpokeV5_Deposited_handler,
  EverclearSpokeV5_Withdrawn_handler,
  EverclearSpokeV5_Settled_handler,
  EverclearSpokeV5_FillQueueProcessed_handler,
  EverclearSpokeV5_ExternalCalldataExecuted_handler,
  EverclearSpokeV5_AssetTransferFailed_handler,
  EverclearSpokeV5_AssetMintFailed_handler,
  EverclearSpokeV5_Paused_handler,
  EverclearSpokeV5_Unpaused_handler,
  EverclearSpokeV5_GatewayUpdated_handler,
  EverclearSpokeV5_LighthouseUpdated_handler,
  FeeAdapter_IntentWithFeesAdded_handler,
  FeeAdapterV2_IntentWithFeesAdded_handler,
  FeeAdapterV2_OrderCreated_handler,
  EverclearHubV2_SettlementEnqueued_handler,
  EverclearHubV2_IntentProcessed_handler,
  EverclearHubV2_FillProcessed_handler,
  EverclearHubV2_SettlementQueueProcessed_handler,
  EverclearHubV2_InvoiceEnqueued_handler,
  EverclearHubV2_DepositEnqueued_handler,
  EverclearHubV2_DepositProcessed_handler,
  EverclearHubV2_FeesWithdrawn_handler,
  EverclearHubV2_ReturnUnsupportedIntent_handler,
  EverclearHubV2_TokenConfigsSet_handler,
  EverclearHubV2_AssetConfigSet_handler,
  EverclearHubV2_MaxDiscountDbpsSet_handler,
  EverclearHubV2_PrioritizedStrategySet_handler,
  EverclearHubV2_DiscountPerEpochSet_handler,
  EverclearHubV2_SolverConfigUpdated_handler,
  EverclearHubV2_IncreaseVirtualBalanceSet_handler,
  EverclearHubV2_Paused_handler,
  EverclearHubV2_Unpaused_handler,
  EverclearHubV2_OwnershipTransferred_handler,
  EverclearHubV2_OwnershipProposed_handler,
  EverclearHubV2_GatewayUpdated_handler,
  EverclearHubV2_AcceptanceDelayUpdated_handler,
  EverclearHubV2_MinSolverSupportedDomainsUpdated_handler,
  EverclearHubV2_EpochLengthUpdated_handler,
  EverclearHubV2_ExpiryTimeBufferUpdated_handler,
  EverclearHubV2_SupportedDomainsAdded_handler,
  EverclearHubV2_SupportedDomainsRemoved_handler,
  EverclearHubV2_WatchtowerUpdated_handler,
  EverclearHubV2_MailboxUpdated_handler,
  EverclearHubV2_SecurityModuleUpdated_handler,
  EverclearSpokeV5_MessageReceiverUpdated_handler,
  EverclearSpokeV5_WatchtowerUpdated_handler,
  EverclearSpokeV5_MessageGasLimitUpdated_handler,
  EverclearSpokeV5_FeeAdapterUpdated_handler,
  EverclearSpokeV5_FillSignerUpdated_handler,
} from '../generated/src/Handlers.gen';

import type { HubIntentStatus_t } from '../generated/src/db/Enums.gen';

// Helper: Convert bytes32 to address (remove leading zeros)
function bytes32ToAddress(bytes32: string): string {
  // Remove 0x prefix if present
  const hex = bytes32.startsWith('0x') ? bytes32.slice(2) : bytes32;
  // Take last 40 characters (20 bytes) and prepend 0x
  return '0x' + hex.slice(-40);
}

// Helper: Extract transaction metadata from event
function getTxMeta(event: any) {
  return {
    txOrigin: event.transaction.from ?? undefined,
    gasPrice: event.transaction.gasPrice != null ? BigInt(event.transaction.gasPrice) : undefined,
    txNonce: undefined as bigint | undefined, // Not available via Envio RPC chains
    gasLimit: undefined as bigint | undefined, // Not available via Envio field_selection
  };
}

// Helper: Check if an address is a FeeAdapter contract
function isFeeAdapterAddress(address: string): boolean {
  const feeAdapterAddresses = [
    // Production V2 addresses (from MainnetProduction.sol)
    "0x00000000000000000000000015a7ca97d1ed168fb34a4055cefa2e2f9bdb6c75", // Ethereum, Arbitrum, Optimism, Base, BNB, Polygon, Avalanche, Zircuit, Blast, Mode
    "0x0000000000000000000000001b0dc9cb7eadda36f4ccfb8130b0ad967b0a3508", // Linea
    "0x0000000000000000000000008ad36c1acb23b47db6573a51a8a3009d4a4bc3b1", // Scroll, Unichain
    "0x00000000000000000000000080ef3ee093ae3b5add1b213628875a4c73f640af", // zkSync
    "0x0000000000000000000000006dea30929a575b8b29f459aae1b3b85e52a723f4", // Gnosis, Berachain, Mantle, Sonic, Ink
    "0x000000000000000000000000a388d644241a2185440eaf0add41c9da30958ba5", // TAC
    "0x000000000000000000000000b7c258c548aff20bbb2e899477b3bb9e8f813ed4", // Plasma
    // Legacy addresses (for historical event detection)
    "0x000000000000000000000000d0185bfb8107c5b2336bc73ce3fdd9bfb504540e", // Legacy V2
    "0x000000000000000000000000aa7ee09f745a3c5de329eb0cd67878ba87b70ffe", // Legacy Linea
    "0x000000000000000000000000877fd0a881b63ebe413124eee6abbcd7e82cf10b", // Legacy Unichain/Ink
    "0x000000000000000000000000a537f0d027cba1661dd1eb46fcd79030cd75a2cd", // Legacy zkSync
    "0x000000000000000000000000e5f2f4afad6211cfbd6a882d5a6a435530ee3909", // Legacy Zircuit
    "0x0000000000000000000000003c135048306b412ad8f4375f6a8cbe94b5d56184", // Legacy Berachain
  ];
  return feeAdapterAddresses.includes(address.toLowerCase());
}

const StrategyStrings = ['DEFAULT', 'XERC20'];

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

// ============================================================================
// SPOKE HANDLERS — IntentAdded (V1 + V5)
// ============================================================================

async function handleIntentAdded({ event, context, isV5 }: { event: any; context: any; isV5: boolean }) {
  const { _intentId, _queueIdx, _intent } = event.params;
  const chainId = event.chainId;
  const txHash = event.transaction.hash;
  const txMeta = getTxMeta(event);

  let initiator: string, receiver: string, inputAsset: string, outputAsset: string,
    origin: any, nonce: bigint, timestamp: bigint, ttl: bigint, amount: bigint,
    destinations: any[], data: string;
  let maxFee = 0;
  let amountOutMin = 0n;

  if (isV5) {
    [initiator, receiver, inputAsset, outputAsset, origin, nonce, timestamp, ttl, amount, amountOutMin, destinations, data] = _intent;
  } else {
    let maxFeeRaw: any;
    [initiator, receiver, inputAsset, outputAsset, maxFeeRaw, origin, nonce, timestamp, ttl, amount, destinations, data] = _intent;
    maxFee = Number(maxFeeRaw);
  }

  const existingIntent = await context.Intent.get(_intentId);
  const isViaFeeAdapter = isFeeAdapterAddress(initiator);

  const intentData = {
    id: _intentId,
    intentId: _intentId,
    queueIdx: _queueIdx,
    initiator,
    receiver,
    inputAsset,
    outputAsset,
    maxFee,
    amountOutMin,
    origin: Number(chainId),
    nonce,
    timestamp,
    ttl,
    originAmount: amount,
    destinations: destinations.map((d: any) => Number(d)),
    data,
    chainId,
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: txHash,
    sender: existingIntent?.sender || '0x0000000000000000000000000000000000000000000000000000000000000000',
    ...txMeta,
    receiveBlockNumber: undefined as bigint | undefined,
    isFastPath: ttl !== 0n,
    tokenFee: existingIntent?.tokenFee,
    nativeFee: existingIntent?.nativeFee,
    orderId: existingIntent?.orderId,
    status: existingIntent?.status === 'SETTLED' ? 'SETTLED' as const : 'ADDED' as const,
  };

  if (isViaFeeAdapter && !existingIntent) {
    intentData.sender = '0x0000000000000000000000000000000000000000000000000000000000000000';
  }

  context.Intent.set(intentData);

  const isNewIntent = !existingIntent || existingIntent.originAmount === 0n;
  if (isNewIntent) {
    let globalStats = await context.IntentStatistics.get('global');
    if (!globalStats) {
      globalStats = { id: 'global', totalUniqueIntents: 0n, totalNettableIntents: 0n, totalFillableIntents: 0n, totalFills: 0n };
    }
    const isNettable = ttl === 0n;
    context.IntentStatistics.set({
      id: 'global',
      totalUniqueIntents: globalStats.totalUniqueIntents + 1n,
      totalNettableIntents: globalStats.totalNettableIntents + (isNettable ? 1n : 0n),
      totalFillableIntents: globalStats.totalFillableIntents + (isNettable ? 0n : 1n),
      totalFills: globalStats.totalFills,
    });

    const inputAssetAddress = bytes32ToAddress(inputAsset);
    const assetId = `${inputAssetAddress}-${chainId}`;
    let asset = await context.Asset.get(assetId);
    if (!asset) {
      asset = { id: assetId, address: inputAssetAddress, chainId, totalIntentVolume: 0n, totalFillVolume: 0n, intentCount: 0n, fillCount: 0n };
    }
    context.Asset.set({ ...asset, totalIntentVolume: asset.totalIntentVolume + amount, intentCount: asset.intentCount + 1n });

    const ubAsset = bytes32ToAddress(inputAsset);
    let ub = await context.UnclaimedBalance.get(ubAsset);
    context.UnclaimedBalance.set({ id: ubAsset, amount: (ub?.amount ?? 0n) + amount });
  }

  // Update Intent Queue
  const queueId = `${chainId}-INTENT`;
  let queue = await context.Queue.get(queueId);
  if (!queue) {
    queue = { id: queueId, queueType: 'INTENT' as const, lastProcessed: undefined, size: 0n, first: 1n, last: 0n, chainId };
  }
  context.Queue.set({ ...queue, last: queue.last + 1n, size: queue.size + 1n });
  context.IntentQueueMapping.set({ id: `${chainId}-${_queueIdx}`, intentId: _intentId, chainId });
}

EverclearSpoke_IntentAdded_handler(async ({ event, context }) => {
  await handleIntentAdded({ event, context, isV5: false });
});

EverclearSpokeV5_IntentAdded_handler(async ({ event, context }) => {
  await handleIntentAdded({ event, context, isV5: true });
});

// ============================================================================
// SPOKE HANDLERS — IntentFilled (V1 + V5)
// ============================================================================

async function handleIntentFilled({ event, context, isV5 }: { event: any; context: any; isV5: boolean }) {
  const chainId = event.chainId;
  const txHash = event.transaction.hash;
  const txMeta = getTxMeta(event);

  let _intentId: string, _solver: string, _queueIdx: bigint, _intent: any;
  let fillAmount: bigint;

  if (isV5) {
    const params = event.params;
    _intentId = params._intentId;
    _solver = params._solver;
    _queueIdx = params._queueIdx;
    _intent = params._intent;
    fillAmount = params._amountOut;
  } else {
    const params = event.params;
    _intentId = params._intentId;
    _solver = params._solver;
    _queueIdx = params._queueIdx;
    _intent = params._intent;
    fillAmount = 0n; // Will be calculated below after destructuring
  }

  let initiator: string, receiver: string, inputAsset: string, outputAsset: string,
    nonce: bigint, timestamp: bigint, ttl: bigint, amount: bigint, destinations: any[], data: string;
  let maxFee = 0;

  if (isV5) {
    [initiator, receiver, inputAsset, outputAsset, , nonce, timestamp, ttl, amount, , destinations, data] = _intent;
  } else {
    let maxFeeRaw: any;
    [initiator, receiver, inputAsset, outputAsset, maxFeeRaw, , nonce, timestamp, ttl, amount, destinations, data] = _intent;
    maxFee = Number(maxFeeRaw);
    const _totalFeeDBPS = event.params._totalFeeDBPS;
    const feeAmount = (amount * _totalFeeDBPS) / 10000n;
    fillAmount = amount - feeAmount;
  }

  const intent = await context.Intent.get(_intentId);
  if (!intent) {
    return;
  }

  const fillId = `${_intentId}-${chainId}-${txHash}`;
  context.Fill.set({
    id: fillId,
    intentId: _intentId,
    solver: _solver,
    totalFeeDBPS: isV5 ? 0n : event.params._totalFeeDBPS,
    queueIdx: _queueIdx,
    intent_id: _intentId,
    initiator, receiver, inputAsset, outputAsset, maxFee,
    origin: Number(chainId), nonce, timestamp, ttl,
    originAmount: amount, fillAmount,
    destinations: destinations.map((d: any) => Number(d)),
    data, chainId,
    blockNumber: BigInt(event.block.number),
    blockTimestamp: BigInt(event.block.timestamp),
    transactionHash: txHash,
    ...txMeta,
  });

  context.Intent.set({
    ...intent,
    receiveBlockNumber: BigInt(event.block.number),
    status: intent.status === 'SETTLED' ? 'SETTLED' as const : 'FILLED' as const,
  });

  const globalStats = await context.IntentStatistics.get('global');
  if (globalStats) {
    context.IntentStatistics.set({
      ...globalStats,
      totalFills: globalStats.totalFills + 1n,
    });
  }

  const outputAssetAddress = bytes32ToAddress(outputAsset);
  const assetId = `${outputAssetAddress}-${chainId}`;
  let asset = await context.Asset.get(assetId);
  if (!asset) {
    asset = { id: assetId, address: outputAssetAddress, chainId, totalIntentVolume: 0n, totalFillVolume: 0n, intentCount: 0n, fillCount: 0n };
  }
  context.Asset.set({ ...asset, totalFillVolume: asset.totalFillVolume + amount, fillCount: asset.fillCount + 1n });

  const fillQueueId = `${chainId}-FILL`;
  let fillQueue = await context.Queue.get(fillQueueId);
  if (!fillQueue) {
    fillQueue = { id: fillQueueId, queueType: 'FILL' as const, lastProcessed: undefined, size: 0n, first: 1n, last: 0n, chainId };
  }
  context.Queue.set({ ...fillQueue, last: fillQueue.last + 1n, size: fillQueue.size + 1n });
  context.FillQueueMapping.set({ id: `${chainId}-${_queueIdx}`, intentId: _intentId, chainId });
}

EverclearSpoke_IntentFilled_handler(async ({ event, context }) => {
  await handleIntentFilled({ event, context, isV5: false });
});

EverclearSpokeV5_IntentFilled_handler(async ({ event, context }) => {
  await handleIntentFilled({ event, context, isV5: true });
});

// ============================================================================
// SPOKE HANDLERS — IntentWithFeesAdded (FeeAdapter V1 + V2)
// ============================================================================

async function handleIntentWithFeesAdded({ event, context }: { event: any; context: any }) {
  const { _intentId, _initiator, _tokenFee, _nativeFee } = event.params;
  const chainId = event.chainId;
  const txMeta = getTxMeta(event);
  const tokenFee = BigInt(_tokenFee);
  const nativeFee = BigInt(_nativeFee);

  let intent = await context.Intent.get(_intentId);

  if (!intent) {
    intent = {
      id: _intentId, intentId: _intentId, queueIdx: 0n,
      initiator: '0x0000000000000000000000000000000000000000000000000000000000000000',
      receiver: _initiator,
      inputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000',
      outputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000',
      maxFee: 0, amountOutMin: 0n, origin: chainId, nonce: 0n,
      timestamp: BigInt(event.block.timestamp), ttl: 0n, originAmount: 0n,
      destinations: [], data: '0x', chainId,
      blockNumber: BigInt(event.block.number), blockTimestamp: BigInt(event.block.timestamp),
      transactionHash: event.transaction.hash,
      sender: _initiator, ...txMeta,
      receiveBlockNumber: undefined, isFastPath: false,
      tokenFee, nativeFee, orderId: undefined, status: 'ADDED' as const,
    };
    context.Intent.set(intent);
  } else {
    context.Intent.set({ ...intent, sender: _initiator, tokenFee, nativeFee });
  }
}

FeeAdapter_IntentWithFeesAdded_handler(async ({ event, context }) => {
  await handleIntentWithFeesAdded({ event, context });
});

FeeAdapterV2_IntentWithFeesAdded_handler(async ({ event, context }) => {
  await handleIntentWithFeesAdded({ event, context });
});

// ============================================================================
// SPOKE HANDLERS — OrderCreated (FeeAdapterV2)
// ============================================================================

FeeAdapterV2_OrderCreated_handler(async ({ event, context }) => {
  const { _orderId, _initiator, _intentIds, _tokenFee, _nativeFee } = event.params;
  const chainId = event.chainId;
  const txMeta = getTxMeta(event);
  const totalTokenFee = BigInt(_tokenFee);
  const totalNativeFee = BigInt(_nativeFee);

  // Create standalone Order entity
  context.Order.set({
    id: _orderId,
    initiator: _initiator,
    intentIds: [..._intentIds],
    tokenFee: totalTokenFee,
    nativeFee: totalNativeFee,
    transactionHash: event.transaction.hash,
    timestamp: BigInt(event.block.timestamp),
    blockNumber: BigInt(event.block.number),
    ...txMeta,
    chainId,
  });

  const numIntents = BigInt(_intentIds.length);
  const perIntentTokenFee = totalTokenFee > 0n ? totalTokenFee / numIntents : 0n;
  const perIntentNativeFee = totalNativeFee > 0n ? totalNativeFee / numIntents : 0n;

  for (const _intentId of _intentIds) {
    let intent = await context.Intent.get(_intentId);
    if (!intent) {
      intent = {
        id: _intentId, intentId: _intentId, queueIdx: 0n,
        initiator: '0x0000000000000000000000000000000000000000000000000000000000000000',
        receiver: _initiator,
        inputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000',
        outputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000',
        maxFee: 0, amountOutMin: 0n, origin: chainId, nonce: 0n,
        timestamp: BigInt(event.block.timestamp), ttl: 0n, originAmount: 0n,
        destinations: [], data: '0x', chainId,
        blockNumber: BigInt(event.block.number), blockTimestamp: BigInt(event.block.timestamp),
        transactionHash: event.transaction.hash,
        sender: _initiator, ...txMeta,
        receiveBlockNumber: undefined, isFastPath: false,
        tokenFee: perIntentTokenFee, nativeFee: perIntentNativeFee,
        orderId: _orderId, status: 'ADDED' as const,
      };
      context.Intent.set(intent);
    } else {
      context.Intent.set({
        ...intent, sender: _initiator,
        tokenFee: perIntentTokenFee, nativeFee: perIntentNativeFee, orderId: _orderId,
      });
    }
  }
});

// ============================================================================
// SPOKE HANDLERS — IntentQueueProcessed / FillQueueProcessed
// ============================================================================

async function handleIntentQueueProcessed({ event, context }: { event: any; context: any }) {
  const { _messageId, _firstIdx, _lastIdx, _quote } = event.params;
  const chainId = event.chainId;
  const txMeta = getTxMeta(event);

  const intentIds: string[] = [];
  const length = Number(_lastIdx - _firstIdx);
  for (let idx = 0; idx < length; idx++) {
    const mappingId = `${chainId}-${_firstIdx + BigInt(idx)}`;
    const mapping = await context.IntentQueueMapping.get(mappingId);
    if (mapping) {
      intentIds.push(mapping.intentId);
      const intent = await context.Intent.get(mapping.intentId);
      if (intent && intent.status === 'ADDED') {
        context.Intent.set({ ...intent, status: 'DISPATCHED' as const });
      }
    }
  }

  context.Message.set({
    id: _messageId, messageType: 'INTENT' as const,
    quote: _quote, firstIdx: _firstIdx, lastIdx: _lastIdx, intentIds,
    transactionHash: event.transaction.hash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    ...txMeta, chainId,
  });

  const queueId = `${chainId}-INTENT`;
  let queue = await context.Queue.get(queueId);
  if (queue) {
    context.Queue.set({ ...queue, first: _lastIdx, size: queue.size - (_lastIdx - _firstIdx), lastProcessed: BigInt(event.block.timestamp) });
  }
}

EverclearSpoke_IntentQueueProcessed_handler(async ({ event, context }) => {
  await handleIntentQueueProcessed({ event, context });
});

EverclearSpokeV5_IntentQueueProcessed_handler(async ({ event, context }) => {
  await handleIntentQueueProcessed({ event, context });
});

async function handleFillQueueProcessed({ event, context }: { event: any; context: any }) {
  const { _messageId, _firstIdx, _lastIdx, _quote } = event.params;
  const chainId = event.chainId;
  const txMeta = getTxMeta(event);

  const intentIds: string[] = [];
  const length = Number(_lastIdx - _firstIdx);
  for (let idx = 0; idx < length; idx++) {
    const mappingId = `${chainId}-${_firstIdx + BigInt(idx)}`;
    const mapping = await context.FillQueueMapping.get(mappingId);
    if (mapping) {
      intentIds.push(mapping.intentId);
    }
  }

  context.Message.set({
    id: _messageId, messageType: 'FILL' as const,
    quote: _quote, firstIdx: _firstIdx, lastIdx: _lastIdx, intentIds,
    transactionHash: event.transaction.hash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    ...txMeta, chainId,
  });

  const queueId = `${chainId}-FILL`;
  let queue = await context.Queue.get(queueId);
  if (queue) {
    context.Queue.set({ ...queue, first: _lastIdx, size: queue.size - (_lastIdx - _firstIdx), lastProcessed: BigInt(event.block.timestamp) });
  }
}

EverclearSpoke_FillQueueProcessed_handler(async ({ event, context }) => {
  await handleFillQueueProcessed({ event, context });
});

EverclearSpokeV5_FillQueueProcessed_handler(async ({ event, context }) => {
  await handleFillQueueProcessed({ event, context });
});

// ============================================================================
// SPOKE HANDLERS — Deposited / Withdrawn (Balance tracking)
// ============================================================================

async function handleDeposited({ event, context }: { event: any; context: any }) {
  const { _depositant, _asset, _amount } = event.params;
  const chainId = event.chainId;
  const txHash = event.transaction.hash;
  const txMeta = getTxMeta(event);

  const balanceId = `${_depositant}-${_asset}-${chainId}`;
  let balance = await context.Balance.get(balanceId);
  const previousBalance = balance?.amount ?? 0n;
  const newBalance = previousBalance + _amount;

  context.Balance.set({ id: balanceId, account: _depositant, asset: _asset, amount: newBalance, chainId });

  context.DepositorEvent.set({
    id: `${txHash}-${event.logIndex}`,
    depositor: _depositant, eventType: 'DEPOSIT' as const,
    asset: _asset, amount: _amount, balance: newBalance,
    transactionHash: txHash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    ...txMeta, chainId,
  });
}

EverclearSpoke_Deposited_handler(async ({ event, context }) => { await handleDeposited({ event, context }); });
EverclearSpokeV5_Deposited_handler(async ({ event, context }) => { await handleDeposited({ event, context }); });

async function handleWithdrawn({ event, context }: { event: any; context: any }) {
  const { _withdrawer, _asset, _amount } = event.params;
  const chainId = event.chainId;
  const txHash = event.transaction.hash;
  const txMeta = getTxMeta(event);

  const balanceId = `${_withdrawer}-${_asset}-${chainId}`;
  let balance = await context.Balance.get(balanceId);
  const previousBalance = balance?.amount ?? 0n;
  const newBalance = previousBalance - _amount;

  context.Balance.set({ id: balanceId, account: _withdrawer, asset: _asset, amount: newBalance, chainId });

  context.DepositorEvent.set({
    id: `${txHash}-${event.logIndex}`,
    depositor: _withdrawer, eventType: 'WITHDRAW' as const,
    asset: _asset, amount: _amount, balance: newBalance,
    transactionHash: txHash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    ...txMeta, chainId,
  });
}

EverclearSpoke_Withdrawn_handler(async ({ event, context }) => { await handleWithdrawn({ event, context }); });
EverclearSpokeV5_Withdrawn_handler(async ({ event, context }) => { await handleWithdrawn({ event, context }); });

// ============================================================================
// SPOKE HANDLERS — Settled
// ============================================================================

async function handleSettled({ event, context }: { event: any; context: any }) {
  const { _intentId, _account, _asset, _amount } = event.params;
  const chainId = event.chainId;
  const txHash = event.transaction.hash;
  const txMeta = getTxMeta(event);

  context.SettlementIntent.set({
    id: _intentId, status: 'SETTLED' as const,
    recipient: _account, asset: _asset, amount: _amount,
    settlementTransactionHash: txHash,
    settlementTimestamp: BigInt(event.block.timestamp),
    settlementBlockNumber: BigInt(event.block.number),
    settlementTxOrigin: txMeta.txOrigin,
    settlementTxNonce: txMeta.txNonce,
    settlementGasPrice: txMeta.gasPrice,
    settlementGasLimit: txMeta.gasLimit,
  });

  const intent = await context.Intent.get(_intentId);
  if (intent) {
    context.Intent.set({ ...intent, status: 'SETTLED' as const });
  }

  const assetAddress = bytes32ToAddress(_asset);
  let unclaimedBalance = await context.UnclaimedBalance.get(assetAddress);
  if (unclaimedBalance) {
    context.UnclaimedBalance.set({ id: assetAddress, amount: unclaimedBalance.amount - _amount });
  }

  const balanceId = `${_account}-${_asset}-${chainId}`;
  let balance = await context.Balance.get(balanceId);
  const previousBalance = balance?.amount ?? 0n;
  context.Balance.set({ id: balanceId, account: _account, asset: _asset, amount: previousBalance + _amount, chainId });
}

EverclearSpoke_Settled_handler(async ({ event, context }) => { await handleSettled({ event, context }); });
EverclearSpokeV5_Settled_handler(async ({ event, context }) => { await handleSettled({ event, context }); });

// ============================================================================
// SPOKE HANDLERS — ExternalCalldataExecuted
// ============================================================================

async function handleExternalCalldataExecuted({ event, context }: { event: any; context: any }) {
  const { _intentId, _returnData } = event.params;
  const txMeta = getTxMeta(event);

  context.ExternalCalldataExecutedEvent.set({
    id: _intentId, intentId: _intentId, returnData: _returnData,
    transactionHash: event.transaction.hash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    ...txMeta, chainId: event.chainId,
  });

  const settlement = await context.SettlementIntent.get(_intentId);
  if (settlement) {
    context.SettlementIntent.set({ ...settlement, status: 'SETTLED_AND_MANUALLY_EXECUTED' as const });
  }
}

EverclearSpoke_ExternalCalldataExecuted_handler(async ({ event, context }) => { await handleExternalCalldataExecuted({ event, context }); });
EverclearSpokeV5_ExternalCalldataExecuted_handler(async ({ event, context }) => { await handleExternalCalldataExecuted({ event, context }); });

// ============================================================================
// SPOKE HANDLERS — AssetTransferFailed / AssetMintFailed
// ============================================================================

async function handleAssetTransferFailed({ event, context }: { event: any; context: any }) {
  const { _asset, _recipient, _amount } = event.params;
  const txMeta = getTxMeta(event);
  context.AssetTransferFailedEvent.set({
    id: `${event.transaction.hash}-${event.logIndex}`,
    asset: _asset, recipient: _recipient, amount: _amount,
    transactionHash: event.transaction.hash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    ...txMeta, chainId: event.chainId,
  });
}

EverclearSpoke_AssetTransferFailed_handler(async ({ event, context }) => { await handleAssetTransferFailed({ event, context }); });
EverclearSpokeV5_AssetTransferFailed_handler(async ({ event, context }) => { await handleAssetTransferFailed({ event, context }); });

async function handleAssetMintFailed({ event, context }: { event: any; context: any }) {
  const { _asset, _recipient, _amount, _strategy } = event.params;
  const txMeta = getTxMeta(event);
  context.AssetMintFailedEvent.set({
    id: `${event.transaction.hash}-${event.logIndex}`,
    asset: _asset, recipient: _recipient, amount: _amount,
    strategy: (StrategyStrings[Number(_strategy)] || 'DEFAULT') as 'DEFAULT' | 'XERC20',
    transactionHash: event.transaction.hash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    ...txMeta, chainId: event.chainId,
  });
}

EverclearSpoke_AssetMintFailed_handler(async ({ event, context }) => { await handleAssetMintFailed({ event, context }); });
EverclearSpokeV5_AssetMintFailed_handler(async ({ event, context }) => { await handleAssetMintFailed({ event, context }); });

// ============================================================================
// SPOKE HANDLERS — SpokeMeta (Paused, Unpaused, GatewayUpdated, LighthouseUpdated)
// ============================================================================

async function getOrCreateSpokeMeta(context: any, chainId: number) {
  const id = String(chainId);
  let meta = await context.SpokeMeta.get(id);
  if (!meta) {
    meta = {
      id, domain: chainId, paused: false,
      gateway: undefined, lighthouse: undefined,
      messageReceiver: undefined, watchtower: undefined,
      messageGasLimit: undefined, feeAdapter: undefined, fillSigner: undefined,
    };
  }
  return meta;
}

EverclearSpokeV5_Paused_handler(async ({ event, context }) => {
  const meta = await getOrCreateSpokeMeta(context, event.chainId);
  context.SpokeMeta.set({ ...meta, paused: true });
});

EverclearSpokeV5_Unpaused_handler(async ({ event, context }) => {
  const meta = await getOrCreateSpokeMeta(context, event.chainId);
  context.SpokeMeta.set({ ...meta, paused: false });
});

EverclearSpokeV5_GatewayUpdated_handler(async ({ event, context }) => {
  const { _newGateway } = event.params;
  const meta = await getOrCreateSpokeMeta(context, event.chainId);
  context.SpokeMeta.set({ ...meta, gateway: _newGateway });
});

EverclearSpokeV5_LighthouseUpdated_handler(async ({ event, context }) => {
  const { _newLightHouse } = event.params;
  const meta = await getOrCreateSpokeMeta(context, event.chainId);
  context.SpokeMeta.set({ ...meta, lighthouse: _newLightHouse });
});

EverclearSpokeV5_MessageReceiverUpdated_handler(async ({ event, context }) => {
  const { _newMessageReceiver } = event.params;
  const meta = await getOrCreateSpokeMeta(context, event.chainId);
  context.SpokeMeta.set({ ...meta, messageReceiver: _newMessageReceiver });
});

EverclearSpokeV5_WatchtowerUpdated_handler(async ({ event, context }) => {
  const { _newWatchtower } = event.params;
  const meta = await getOrCreateSpokeMeta(context, event.chainId);
  context.SpokeMeta.set({ ...meta, watchtower: _newWatchtower });
});

EverclearSpokeV5_MessageGasLimitUpdated_handler(async ({ event, context }) => {
  const { _newGasLimit } = event.params;
  const meta = await getOrCreateSpokeMeta(context, event.chainId);
  context.SpokeMeta.set({ ...meta, messageGasLimit: _newGasLimit });
});

EverclearSpokeV5_FeeAdapterUpdated_handler(async ({ event, context }) => {
  const { _newFeeAdapter } = event.params;
  const meta = await getOrCreateSpokeMeta(context, event.chainId);
  context.SpokeMeta.set({ ...meta, feeAdapter: _newFeeAdapter });
});

EverclearSpokeV5_FillSignerUpdated_handler(async ({ event, context }) => {
  const { _newFillSigner } = event.params;
  const meta = await getOrCreateSpokeMeta(context, event.chainId);
  context.SpokeMeta.set({ ...meta, fillSigner: _newFillSigner });
});

// ============================================================================
// HUB HANDLERS — SettlementEnqueued
// ============================================================================

EverclearHubV2_SettlementEnqueued_handler(async ({ event, context }) => {
  const { _intentId, _domain, _entryEpoch, _asset, _amount, _updateVirtualBalance, _owner } = event.params;
  const txMeta = getTxMeta(event);

  // Update or create Intent
  let intent = await context.Intent.get(_intentId);
  if (!intent) {
    intent = {
      id: _intentId, intentId: _intentId, queueIdx: 0n,
      initiator: '0x0000000000000000000000000000000000000000000000000000000000000000',
      receiver: _owner, inputAsset: _asset,
      outputAsset: '0x0000000000000000000000000000000000000000000000000000000000000000',
      maxFee: 0, amountOutMin: 0n, origin: Number(_domain), nonce: 0n,
      timestamp: BigInt(event.block.timestamp), ttl: 0n, originAmount: _amount,
      destinations: [], data: '0x', chainId: Number(_domain),
      blockNumber: BigInt(event.block.number), blockTimestamp: BigInt(event.block.timestamp),
      transactionHash: event.transaction.hash,
      sender: '0x0000000000000000000000000000000000000000000000000000000000000000',
      ...txMeta,
      receiveBlockNumber: undefined, isFastPath: false,
      tokenFee: undefined, nativeFee: undefined, orderId: undefined,
      status: 'SETTLED' as const,
    };
    context.Intent.set(intent);
  } else {
    context.Intent.set({ ...intent, status: 'SETTLED' as const });
  }

  // Update SettlementQueue
  const domainStr = String(_domain);
  let queue = await context.SettlementQueue.get(domainStr);
  if (!queue) {
    queue = { id: domainStr, domain: Number(_domain), lastProcessed: undefined, size: 0n, first: 1n, last: 0n };
  }
  const newLast = queue.last + 1n;
  context.SettlementQueue.set({ ...queue, last: newLast, size: queue.size + 1n });
  context.SettlementQueueMapping.set({ id: `${domainStr}-${newLast}`, intentId: _intentId });

  // Create HubSettlement
  context.HubSettlement.set({
    id: _intentId, intentId: _intentId, queueIdx: newLast,
    amount: _amount, asset: _asset, updateVirtualBalance: _updateVirtualBalance,
    recipient: _owner, domain: Number(_domain), entryEpoch: _entryEpoch,
    enqueuedTransactionHash: event.transaction.hash,
    enqueuedTimestamp: BigInt(event.block.timestamp),
    enqueuedBlockNumber: BigInt(event.block.number),
    enqueuedTxOrigin: txMeta.txOrigin,
    enqueuedTxNonce: txMeta.txNonce,
  });

  // Update HubIntent
  let hubIntent = await context.HubIntent.get(_intentId);
  context.HubIntent.set({
    id: _intentId, status: 'SETTLED' as HubIntentStatus_t,
    settlementId: _intentId,
    messageId: hubIntent?.messageId ?? undefined,
    addEventTransactionHash: hubIntent?.addEventTransactionHash ?? undefined,
    addEventTimestamp: hubIntent?.addEventTimestamp ?? undefined,
    addEventBlockNumber: hubIntent?.addEventBlockNumber ?? undefined,
    addEventTxNonce: hubIntent?.addEventTxNonce ?? undefined,
    fillEventTransactionHash: hubIntent?.fillEventTransactionHash ?? undefined,
    fillEventTimestamp: hubIntent?.fillEventTimestamp ?? undefined,
    fillEventBlockNumber: hubIntent?.fillEventBlockNumber ?? undefined,
    fillEventTxNonce: hubIntent?.fillEventTxNonce ?? undefined,
  });
});

// ============================================================================
// HUB HANDLERS — IntentProcessed / FillProcessed
// ============================================================================

EverclearHubV2_IntentProcessed_handler(async ({ event, context }) => {
  const { _intentId, _status } = event.params;
  const statusStr = (HubIntentStatusStrings[Number(_status)] || 'NONE') as HubIntentStatus_t;
  const txMeta = getTxMeta(event);
  let hubIntent = await context.HubIntent.get(_intentId);

  context.HubIntent.set({
    id: _intentId, status: statusStr,
    settlementId: hubIntent?.settlementId ?? undefined,
    messageId: hubIntent?.messageId ?? undefined,
    addEventTransactionHash: event.transaction.hash,
    addEventTimestamp: BigInt(event.block.timestamp),
    addEventBlockNumber: BigInt(event.block.number),
    addEventTxNonce: txMeta.txNonce,
    fillEventTransactionHash: hubIntent?.fillEventTransactionHash ?? undefined,
    fillEventTimestamp: hubIntent?.fillEventTimestamp ?? undefined,
    fillEventBlockNumber: hubIntent?.fillEventBlockNumber ?? undefined,
    fillEventTxNonce: hubIntent?.fillEventTxNonce ?? undefined,
  });
});

EverclearHubV2_FillProcessed_handler(async ({ event, context }) => {
  const { _intentId, _status } = event.params;
  const statusStr = (HubIntentStatusStrings[Number(_status)] || 'NONE') as HubIntentStatus_t;
  const txMeta = getTxMeta(event);
  let hubIntent = await context.HubIntent.get(_intentId);

  context.HubIntent.set({
    id: _intentId, status: statusStr,
    settlementId: hubIntent?.settlementId ?? undefined,
    messageId: hubIntent?.messageId ?? undefined,
    addEventTransactionHash: hubIntent?.addEventTransactionHash ?? undefined,
    addEventTimestamp: hubIntent?.addEventTimestamp ?? undefined,
    addEventBlockNumber: hubIntent?.addEventBlockNumber ?? undefined,
    addEventTxNonce: hubIntent?.addEventTxNonce ?? undefined,
    fillEventTransactionHash: event.transaction.hash,
    fillEventTimestamp: BigInt(event.block.timestamp),
    fillEventBlockNumber: BigInt(event.block.number),
    fillEventTxNonce: txMeta.txNonce,
  });
});

// ============================================================================
// HUB HANDLERS — SettlementQueueProcessed
// ============================================================================

EverclearHubV2_SettlementQueueProcessed_handler(async ({ event, context }) => {
  const { _messageId, _domain, _amount, _quote } = event.params;
  const domainStr = String(_domain);
  const txMeta = getTxMeta(event);

  let queue = await context.SettlementQueue.get(domainStr);
  const intentIds: string[] = [];

  if (queue) {
    const length = Number(_amount);
    for (let idx = 0; idx < length; idx++) {
      const mappingId = `${domainStr}-${queue.first + BigInt(idx)}`;
      const mapping = await context.SettlementQueueMapping.get(mappingId);
      if (mapping) {
        intentIds.push(mapping.intentId);
        const hubIntent = await context.HubIntent.get(mapping.intentId);
        if (hubIntent) {
          context.HubIntent.set({ ...hubIntent, messageId: _messageId });
        }
      }
    }
    context.SettlementQueue.set({ ...queue, first: queue.first + _amount, size: queue.size - _amount, lastProcessed: BigInt(event.block.timestamp) });
  }

  context.SettlementMessage.set({
    id: _messageId, quote: _quote, domain: Number(_domain),
    intentIds, messageType: 'SETTLED' as const,
    transactionHash: event.transaction.hash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    ...txMeta,
  });
});

// ============================================================================
// HUB HANDLERS — InvoiceEnqueued
// ============================================================================

EverclearHubV2_InvoiceEnqueued_handler(async ({ event, context }) => {
  const { _intentId, _tickerHash, _entryEpoch, _amount, _owner } = event.params;
  const txHash = event.transaction.hash;
  const txMeta = getTxMeta(event);

  context.Invoice.set({
    id: `${txHash}-${event.logIndex}`,
    intentId: _intentId, tickerHash: _tickerHash, amount: _amount,
    owner: _owner, entryEpoch: _entryEpoch,
    transactionHash: txHash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    txOrigin: txMeta.txOrigin, txNonce: txMeta.txNonce,
  });

  let hubIntent = await context.HubIntent.get(_intentId);
  context.HubIntent.set({
    id: _intentId, status: 'INVOICED' as const,
    settlementId: hubIntent?.settlementId ?? undefined,
    messageId: hubIntent?.messageId ?? undefined,
    addEventTransactionHash: hubIntent?.addEventTransactionHash ?? undefined,
    addEventTimestamp: hubIntent?.addEventTimestamp ?? undefined,
    addEventBlockNumber: hubIntent?.addEventBlockNumber ?? undefined,
    addEventTxNonce: hubIntent?.addEventTxNonce ?? undefined,
    fillEventTransactionHash: hubIntent?.fillEventTransactionHash ?? undefined,
    fillEventTimestamp: hubIntent?.fillEventTimestamp ?? undefined,
    fillEventBlockNumber: hubIntent?.fillEventBlockNumber ?? undefined,
    fillEventTxNonce: hubIntent?.fillEventTxNonce ?? undefined,
  });
});

// ============================================================================
// HUB HANDLERS — DepositEnqueued / DepositProcessed
// ============================================================================

EverclearHubV2_DepositEnqueued_handler(async ({ event, context }) => {
  const { _epoch, _domain, _tickerHash, _intentId, _amount } = event.params;
  const txHash = event.transaction.hash;
  const txMeta = getTxMeta(event);

  const queueId = `${_epoch}-${_domain}-${_tickerHash}`;
  let queue = await context.DepositQueue.get(queueId);
  if (!queue) {
    queue = { id: queueId, epoch: _epoch, domain: Number(_domain), tickerHash: _tickerHash, lastProcessed: undefined, size: 0n, first: 1n, last: 0n, blockNumber: BigInt(event.block.number) };
  }
  context.DepositQueue.set({ ...queue, last: queue.last + 1n, size: queue.size + 1n });

  context.Deposit.set({
    id: _intentId, intentId: _intentId, epoch: _epoch, domain: Number(_domain),
    amount: _amount, tickerHash: _tickerHash,
    enqueuedTransactionHash: txHash,
    enqueuedTimestamp: BigInt(event.block.timestamp),
    enqueuedBlockNumber: BigInt(event.block.number),
    enqueuedTxNonce: txMeta.txNonce,
    processedTransactionHash: undefined, processedTimestamp: undefined,
    processedBlockNumber: undefined, processedTxNonce: undefined,
  });
});

EverclearHubV2_DepositProcessed_handler(async ({ event, context }) => {
  const { _epoch, _domain, _tickerHash, _intentId, _amountAndRewards } = event.params;
  const txHash = event.transaction.hash;
  const txMeta = getTxMeta(event);

  let hubIntent = await context.HubIntent.get(_intentId);
  context.HubIntent.set({
    id: _intentId, status: 'DEPOSIT_PROCESSED' as const,
    settlementId: hubIntent?.settlementId ?? undefined,
    messageId: hubIntent?.messageId ?? undefined,
    addEventTransactionHash: hubIntent?.addEventTransactionHash ?? undefined,
    addEventTimestamp: hubIntent?.addEventTimestamp ?? undefined,
    addEventBlockNumber: hubIntent?.addEventBlockNumber ?? undefined,
    addEventTxNonce: hubIntent?.addEventTxNonce ?? undefined,
    fillEventTransactionHash: hubIntent?.fillEventTransactionHash ?? undefined,
    fillEventTimestamp: hubIntent?.fillEventTimestamp ?? undefined,
    fillEventBlockNumber: hubIntent?.fillEventBlockNumber ?? undefined,
    fillEventTxNonce: hubIntent?.fillEventTxNonce ?? undefined,
  });

  let deposit = await context.Deposit.get(_intentId);
  if (deposit) {
    context.Deposit.set({
      ...deposit, amount: _amountAndRewards,
      processedTransactionHash: txHash,
      processedTimestamp: BigInt(event.block.timestamp),
      processedBlockNumber: BigInt(event.block.number),
      processedTxNonce: txMeta.txNonce,
    });
  } else {
    context.Deposit.set({
      id: _intentId, intentId: _intentId, epoch: _epoch, domain: Number(_domain),
      amount: _amountAndRewards, tickerHash: _tickerHash,
      enqueuedTransactionHash: undefined, enqueuedTimestamp: undefined,
      enqueuedBlockNumber: undefined, enqueuedTxNonce: undefined,
      processedTransactionHash: txHash,
      processedTimestamp: BigInt(event.block.timestamp),
      processedBlockNumber: BigInt(event.block.number),
      processedTxNonce: txMeta.txNonce,
    });
  }

  const queueId = `${_epoch}-${_domain}-${_tickerHash}`;
  let queue = await context.DepositQueue.get(queueId);
  if (queue) {
    context.DepositQueue.set({ ...queue, first: queue.first + 1n, size: queue.size - 1n, lastProcessed: BigInt(event.block.timestamp) });
  }
});

// ============================================================================
// HUB HANDLERS — FeesWithdrawn
// ============================================================================

EverclearHubV2_FeesWithdrawn_handler(async ({ event, context }) => {
  const { _withdrawer, _feeRecipient, _tickerHash, _amount, _paymentId } = event.params;
  const txHash = event.transaction.hash;
  const txMeta = getTxMeta(event);

  context.FeesWithdrawnEvent.set({
    id: `${txHash}-${event.logIndex}`,
    withdrawer: _withdrawer, recipient: _feeRecipient,
    tickerHash: _tickerHash, amount: _amount, paymentId: _paymentId,
    transactionHash: txHash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    txOrigin: txMeta.txOrigin, txNonce: txMeta.txNonce,
  });
});

// ============================================================================
// HUB HANDLERS — ReturnUnsupportedIntent
// ============================================================================

EverclearHubV2_ReturnUnsupportedIntent_handler(async ({ event, context }) => {
  const { _domain, _messageId, _intentId } = event.params;
  const txMeta = getTxMeta(event);

  context.SettlementMessage.set({
    id: _messageId, quote: 0n, domain: Number(_domain),
    intentIds: [_intentId], messageType: 'UNSUPPORTED_RETURNED' as const,
    transactionHash: event.transaction.hash,
    timestamp: BigInt(event.block.timestamp), blockNumber: BigInt(event.block.number),
    ...txMeta,
  });

  let hubIntent = await context.HubIntent.get(_intentId);
  if (hubIntent) {
    context.HubIntent.set({ ...hubIntent, status: 'UNSUPPORTED_RETURNED' as const, messageId: _messageId });
  }
});

// ============================================================================
// HUB HANDLERS — Token & Asset Configuration
// ============================================================================

EverclearHubV2_TokenConfigsSet_handler(async ({ event, context }) => {
  const { _configs } = event.params;

  for (const config of _configs) {
    const [tickerHash, , prioritizedStrategy, maxDiscountDbps, discountPerEpoch, fees, adoptedForAssets] = config;

    // Extract fee recipients and amounts
    const feeRecipients: string[] = [];
    const feeAmounts: bigint[] = [];
    for (const fee of fees) {
      feeRecipients.push(fee[0]); // recipient address
      feeAmounts.push(BigInt(fee[1])); // fee amount
    }

    context.Token.set({
      id: tickerHash,
      feeRecipients, feeAmounts,
      maxDiscountBps: BigInt(maxDiscountDbps),
      discountPerEpoch: BigInt(discountPerEpoch),
      prioritizedStrategy: (StrategyStrings[Number(prioritizedStrategy)] || 'DEFAULT') as 'DEFAULT' | 'XERC20',
    });

    // Create HubAsset entities for each adopted asset config
    for (const assetConfig of adoptedForAssets) {
      const [assetTickerHash, adopted, domain, approval, strategy] = assetConfig;
      const assetId = `${assetTickerHash}-${domain}`;
      context.HubAsset.set({
        id: assetId,
        tickerHash: assetTickerHash,
        domain: Number(domain),
        adopted,
        approval,
        strategy: (StrategyStrings[Number(strategy)] || 'DEFAULT') as 'DEFAULT' | 'XERC20',
      });
    }
  }
});

EverclearHubV2_AssetConfigSet_handler(async ({ event, context }) => {
  const { _config } = event.params;
  const [tickerHash, adopted, domain, approval, strategy] = _config;
  const assetId = `${tickerHash}-${domain}`;

  context.HubAsset.set({
    id: assetId,
    tickerHash,
    domain: Number(domain),
    adopted,
    approval,
    strategy: (StrategyStrings[Number(strategy)] || 'DEFAULT') as 'DEFAULT' | 'XERC20',
  });
});

EverclearHubV2_MaxDiscountDbpsSet_handler(async ({ event, context }) => {
  const { _tickerHash, _newMaxDiscountDbps } = event.params;
  let token = await context.Token.get(_tickerHash);
  if (token) {
    context.Token.set({ ...token, maxDiscountBps: BigInt(_newMaxDiscountDbps) });
  }
});

EverclearHubV2_PrioritizedStrategySet_handler(async ({ event, context }) => {
  const { _tickerHash, _strategy } = event.params;
  let token = await context.Token.get(_tickerHash);
  if (token) {
    context.Token.set({ ...token, prioritizedStrategy: (StrategyStrings[Number(_strategy)] || 'DEFAULT') as 'DEFAULT' | 'XERC20' });
  }
});

EverclearHubV2_DiscountPerEpochSet_handler(async ({ event, context }) => {
  const { _tickerHash, _newDiscountPerEpoch } = event.params;
  let token = await context.Token.get(_tickerHash);
  if (token) {
    context.Token.set({ ...token, discountPerEpoch: BigInt(_newDiscountPerEpoch) });
  }
});

// ============================================================================
// HUB HANDLERS — Solver Configuration
// ============================================================================

EverclearHubV2_SolverConfigUpdated_handler(async ({ event, context }) => {
  const { _solver, _supportedDomains } = event.params;

  let solver = await context.Solver.get(_solver);
  context.Solver.set({
    id: _solver,
    supportedDomains: _supportedDomains.map((d: any) => Number(d)),
    updateVirtualBalance: solver?.updateVirtualBalance ?? false,
  });
});

EverclearHubV2_IncreaseVirtualBalanceSet_handler(async ({ event, context }) => {
  const { _user, _status } = event.params;

  let solver = await context.Solver.get(_user);
  context.Solver.set({
    id: _user,
    supportedDomains: solver?.supportedDomains ?? [],
    updateVirtualBalance: _status,
  });
});

// ============================================================================
// HUB HANDLERS — Meta (Admin/Protocol State)
// ============================================================================

const HUB_META_ID = 'HUB_META';

async function getOrCreateHubMeta(context: any) {
  let meta = await context.HubMeta.get(HUB_META_ID);
  if (!meta) {
    meta = {
      id: HUB_META_ID, domain: undefined, paused: false,
      owner: undefined, proposedOwner: undefined, proposedOwnershipTimestamp: undefined,
      gateway: undefined, watchtower: undefined, mailbox: undefined, securityModule: undefined,
      acceptanceDelay: undefined, minSolverSupportedDomains: undefined, epochLength: undefined,
      expiryTimeBuffer: undefined, supportedDomains: [],
    };
  }
  return meta;
}

EverclearHubV2_Paused_handler(async ({ event, context }) => {
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, paused: true });
});

EverclearHubV2_Unpaused_handler(async ({ event, context }) => {
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, paused: false });
});

EverclearHubV2_OwnershipTransferred_handler(async ({ event, context }) => {
  const { _newOwner } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, owner: _newOwner });
});

EverclearHubV2_OwnershipProposed_handler(async ({ event, context }) => {
  const { _proposedOwner, _timestamp } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, proposedOwner: _proposedOwner, proposedOwnershipTimestamp: BigInt(_timestamp) });
});

EverclearHubV2_GatewayUpdated_handler(async ({ event, context }) => {
  const { _newGateway } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, gateway: _newGateway });
});

EverclearHubV2_AcceptanceDelayUpdated_handler(async ({ event, context }) => {
  const { _newAcceptanceDelay } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, acceptanceDelay: BigInt(_newAcceptanceDelay) });
});

EverclearHubV2_MinSolverSupportedDomainsUpdated_handler(async ({ event, context }) => {
  const { _newMinSolverSupportedDomains } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, minSolverSupportedDomains: Number(_newMinSolverSupportedDomains) });
});

EverclearHubV2_EpochLengthUpdated_handler(async ({ event, context }) => {
  const { _newEpochLength } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, epochLength: BigInt(_newEpochLength) });
});

EverclearHubV2_ExpiryTimeBufferUpdated_handler(async ({ event, context }) => {
  const { _newExpiryTimeBuffer } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, expiryTimeBuffer: BigInt(_newExpiryTimeBuffer) });
});

EverclearHubV2_SupportedDomainsAdded_handler(async ({ event, context }) => {
  const { _domains } = event.params;
  const meta = await getOrCreateHubMeta(context);

  const newDomains = [...meta.supportedDomains];
  for (const domainSetup of _domains) {
    const [domainId, blockGasLimit] = domainSetup;
    const domainNum = Number(domainId);

    // Create Domain entity
    context.Domain.set({
      id: String(domainNum),
      domain: domainNum,
      blockGasLimit: BigInt(blockGasLimit),
    });

    if (!newDomains.includes(domainNum)) {
      newDomains.push(domainNum);
    }
  }

  context.HubMeta.set({ ...meta, supportedDomains: newDomains });
});

EverclearHubV2_SupportedDomainsRemoved_handler(async ({ event, context }) => {
  const { _domains } = event.params;
  const meta = await getOrCreateHubMeta(context);

  const removedDomains = new Set(_domains.map((d: any) => Number(d)));
  const newDomains = meta.supportedDomains.filter((d: number) => !removedDomains.has(d));

  context.HubMeta.set({ ...meta, supportedDomains: newDomains });
});

// ============================================================================
// HUB HANDLERS — Watchtower, Mailbox, SecurityModule
// ============================================================================

EverclearHubV2_WatchtowerUpdated_handler(async ({ event, context }) => {
  const { _newWatchtower } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, watchtower: _newWatchtower });
});

EverclearHubV2_MailboxUpdated_handler(async ({ event, context }) => {
  const { _mailbox } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, mailbox: _mailbox });
});

EverclearHubV2_SecurityModuleUpdated_handler(async ({ event, context }) => {
  const { _securityModule } = event.params;
  const meta = await getOrCreateHubMeta(context);
  context.HubMeta.set({ ...meta, securityModule: _securityModule });
});
