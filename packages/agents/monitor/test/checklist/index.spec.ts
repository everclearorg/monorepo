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
import * as tokenomics from "./../../src/checklist/tokenomics";
import * as solana from "./../../src/checklist/solana";

// Import Tron modules
import * as tronSpokeModule from './../../src/checklist/tron-spoke';
import * as tronModule from './../../src/checklist/tron';  
import * as tronEpochsModule from './../../src/checklist/tron-epochs';
import * as tronMessageModule from './../../src/checklist/tron-message';
import * as tronPipelineModule from './../../src/checklist/tron-pipeline';
import * as tronDepositModule from './../../src/checklist/queue/tron-deposit';
import * as tronIntentModule from './../../src/checklist/queue/tron-intent';
import * as tronSettlementModule from './../../src/checklist/queue/tron-settlement';

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
    const checkTokenomicsExportStatusStub = sandbox.stub(tokenomics, 'checkTokenomicsExportStatus').resolves();
    const checkTokenomicsExportLatencyStub = sandbox.stub(tokenomics, 'checkTokenomicsExportLatency').resolves();
    const checkSolanaPipelineStatusStub = sandbox.stub(solana, 'checkSolanaPipelineStatus').resolves();
    
    // Add Tron stubs
    const checkTronSpokeBalanceStub = sandbox.stub(tronSpokeModule, 'checkTronSpokeBalance').resolves();
    const checkTronGasStub = sandbox.stub(tronModule, 'checkTronGas').resolves();
    const checkTronMessageStatusStub = sandbox.stub(tronMessageModule, 'checkTronMessageStatus').resolves();
    const checkTronIntentQueueCountStub = sandbox.stub(tronIntentModule, 'checkTronIntentQueueCount').resolves();
    const checkTronIntentQueueLatencyStub = sandbox.stub(tronIntentModule, 'checkTronIntentQueueLatency').resolves();
    const checkTronFillQueueCountStub = sandbox.stub(tronIntentModule, 'checkTronFillQueueCount').resolves();
    const checkTronFillQueueLatencyStub = sandbox.stub(tronIntentModule, 'checkTronFillQueueLatency').resolves();
    const checkTronSettlementQueueStatusCountStub = sandbox.stub(tronSettlementModule, 'checkTronSettlementQueueStatusCount').resolves();
    const checkTronSettlementQueueLatencyStub = sandbox.stub(tronSettlementModule, 'checkTronSettlementQueueLatency').resolves();
    const checkTronDepositQueueCountStub = sandbox.stub(tronDepositModule, 'checkTronDepositQueueCount').resolves();
    const checkTronDepositQueueLatencyStub = sandbox.stub(tronDepositModule, 'checkTronDepositQueueLatency').resolves();
    const checkTronElapsedEpochsByTickerHashStub = sandbox.stub(tronEpochsModule, 'checkTronElapsedEpochsByTickerHash').resolves();
    const checkTronPipelineStatusStub = sandbox.stub(tronPipelineModule, 'checkTronPipelineStatus').resolves();

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
    expect(checkTokenomicsExportStatusStub.calledOnce).to.be.true;
    expect(checkTokenomicsExportLatencyStub.calledOnce).to.be.true;
    expect(checkSolanaPipelineStatusStub.calledOnce).to.be.true;
    
    // Add Tron expectations
    expect(checkTronSpokeBalanceStub.calledOnce).to.be.true;
    expect(checkTronGasStub.calledOnce).to.be.true;
    expect(checkTronMessageStatusStub.calledOnce).to.be.true;
    expect(checkTronIntentQueueCountStub.calledOnce).to.be.true;
    expect(checkTronIntentQueueLatencyStub.calledOnce).to.be.true;
    expect(checkTronFillQueueCountStub.calledOnce).to.be.true;
    expect(checkTronFillQueueLatencyStub.calledOnce).to.be.true;
    expect(checkTronSettlementQueueStatusCountStub.calledOnce).to.be.true;
    expect(checkTronSettlementQueueLatencyStub.calledOnce).to.be.true;
    expect(checkTronDepositQueueCountStub.calledOnce).to.be.true;
    expect(checkTronDepositQueueLatencyStub.calledOnce).to.be.true;
    expect(checkTronElapsedEpochsByTickerHashStub.calledOnce).to.be.true;
    expect(checkTronPipelineStatusStub.calledOnce).to.be.true;
  });
});
