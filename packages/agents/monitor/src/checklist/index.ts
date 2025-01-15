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
} from './queue';
import { getContext } from '../context';
import { checkSpokeBalance } from './spoke';
import { checkShadowExportLatency, checkShadowExportStatus } from './shadow';
import { checkTokenomicsExportLatency, checkTokenomicsExportStatus } from './tokenomics';

export const runChecks = async () => {
  const { requestContext, methodContext } = createLoggingContext(runChecks.name);
  const checklist = [
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
    checkShadowExportStatus,
    checkShadowExportLatency,
    checkTokenomicsExportStatus,
    checkTokenomicsExportLatency,
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
