import { createLoggingContext } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { Severity } from '../types';
import { resolveAlerts, sendAlerts } from '../mockable';
import { getTronLastIntentNonce } from '../helpers/tron';

/**
 * Tron-specific pipeline monitoring
 * Provides 1-1 parity with Solana pipeline checks but for Tron chains
 */

const TRON_CHAINID = '728126428'; // Tron mainnet chain ID
const CHECKPOINT_NAME = 'tron_intent_nonce';

export const checkTronPipelineStatus = async (shouldAlert = true): Promise<void> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronPipelineStatus.name);

  logger.debug('Checking Tron pipeline status', requestContext, methodContext);

  // Get the last processed nonce from Tron chain
  const chainNonce = await getTronLastIntentNonce();
  const localNonce = await database.getOriginIntentsLastNonce(TRON_CHAINID);
  const lastSavedNonce = await database.getCheckPoint(CHECKPOINT_NAME);
  
  if (chainNonce === lastSavedNonce) {
    logger.debug('Tron intent nonce match', requestContext, methodContext, {
      chainNonce,
      localNonce,
    });
    return;
  }

  if (localNonce !== lastSavedNonce) {
    await database.saveCheckPoint(CHECKPOINT_NAME, localNonce);
  }

  if (shouldAlert) {
    const report = {
      severity: Severity.Warning,
      type: 'TronPipelineDelay',
      ids: ['TronPipelineDelay'],
      reason: `The Tron pipeline is delayed, local nonce: ${localNonce}, chain nonce: ${chainNonce}`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };
    
    if (chainNonce !== localNonce) {
      logger.warn('Tron intent nonce mismatch', requestContext, methodContext, {
        chainNonce,
        localNonce,
      });

      await sendAlerts(report, logger, config, requestContext);
    } else {
      await resolveAlerts(report, logger, config, requestContext, true);
    }
  }
};

