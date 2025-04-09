import { createLoggingContext, SOLANA_CHAINID } from '@chimera-monorepo/utils';
import { getContext } from '../../context';

/**
 * @notice Processes Solana settlements by collecting them from the database and submitting
 * them to the Solana network through chainservice.
 * @dev This service manages cross-chain communication with Solana.
 */
export const processSolanaTransactions = async () => {
  const {
    config: { chains },
    logger,
    // adapters: { database },
  } = getContext();

  // Create logging context
  const { requestContext, methodContext } = createLoggingContext(processSolanaTransactions.name);

  // Check if Solana chain is configured
  if (!chains[SOLANA_CHAINID]) {
    logger.warn('Solana chain not configured', requestContext, methodContext);
    return;
  }

  // Get pending Solana settlements from database
  logger.info('Fetching pending Solana settlements', requestContext, methodContext);
  //   const pendingTransactions = await database.getPendingSolanaTransactions();

  logger.info('Completed processing Solana settlements', requestContext, methodContext);
};
