import { createLoggingContext, SOLANA_CHAINID, TIntentStatus, HyperlaneStatus } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import * as anchor from '@coral-xyz/anchor';

const MAX_RETRIES = 60;

/**
 * @notice Processes Solana settlements by collecting them from the database and submitting
 * them to the Solana network through chainservice.
 * @dev This service manages cross-chain communication with Solana.
 * @dev Reuses Solana connection from context to prevent EMFILE errors
 */
export const processSolanaTransactions = async () => {
  const {
    logger,
    adapters: { database, solana },
  } = getContext();

  // Create logging context
  const { requestContext, methodContext } = createLoggingContext(processSolanaTransactions.name);

  const updatedCount = await database.updateMessageStatuses();
  if (updatedCount > 0) {
    logger.info(`Bulk updated ${updatedCount} message statuses to delivered`, requestContext, methodContext);
  }

  // Get pending Solana settlements from database
  logger.info('Fetching pending Solana settlements', requestContext, methodContext);
  const settlements = await database.getDeliveredSettlements(SOLANA_CHAINID);
  if (!settlements || settlements.length === 0) {
    logger.info('No pending Solana settlements found', requestContext, methodContext);
    return;
  }

  if (!solana) {
    logger.error('Solana adapter not initialized in context', requestContext, methodContext);
    return;
  }
  const { connection, spoke, signer } = solana;

  // Process settlements
  for (const settlement of settlements) {
    logger.debug('Settling intent', requestContext, methodContext, { intentId: settlement.intentId });
    try {
      const intentId = Buffer.from(settlement.intentId.slice(2), 'hex');
      const [intentStatusPda] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from('everclear_spoke'), Buffer.from('-'), Buffer.from('intent_status'), intentId],
        spoke.programId,
      );

      const intentStatus = await spoke.account.intentStatusAccount.fetch(intentStatusPda);

      const transaction = new anchor.web3.Transaction().add(
        await spoke.methods
          .settleDeliveredIntent({
            intentId: Array.from(intentId),
          })
          .accountsPartial({
            authority: signer.publicKey,
            spokeState: intentStatus.accounts[0].pubkey,
            intentStatusPda: intentStatus.accounts[1].pubkey,
            vaultAuthority: intentStatus.accounts[2].pubkey,
            tokenProgram: intentStatus.accounts[3].pubkey,
            systemProgram: intentStatus.accounts[4].pubkey,
            mintAccount: intentStatus.accounts[5].pubkey,
            associatedTokenProgram: intentStatus.accounts[6].pubkey,
            recipient: intentStatus.accounts[7].pubkey,
            recipientTokenAccount: intentStatus.accounts[8].pubkey,
            vaultTokenAccount: intentStatus.accounts[9].pubkey,
          })
          .instruction(),
      );

      await anchor.web3.sendAndConfirmTransaction(connection, transaction, [signer], { maxRetries: MAX_RETRIES });

      // Update the status of the settlement in the database
      await database.updateSettlementStatus(settlement.intentId, TIntentStatus.Settled);

      // Update the message status in the database
      const messages = await database.getMessagesByIntentIds([settlement.intentId]);
      for (const message of messages) {
        if (message.destinationDomain === SOLANA_CHAINID && message.status !== HyperlaneStatus.delivered) {
          await database.updateMessageStatus(message.id, HyperlaneStatus.delivered);
          break;
        }
      }
    } catch (error) {
      logger.error('Failed to settle intent', requestContext, methodContext, {
        message: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
        type: error instanceof Error ? error.constructor.name : typeof error,
        context: { intentId: settlement.intentId },
      }); // Continue to the next settlement
    }
  }

  logger.info('Completed processing Solana settlements', requestContext, methodContext);
};
