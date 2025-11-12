import {
  createLoggingContext,
  SOLANA_CHAINID,
  EverclearSpoke,
  TIntentStatus,
  HyperlaneStatus,
} from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import * as anchor from '@coral-xyz/anchor';
import idlFile from '../../idl/everclear_spoke.json';
import stagingIdlFile from '../../idl/everclear_spoke.staging.json';

const MAX_RETRIES = 60;

/**
 * @notice Processes Solana settlements by collecting them from the database and submitting
 * them to the Solana network through chainservice.
 * @dev This service manages cross-chain communication with Solana.
 */
export const processSolanaTransactions = async () => {
  const {
    config: { chains, solana, environment },
    logger,
    adapters: { database },
  } = getContext();

  // Create logging context
  const { requestContext, methodContext } = createLoggingContext(processSolanaTransactions.name);

  const updatedCount = await database.updateSolanaMessageStatuses();
  logger.info(`Bulk updated ${updatedCount} solana message statuses to delivered`, requestContext, methodContext);

  // Check if Solana chain is configured
  const chainConfig = chains[SOLANA_CHAINID];
  let idl;
  if (environment === 'production') {
    idl = JSON.parse(JSON.stringify(idlFile));
  } else {
    idl = JSON.parse(JSON.stringify(stagingIdlFile));
  }

  if (!chainConfig) {
    logger.warn('Solana chain not configured', requestContext, methodContext);
    return;
  }

  if (!chainConfig.providers || !chainConfig.providers.length) {
    logger.warn('Solana provider not configured', requestContext, methodContext);
    return;
  }

  // Get pending Solana settlements from database
  logger.info('Fetching pending Solana settlements', requestContext, methodContext);
  const settlements = await database.getDeliveredSettlements(SOLANA_CHAINID);
  if (!settlements || settlements.length === 0) {
    logger.info('No pending Solana settlements found', requestContext, methodContext);
    return;
  }

  // Set up Solana provider with mainnet connection
  const connection = new anchor.web3.Connection(chainConfig.providers[0]);

  if (!solana.signer) {
    logger.info('Solana signer is not set', requestContext, methodContext);
    return;
  }

  const signer = anchor.web3.Keypair.fromSecretKey(
    new Uint8Array(
      solana.signer
        .slice(1, solana.signer.length - 1)
        .split(',')
        .map(Number),
    ),
  );

  // Create a wallet from the signer
  const wallet = new anchor.Wallet(signer);

  // Create a custom provider with the mainnet connection and wallet
  const provider = new anchor.AnchorProvider(connection, wallet, { commitment: 'confirmed' });

  const spokeProgramId = new anchor.web3.PublicKey(idl.address);
  if (!spokeProgramId) {
    throw new Error('solana.spokeProgramId not configured');
  }

  const spoke = new anchor.Program(idl, provider) as anchor.Program<EverclearSpoke>;

  // Process settlements
  for (const settlement of settlements) {
    logger.debug('Settling intent', requestContext, methodContext, { intentId: settlement.intentId });
    try {
      const intentId = Buffer.from(settlement.intentId.slice(2), 'hex');
      const [intentStatusPda] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from('everclear_spoke'), Buffer.from('-'), Buffer.from('intent_status'), intentId],
        spokeProgramId,
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
