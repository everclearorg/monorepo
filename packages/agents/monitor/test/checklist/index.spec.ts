import { expect } from 'chai';
import sinon from 'sinon';
import { runChecks } from './../../src/checklist/';
import * as chain from './../../src/checklist/chain';
import * as gas from './../../src/checklist/gas';
import * as agent from './../../src/checklist/agent';
import * as rpc from './../../src/checklist/rpc';
import * as intent from './../../src/checklist/queue/intent';
import * as settlementQueue from './../../src/checklist/queue/settlement';
import * as settlement from './../../src/checklist/epochs';
import * as spoke from './../../src/checklist/spoke';
import * as deposit from './../../src/checklist/queue/deposit';
import * as invoice from './../../src/checklist/queue/invoice';
import * as message from './../../src/checklist/queue/message';
import * as shadow from "./../../src/checklist/shadow";
import * as tokenomics from "./../../src/checklist/tokenomics";

describe('runChecks', () => {
  let sandbox: sinon.SinonSandbox;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should run all checks', async () => {
    const logger = {
      info: sandbox.stub(),
      debug: sandbox.stub(),
    };
    const context = {
      config: {},
      logger,
    };

    const chainsStub = sandbox.stub(chain, 'checkChains').resolves();
    const checkGasStub = sandbox.stub(gas, 'checkGas').resolves();
    const agentsStub = sandbox.stub(agent, 'checkAgents').resolves();
    const rpcStub = sandbox.stub(rpc, 'checkRpcs').resolves();
    const checkSpokeBalanceStub = sandbox.stub(spoke, 'checkSpokeBalance').resolves();
    const messageStub = sandbox.stub(message, 'checkMessageStatus').resolves();
    const checkIntentQueueCountStub = sandbox.stub(intent, 'checkIntentQueueCount').resolves();
    const checkIntentQueueLatencyStub = sandbox.stub(intent, 'checkIntentQueueLatency').resolves();
    const checkFillQueueCountStub = sandbox.stub(intent, 'checkFillQueueCount').resolves();
    const checkFillQueueLatencyStub = sandbox.stub(intent, 'checkFillQueueLatency').resolves();
    // const checkSettlementQueueAmountStub = sandbox.stub(settlementQueue, 'checkSettlementQueueAmount').resolves();
    const checkSettlementQueueStatusCountStub = sandbox
      .stub(settlementQueue, 'checkSettlementQueueStatusCount')
      .resolves();
    const checkSettlementQueueLatencyStub = sandbox.stub(settlementQueue, 'checkSettlementQueueLatency').resolves();
    const checkDepositQueueCountStub = sandbox.stub(deposit, 'checkDepositQueueCount').resolves();
    const checkDepositQueueLatencyStub = sandbox.stub(deposit, 'checkDepositQueueLatency').resolves();
    const checkElapsedEpochsByTickerHashStub = sandbox.stub(settlement, 'checkElapsedEpochsByTickerHash').resolves();
    const checkInvoiceAmountStub = sandbox.stub(invoice, 'checkInvoiceAmount').resolves();
    const checkInvoicesStub = sandbox.stub(invoice, 'checkInvoices').resolves();
    const checkShadowExportStatusStub = sandbox.stub(shadow, 'checkShadowExportStatus').resolves();
    const checkShadowExportLatencyStub = sandbox.stub(shadow, 'checkShadowExportLatency').resolves();
    const checkTokenomicsExportStatusStub = sandbox.stub(tokenomics, 'checkTokenomicsExportStatus').resolves();
    const checkTokenomicsExportLatencyStub = sandbox.stub(tokenomics, 'checkTokenomicsExportLatency').resolves();
    

    await runChecks();

    expect(chainsStub.calledOnce).to.be.true;
    expect(agentsStub.calledOnce).to.be.true;
    expect(rpcStub.calledOnce).to.be.true;
    expect(checkSpokeBalanceStub.calledOnce).to.be.true;
    expect(checkGasStub.calledOnce).to.be.true;
    expect(messageStub.calledOnce).to.be.true;
    expect(checkIntentQueueCountStub.calledOnce).to.be.true;
    expect(checkIntentQueueLatencyStub.calledOnce).to.be.true;
    expect(checkFillQueueCountStub.calledOnce).to.be.true;
    expect(checkFillQueueLatencyStub.calledOnce).to.be.true;
    // expect(checkSettlementQueueAmountStub.calledOnce).to.be.true;
    expect(checkSettlementQueueStatusCountStub.calledOnce).to.be.true;
    expect(checkSettlementQueueLatencyStub.calledOnce).to.be.true;
    expect(checkDepositQueueCountStub.calledOnce).to.be.true;
    expect(checkDepositQueueLatencyStub.calledOnce).to.be.true;
    expect(checkElapsedEpochsByTickerHashStub.calledOnce).to.be.true;
    expect(checkInvoiceAmountStub.calledOnce).to.be.true;
    expect(checkInvoicesStub.calledOnce).to.be.true;
    expect(checkShadowExportStatusStub.calledOnce).to.be.true;
    expect(checkShadowExportLatencyStub.calledOnce).to.be.true;
    expect(checkTokenomicsExportStatusStub.calledOnce).to.be.true;
    expect(checkTokenomicsExportLatencyStub.calledOnce).to.be.true;
  });
});
