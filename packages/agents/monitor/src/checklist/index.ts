import { createLoggingContext } from '@chimera-monorepo/utils';
import { checkAgents } from './agent';
import { checkChains } from './chain';
import { checkGas } from './gas';
import { checkRpcs } from './rpc';
import { checkElapsedEpochsByTickerHash } from './epochs';
import {
  checkFillQueueCount,
  checkSettlementQueueStatusCount,
  checkSettlementQueueLatency,
  checkMessageStatus,
  checkDepositQueueCount,
  checkDepositQueueLatency,
  checkFillQueueLatency,
  checkIntentQueueCount,
  checkIntentQueueLatency,
  checkInvoiceAmount,
  checkInvoices,
  // Tron queue monitoring
  checkTronFillQueueCount,
  checkTronFillQueueLatency,
  checkTronIntentQueueCount,
  checkTronIntentQueueLatency,
  checkTronSettlementQueueStatusCount,
  checkTronSettlementQueueLatency,
  checkTronDepositQueueCount,
  checkTronDepositQueueLatency,
} from './queue';
import { getContext } from '../context';
import { checkSpokeBalance } from './spoke';
import { checkTokenomicsExportLatency, checkTokenomicsExportStatus } from './tokenomics';
import { checkSolanaPipelineStatus } from './solana';
// Tron-specific monitoring imports
import { checkTronChains, checkTronRpcs, checkTronGas } from './tron';
import { checkTronSpokeBalance } from './tron-spoke';
import { checkTronMessageStatus } from './tron-message';
import { checkTronElapsedEpochsByTickerHash } from './tron-epochs';
import { checkTronPipelineStatus } from './tron-pipeline';

export const runChecks = async () => {
  const { requestContext, methodContext } = createLoggingContext(runChecks.name);
  const checklist = [
    // EVM monitoring checks
    checkChains,
    checkAgents,
    checkMessageStatus,
    checkRpcs,
    checkGas,
    checkSpokeBalance,
    checkIntentQueueCount,
    checkIntentQueueLatency,
    checkFillQueueCount,
    checkFillQueueLatency,
    // TODO: Replace with a metrics push to track  settlement queue amounts over time
    // checkSettlementQueueAmount,
    checkSettlementQueueStatusCount,
    checkSettlementQueueLatency,
    checkDepositQueueCount,
    checkDepositQueueLatency,
    checkElapsedEpochsByTickerHash,
    checkInvoices,
    checkInvoiceAmount,
    checkTokenomicsExportStatus,
    checkTokenomicsExportLatency,
    checkSolanaPipelineStatus,
    
    // Tron monitoring checks - 1:1 parity with EVM
    checkTronChains,
    checkTronRpcs,
    checkTronGas,
    checkTronSpokeBalance,
    checkTronMessageStatus,
    checkTronIntentQueueCount,
    checkTronIntentQueueLatency,
    checkTronFillQueueCount,
    checkTronFillQueueLatency,
    checkTronSettlementQueueStatusCount,
    checkTronSettlementQueueLatency,
    checkTronDepositQueueCount,
    checkTronDepositQueueLatency,
    checkTronElapsedEpochsByTickerHash,
    checkTronPipelineStatus,
  ];

  const { logger } = getContext();
  logger.info(`Running checks... fns: ${checklist.map((it) => it.name).join(',')}`, requestContext, methodContext);
  for (const checkFn of checklist) {
    const startTime = Date.now();
    await checkFn();
    const endTime = Date.now();
    logger.debug(`Elapsed time: ${(endTime - startTime) / 1000}s`, requestContext, methodContext);
  }
};
