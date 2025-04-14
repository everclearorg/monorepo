import { createLoggingContext } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { Severity } from '../types';
import { resolveAlerts, sendAlerts } from '../mockable';
import { getLastSolanaIntentNonce } from '../helpers';
import { SOLANA_CHAINID } from '@chimera-monorepo/utils';

const CHECKPOINT_NAME = 'solana_intent_nonce';

export const checkSolanaPipelineStatus = async (shouldAlert = true): Promise<void> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkSolanaPipelineStatus.name);

  logger.debug('Checking solana pipeline status', requestContext, methodContext);

  const chainNonce = await getLastSolanaIntentNonce();
  const localNonce = await database.getOriginIntentsLastNonce(SOLANA_CHAINID);
  const lastSavedNonce = await database.getCheckPoint(CHECKPOINT_NAME);
  if (chainNonce === lastSavedNonce) {
    logger.debug('Solana intent nonce match', requestContext, methodContext, {
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
      type: 'SolanaPipelineDelay',
      ids: [],
      reason: `The solana pipeline is delayed, local nonce: ${localNonce}, chain nonce: ${chainNonce}`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };
    if (chainNonce !== localNonce) {
      logger.warn('Solana intent nonce mismatch', requestContext, methodContext, {
        chainNonce,
        localNonce,
      });

      await sendAlerts(report, logger, config, requestContext);
    } else {
      await resolveAlerts(report, logger, config, requestContext, true);
    }
  }
};
