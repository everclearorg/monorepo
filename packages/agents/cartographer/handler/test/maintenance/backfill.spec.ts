import { expect } from '@chimera-monorepo/utils';
import { stub, restore, SinonStub } from 'sinon';
import { AppContext } from '@chimera-monorepo/cartographer-core';
import { LIGHTHOUSE_QUEUES } from '@chimera-monorepo/mqclient';

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

    // Notify operations — default to returning 0 (no new data)
    updateOriginIntentsStub = stub(mockable, 'updateOriginIntents').resolves(0);
    updateDestinationIntentsStub = stub(mockable, 'updateDestinationIntents').resolves(0);
    updateHubIntentsStub = stub(mockable, 'updateHubIntents').resolves(0);
    updateSettlementIntentsStub = stub(mockable, 'updateSettlementIntents').resolves(0);
    updateHubInvoicesStub = stub(mockable, 'updateHubInvoices').resolves(0);
    updateHubDepositsStub = stub(mockable, 'updateHubDeposits').resolves(0);
    updateMessagesStub = stub(mockable, 'updateMessages').resolves(0);

    // Plain operations
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
    updateOriginIntentsStub.resolves(3);

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.INTENT)).to.be.true;
  });

  it('should notify FILL queue when updateDestinationIntents finds new data', async () => {
    updateDestinationIntentsStub.resolves(2);

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.FILL)).to.be.true;
  });

  it('should notify INTENT and FILL queues when updateHubIntents finds new data', async () => {
    updateHubIntentsStub.resolves(5);

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.INTENT)).to.be.true;
    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.FILL)).to.be.true;
  });

  it('should notify SETTLEMENT queue when updateSettlementIntents finds new data', async () => {
    updateSettlementIntentsStub.resolves(1);

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.SETTLEMENT)).to.be.true;
  });

  it('should notify INVOICE queue when updateHubInvoices finds new data', async () => {
    updateHubInvoicesStub.resolves(4);

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.INVOICE)).to.be.true;
  });

  it('should notify INVOICE queue when updateHubDeposits finds new data', async () => {
    updateHubDepositsStub.resolves(2);

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.INVOICE)).to.be.true;
  });

  it('should notify SETTLEMENT, FILL, and SOLANA queues when updateMessages finds new data', async () => {
    updateMessagesStub.resolves(3);

    await runBackfill(context);

    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.SETTLEMENT)).to.be.true;
    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.FILL)).to.be.true;
    expect(notifyStub.calledWith(LIGHTHOUSE_QUEUES.SOLANA)).to.be.true;
  });

  it('should deduplicate queue notifications', async () => {
    // Both updateOriginIntents and updateHubIntents map to INTENT
    updateOriginIntentsStub.resolves(1);
    updateHubIntentsStub.resolves(1);

    await runBackfill(context);

    // INTENT should be notified only once despite two operations triggering it
    const intentCalls = notifyStub.getCalls().filter((c: { args: string[] }) => c.args[0] === LIGHTHOUSE_QUEUES.INTENT);
    expect(intentCalls.length).to.equal(1);
  });

  it('should continue running remaining operations when one fails', async () => {
    updateOriginIntentsStub.rejects(new Error('subgraph timeout'));

    await runBackfill(context);

    // Other operations should still have been called
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
    updateSettlementIntentsStub.resolves(2);

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
