import { createLoggingContext, RequestContext } from '@chimera-monorepo/utils';
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
import { checkTokenomicsExportLatency, checkTokenomicsExportStatus } from './tokenomics';
import { checkSolanaPipelineStatus } from './solana';

export const runChecks = async (_requestContext?: RequestContext) => {
  const { methodContext, requestContext } = createLoggingContext(runChecks.name, _requestContext);
  const checklist = [
    checkAgents,
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
    checkInvoiceAmount,
    checkTokenomicsExportStatus,
    checkTokenomicsExportLatency,
    checkSolanaPipelineStatus,
    checkInvoices,
    checkMessageStatus,
    checkChains,
    checkRpcs,
    checkGas,
    checkSpokeBalance,
  ];

  const { logger } = getContext();
  logger.info(`Running checks... fns: ${checklist.map((it) => it.name).join(',')}`, requestContext, methodContext);
  for (const checkFn of checklist) {
    const startTime = Date.now();
    logger.debug(`Starting check`, requestContext, methodContext, {
      startTime,
      check: checkFn.name,
    });
    await checkFn();
    const endTime = Date.now();
    const elapsed = endTime - startTime;
    if (elapsed > 90_000) {
      logger.warn(`Check took more than 90s`, requestContext, methodContext, {
        elapsedSec: elapsed / 1000,
        check: checkFn.name,
      });
    } else {
      logger.debug(`Elapsed time for check`, requestContext, methodContext, {
        elapsedSec: elapsed / 1000,
        check: checkFn.name,
      });
    }
  }
};
