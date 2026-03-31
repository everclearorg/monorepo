/**
 * Local integration test for EnvioReader against live Envio HyperIndex
 *
 * Run:
 *   npx ts-node --project packages/adapters/subgraph/tsconfig.json packages/adapters/subgraph/test-envio-local.ts
 */
import { EnvioReader } from './src/envio';

const ENVIO_URL = 'https://indexer.dev.hyperindex.xyz/6468315/v1/graphql';

const ETHEREUM = '1';
const ARBITRUM = '42161';
const HUB = '25327';

let passed = 0;
let failed = 0;

async function test(name: string, fn: () => Promise<void>) {
  try {
    await fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e: any) {
    failed++;
    console.log(`  ✗ ${name}`);
    console.log(`    Error: ${e.message}`);
  }
}

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

async function main() {
  (EnvioReader as any).instance = undefined;

  const reader = EnvioReader.create({
    subgraphs: {},
    envio: { url: ENVIO_URL, timeout: 15 },
  });

  console.log(`\nEnvioReader Integration Test`);
  console.log(`Endpoint: ${ENVIO_URL}\n`);

  // ── Block Numbers ──────────────────────────────────────────────

  console.log('Block Numbers');

  await test('getLatestBlockNumber returns blocks for multiple chains', async () => {
    const blocks = await reader.getLatestBlockNumber([ETHEREUM, ARBITRUM]);
    assert(blocks.size > 0, 'Expected at least one block number');
    assert((blocks.get(ETHEREUM) ?? 0) > 20_000_000, `Ethereum block too low: ${blocks.get(ETHEREUM)}`);
    assert((blocks.get(ARBITRUM) ?? 0) > 400_000_000, `Arbitrum block too low: ${blocks.get(ARBITRUM)}`);
  });

  // ── Hub Meta ───────────────────────────────────────────────────

  console.log('\nHub Meta');

  await test('getHubMeta returns hub configuration', async () => {
    const meta = await reader.getHubMeta(HUB);
    assert(meta !== undefined, 'HubMeta should not be undefined');
    assert(meta!.paused === false, `Hub should not be paused, got: ${meta!.paused}`);
    assert(Array.isArray(meta!.supportedDomains), 'supportedDomains should be an array');
    assert(meta!.supportedDomains!.length > 10, `Expected >10 supported domains, got: ${meta!.supportedDomains!.length}`);
    console.log(`    → ${meta!.supportedDomains!.length} supported domains, epochLength=${meta!.epochLength}`);
  });

  // ── Spoke Meta ─────────────────────────────────────────────────

  console.log('\nSpoke Meta');

  await test('getSpokeMeta returns spoke config for Ethereum', async () => {
    const meta = await reader.getSpokeMeta(ETHEREUM);
    assert(meta !== undefined, 'SpokeMeta should not be undefined');
    assert(meta!.domain === ETHEREUM, `Expected domain ${ETHEREUM}, got: ${meta!.domain}`);
    assert(meta!.paused === false, 'Ethereum spoke should not be paused');
    console.log(`    → domain=${meta!.domain}, messageGasLimit=${meta!.messageGasLimit}`);
  });

  await test('getSpokeMeta returns undefined for non-existent chain', async () => {
    const meta = await reader.getSpokeMeta('999999');
    assert(meta === undefined, 'Expected undefined for non-existent chain');
  });

  // ── Tokens & Assets ────────────────────────────────────────────

  console.log('\nTokens & Assets');

  await test('getTokens returns tokens and assets', async () => {
    const [tokens, assets] = await reader.getTokens(HUB);
    assert(tokens.length > 0, 'Expected at least one token');
    assert(assets.length > 0, 'Expected at least one asset');
    assert(tokens[0].id !== undefined, 'Token should have an id');
    assert(assets[0].domain !== undefined, 'Asset should have a domain');
    console.log(`    → ${tokens.length} tokens, ${assets.length} assets`);
  });

  // ── Queues ─────────────────────────────────────────────────────

  console.log('\nQueues');

  await test('getSpokeQueues returns queues for Arbitrum', async () => {
    const queues = await reader.getSpokeQueues(ARBITRUM);
    assert(queues.length > 0, 'Expected at least one queue');
    assert(queues[0].domain === ARBITRUM, `Expected domain ${ARBITRUM}, got: ${queues[0].domain}`);
    console.log(`    → ${queues.length} queues, type=${queues[0].type}, size=${queues[0].size}`);
  });

  await test('getSettlementQueues returns settlement queues', async () => {
    const queues = await reader.getSettlementQueues(HUB);
    assert(queues.length > 0, 'Expected at least one settlement queue');
    console.log(`    → ${queues.length} settlement queues`);
  });

  await test('getDepositQueues returns deposit queues', async () => {
    const queues = await reader.getDepositQueues(HUB, 0);
    assert(Array.isArray(queues), 'Expected an array');
    console.log(`    → ${queues.length} deposit queues`);
  });

  // ── Origin Intents ─────────────────────────────────────────────

  console.log('\nOrigin Intents');

  await test('getOriginIntentsByNonce returns intents with blockNumber-based txNonce', async () => {
    const intents = await reader.getOriginIntentsByNonce(
      new Map([[ARBITRUM, { latestNonce: 0, maxBlockNumber: 999999999 }]]),
    );
    assert(intents.length > 0, 'Expected at least one origin intent');
    assert(intents[0].id !== undefined, 'Intent should have an id');
    assert(intents[0].origin === ARBITRUM, `Expected origin ${ARBITRUM}, got: ${intents[0].origin}`);
    assert(intents[0].txNonce > 1_000_000, `txNonce should be a blockNumber (got ${intents[0].txNonce}), not an intent nonce`);
    console.log(`    → ${intents.length} intents, first txNonce(=blockNumber)=${intents[0].txNonce}`);
  });

  await test('getOriginIntentById returns a specific intent', async () => {
    const intents = await reader.getOriginIntentsByNonce(
      new Map([[ARBITRUM, { latestNonce: 0, maxBlockNumber: 999999999 }]]),
    );
    assert(intents.length > 0, 'Need at least one intent for lookup test');
    const intent = await reader.getOriginIntentById(ARBITRUM, intents[0].id);
    assert(intent !== undefined, 'Should find the intent by ID');
    assert(intent!.id === intents[0].id, 'ID should match');
  });

  await test('pagination works: second poll with checkpoint skips already-seen data', async () => {
    const first = await reader.getOriginIntentsByNonce(
      new Map([[ARBITRUM, { latestNonce: 0, maxBlockNumber: 999999999 }]]),
    );
    assert(first.length > 0, 'First batch should have intents');
    const checkpoint = Math.max(...first.map((i) => i.txNonce));

    const second = await reader.getOriginIntentsByNonce(
      new Map([[ARBITRUM, { latestNonce: checkpoint, maxBlockNumber: 999999999 }]]),
    );
    // Second batch should not contain any intents from the first batch
    const firstIds = new Set(first.map((i) => i.id));
    const overlap = second.filter((i) => firstIds.has(i.id));
    assert(overlap.length === 0, `Found ${overlap.length} overlapping intents between batches`);
    console.log(`    → First batch: ${first.length}, checkpoint=${checkpoint}, second batch: ${second.length}, 0 overlap`);
  });

  // ── Destination Intents ────────────────────────────────────────

  console.log('\nDestination Intents');

  await test('getDestinationIntentsByNonce returns filled intents', async () => {
    const intents = await reader.getDestinationIntentsByNonce(
      new Map([[ARBITRUM, { latestNonce: 0, maxBlockNumber: 999999999 }]]),
    );
    assert(Array.isArray(intents), 'Expected an array');
    console.log(`    → ${intents.length} destination intents`);
    if (intents.length > 0) {
      assert(intents[0].solver !== undefined, 'Destination intent should have a solver');
      assert(intents[0].txNonce > 1_000_000, `txNonce should be a blockNumber (got ${intents[0].txNonce})`);
    }
  });

  // ── Hub Intents ────────────────────────────────────────────────

  console.log('\nHub Intents');

  await test('getHubIntentsByNonce returns three arrays with blockNumber-based nonces', async () => {
    const [added, filled, enqueued] = await reader.getHubIntentsByNonce(HUB, 0, 0, 0, 999999999);
    assert(Array.isArray(added), 'added should be an array');
    assert(Array.isArray(filled), 'filled should be an array');
    assert(Array.isArray(enqueued), 'enqueued should be an array');
    assert(added.length > 0, 'Expected at least one added hub intent');
    // Hub chain (25327) has low block numbers since it's a dedicated chain
    if (added[0].addedTxNonce !== undefined) {
      assert(added[0].addedTxNonce! > 0, `addedTxNonce should be a positive blockNumber (got ${added[0].addedTxNonce})`);
    }
    console.log(`    → Added: ${added.length}, Filled: ${filled.length}, Enqueued: ${enqueued.length}`);
  });

  await test('getHubIntentById returns a specific hub intent', async () => {
    const [added] = await reader.getHubIntentsByNonce(HUB, 0, 0, 0, 999999999);
    assert(added.length > 0, 'Need at least one hub intent for lookup test');
    const intent = await reader.getHubIntentById(HUB, added[0].id);
    assert(intent !== undefined, 'Should find the hub intent by ID');
    assert(intent!.id === added[0].id, 'ID should match');
    console.log(`    → Found: ${intent!.id.slice(0, 18)}... status=${intent!.status}`);
  });

  // ── Invoices ───────────────────────────────────────────────────

  console.log('\nInvoices');

  await test('getHubInvoicesByNonce returns invoices and intents', async () => {
    const [invoices, intents] = await reader.getHubInvoicesByNonce(HUB, 0, 999999999);
    assert(Array.isArray(invoices), 'invoices should be an array');
    assert(Array.isArray(intents), 'intents should be an array');
    console.log(`    → ${invoices.length} invoices, ${intents.length} intents`);
  });

  // ── Settlement Intents ─────────────────────────────────────────

  console.log('\nSettlement Intents');

  await test('getSettlementIntentsByNonce returns settlements', async () => {
    const intents = await reader.getSettlementIntentsByNonce(
      new Map([
        [ARBITRUM, { latestNonce: 0, maxBlockNumber: 999999999 }],
        [ETHEREUM, { latestNonce: 0, maxBlockNumber: 999999999 }],
      ]),
    );
    assert(Array.isArray(intents), 'Expected an array');
    console.log(`    → ${intents.length} settlement intents`);
  });

  // ── Deposits ───────────────────────────────────────────────────

  console.log('\nDeposits');

  await test('getDepositsEnqueuedByNonce returns enqueued deposits', async () => {
    const deposits = await reader.getDepositsEnqueuedByNonce(HUB, 0, 999999999);
    assert(Array.isArray(deposits), 'Expected an array');
    console.log(`    → ${deposits.length} enqueued deposits`);
  });

  await test('getDepositsProcessedByNonce returns processed deposits', async () => {
    const deposits = await reader.getDepositsProcessedByNonce(HUB, 0, 999999999);
    assert(Array.isArray(deposits), 'Expected an array');
    console.log(`    → ${deposits.length} processed deposits`);
  });

  // ── Messages ───────────────────────────────────────────────────

  console.log('\nMessages');

  await test('getSpokeMessages returns messages', async () => {
    const messages = await reader.getSpokeMessages(ARBITRUM, 0);
    assert(Array.isArray(messages), 'Expected an array');
    console.log(`    → ${messages.length} spoke messages`);
    if (messages.length > 0) {
      assert(messages[0].txNonce > 1_000_000, `txNonce should be blockNumber-scale (got ${messages[0].txNonce})`);
    }
  });

  await test('getHubMessages returns settlement messages', async () => {
    const messages = await reader.getHubMessages(HUB, 0);
    assert(Array.isArray(messages), 'Expected an array');
    console.log(`    → ${messages.length} hub messages`);
  });

  // ── Orders ─────────────────────────────────────────────────────

  console.log('\nOrders');

  await test('getOrdersByNonce returns orders', async () => {
    const orders = await reader.getOrdersByNonce(
      new Map([[ARBITRUM, { latestNonce: 0, maxBlockNumber: 999999999 }]]),
    );
    assert(Array.isArray(orders), 'Expected an array');
    console.log(`    → ${orders.length} orders`);
  });

  // ── Depositor Events ───────────────────────────────────────────

  console.log('\nDepositor Events');

  await test('getDepositorEvents returns events', async () => {
    const events = await reader.getDepositorEvents(HUB, 0);
    assert(Array.isArray(events), 'Expected an array');
    console.log(`    → ${events.length} depositor events`);
  });

  // ── Audit Trail Stubs ──────────────────────────────────────────

  console.log('\nAudit Trail Stubs (should return empty)');

  await test('getHubMetaUpdates returns empty', async () => {
    const result = await reader.getHubMetaUpdates(HUB, 0);
    assert(result.length === 0, 'Should return empty array');
  });

  await test('getSpokeMetaUpdates returns empty', async () => {
    const result = await reader.getSpokeMetaUpdates(ETHEREUM, 0);
    assert(result.length === 0, 'Should return empty array');
  });

  await test('getHubTokenUpdates returns empty', async () => {
    const result = await reader.getHubTokenUpdates(HUB, 0);
    assert(result.length === 0, 'Should return empty array');
  });

  await test('getHubAssetUpdates returns empty', async () => {
    const result = await reader.getHubAssetUpdates(HUB, 0);
    assert(result.length === 0, 'Should return empty array');
  });

  // ── Summary ────────────────────────────────────────────────────

  console.log(`\n${'═'.repeat(50)}`);
  console.log(`Results: ${passed} passed, ${failed} failed`);
  console.log(`${'═'.repeat(50)}\n`);

  if (failed > 0) process.exit(1);
}

main().catch((e) => {
  console.error('\nFatal error:', e);
  process.exit(1);
});
