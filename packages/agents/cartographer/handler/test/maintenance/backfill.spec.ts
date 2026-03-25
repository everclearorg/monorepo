import { expect, LIGHTHOUSE_QUEUES } from '@chimera-monorepo/utils';
import { stub, restore, SinonStub } from 'sinon';
import { AppContext } from '@chimera-monorepo/cartographer-core';

import * as mockable from '../../src/mockable';
import { runBackfill } from '../../src/maintenance/backfill';
import * as notify from '../../src/notify';
import { createAppContext } from '../mock';

describe('backfill', () => {
  let context: AppContext;
  let notifyStub: SinonStub;

  // Core operations that should trigger lighthouse notifications
  let updateOriginIntentsStub: SinonStub;
  let updateDestinationIntentsStub: SinonStub;
  let updateHubIntentsStub: SinonStub;
  let updateSettlementIntentsStub: SinonStub;
  let updateHubInvoicesStub: SinonStub;
  let updateHubDepositsStub: SinonStub;
  let updateMessagesStub: SinonStub;

  // Core operations that should NOT trigger lighthouse notifications
  let updateOrdersStub: SinonStub;
  let updateAssetsStub: SinonStub;
  let updateDepositorsStub: SinonStub;
  let updateQueuesStub: SinonStub;
  let updateHubSpokeMetaStub: SinonStub;
  let updateProtocolUpdateLogsStub: SinonStub;
  let updateMessageStatusStub: SinonStub;

  beforeEach(() => {
    context = createAppContext();
    notifyStub = stub(notify, 'notifyLighthouse').resolves();

    // Notify operations — default to returning empty set (no new data)
    updateOriginIntentsStub = stub(mockable, 'updateOriginIntents').resolves(new Set());
    updateDestinationIntentsStub = stub(mockable, 'updateDestinationIntents').resolves(new Set());
    updateHubIntentsStub = stub(mockable, 'updateHubIntents').resolves(new Set());
    updateHubInvoicesStub = stub(mockable, 'updateHubInvoices').resolves(new Set());
    updateHubDepositsStub = stub(mockable, 'updateHubDeposits').resolves(new Set());

    // Plain operations
    updateSettlementIntentsStub = stub(mockable, 'updateSettlementIntents').resolves();
    updateMessagesStub = stub(mockable, 'updateMessages').resolves();
    updateOrdersStub = stub(mockable, 'updateOrders').resolves();
    updateAssetsStub = stub(mockable, 'updateAssets').resolves();
    updateDepositorsStub = stub(mockable, 'updateDepositors').resolves();
    updateQueuesStub = stub(mockable, 'updateQueues').resolves();
    updateHubSpokeMetaStub = stub(mockable, 'updateHubSpokeMeta').resolves();
    updateProtocolUpdateLogsStub = stub(mockable, 'updateProtocolUpdateLogs').resolves();
    updateMessageStatusStub = stub(mockable, 'updateMessageStatus').resolves();
  });

  afterEach(() => {
    restore();
  });

  it('should run all operations', async () => {
    await runBackfill(context);

    expect(updateOriginIntentsStub.callCount).to.equal(1);
    expect(updateDestinationIntentsStub.callCount).to.equal(1);
    expect(updateHubIntentsStub.callCount).to.equal(1);
    expect(updateSettlementIntentsStub.callCount).to.equal(1);
    expect(updateHubInvoicesStub.callCount).to.equal(1);
    expect(updateHubDepositsStub.callCount).to.equal(1);
    expect(updateMessagesStub.callCount).to.equal(1);
    expect(updateOrdersStub.callCount).to.equal(1);
    expect(updateAssetsStub.callCount).to.equal(1);
    expect(updateDepositorsStub.callCount).to.equal(1);
    expect(updateQueuesStub.callCount).to.equal(1);
    expect(updateHubSpokeMetaStub.callCount).to.equal(1);
    expect(updateProtocolUpdateLogsStub.callCount).to.equal(1);
    expect(updateMessageStatusStub.callCount).to.equal(1);
  });

  it('should not notify lighthouse when no operations return new data', async () => {
    await runBackfill(context);

    expect(notifyStub.callCount).to.equal(0);
  });

  it('should notify INTENT queue when updateOriginIntents finds new data', async () => {
    updateOriginIntentsStub.resolves(new Set([LIGHTHOUSE_QUEUES.INTENT]));

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.INTENT)).to.be.true;
  });

  it('should notify FILL queue when updateDestinationIntents finds new data', async () => {
    updateDestinationIntentsStub.resolves(new Set([LIGHTHOUSE_QUEUES.FILL]));

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.FILL)).to.be.true;
  });

  it('should notify SETTLEMENT queue when updateHubIntents finds enqueued intents', async () => {
    updateHubIntentsStub.resolves(new Set([LIGHTHOUSE_QUEUES.SETTLEMENT]));

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.SETTLEMENT)).to.be.true;
  });

  it('should notify INVOICE queue when updateHubInvoices finds new data', async () => {
    updateHubInvoicesStub.resolves(new Set([LIGHTHOUSE_QUEUES.INVOICE]));

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.INVOICE)).to.be.true;
  });

  it('should notify INVOICE queue when updateHubDeposits finds new data', async () => {
    updateHubDepositsStub.resolves(new Set([LIGHTHOUSE_QUEUES.INVOICE]));

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.INVOICE)).to.be.true;
  });

  it('should deduplicate queue notifications across operations', async () => {
    // Both updateHubInvoices and updateHubDeposits return INVOICE
    updateHubInvoicesStub.resolves(new Set([LIGHTHOUSE_QUEUES.INVOICE]));
    updateHubDepositsStub.resolves(new Set([LIGHTHOUSE_QUEUES.INVOICE]));

    await runBackfill(context);

    // INVOICE should be notified only once despite two operations returning it
    const invoiceCalls = notifyStub.getCalls().filter((c: { args: string[] }) => c.args[0] === LIGHTHOUSE_QUEUES.INVOICE);
    expect(invoiceCalls.length).to.equal(1);
  });

  it('should continue running remaining operations when one fails', async () => {
    updateOriginIntentsStub.rejects(new Error('subgraph timeout'));

    await runBackfill(context);

    expect(updateDestinationIntentsStub.callCount).to.equal(1);
    expect(updateHubIntentsStub.callCount).to.equal(1);
    expect(updateOrdersStub.callCount).to.equal(1);
  });

  it('should not notify for a queue whose operation failed', async () => {
    updateOriginIntentsStub.rejects(new Error('subgraph timeout'));

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.INTENT)).to.be.false;
  });

  it('should still notify other queues when one operation fails', async () => {
    updateOriginIntentsStub.rejects(new Error('subgraph timeout'));
    updateHubIntentsStub.resolves(new Set([LIGHTHOUSE_QUEUES.SETTLEMENT]));

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.INTENT)).to.be.false;
    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.SETTLEMENT)).to.be.true;
  });

  it('should refresh materialized views', async () => {
    await runBackfill(context);

    const db = context.adapters.database;
    expect((db.refreshIntentsView as SinonStub).callCount).to.equal(1);
    expect((db.refreshInvoicesView as SinonStub).callCount).to.equal(1);
  });
});
