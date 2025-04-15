import { createLoggingContext, SOLANA_CHAINID, EverclearSpoke, TIntentStatus } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import * as anchor from '@coral-xyz/anchor';

/**
 * @notice Processes Solana settlements by collecting them from the database and submitting
 * them to the Solana network through chainservice.
 * @dev This service manages cross-chain communication with Solana.
 */
export const processSolanaTransactions = async () => {
  const {
    config: { chains, solana },
    logger,
    adapters: { database },
  } = getContext();

  // Create logging context
  const { requestContext, methodContext } = createLoggingContext(processSolanaTransactions.name);

  // Check if Solana chain is configured
  const chainConfig = chains[SOLANA_CHAINID];
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

  if (!solana.signer) {
    logger.info('Solana signer is not set', requestContext, methodContext);
    return;
  }

  // Set up Solana provider
  const signer = anchor.web3.Keypair.fromSecretKey(
    new Uint8Array(
      solana.signer
        .slice(1, solana.signer.length - 1)
        .split(',')
        .map(Number),
    ),
  );
  const connection = new anchor.web3.Connection(chainConfig.providers[0]);
  const wallet = new anchor.Wallet(signer);
  const provider = new anchor.AnchorProvider(connection, wallet, { commitment: 'confirmed' });
  const spokeAddress = new anchor.web3.PublicKey(solana.spokeAddress);
  const spokeIdl = await anchor.Program.fetchIdl(spokeAddress, provider);
  const spoke = new anchor.Program(JSON.parse(JSON.stringify(spokeIdl)), provider) as anchor.Program<EverclearSpoke>;

  // Process settlements
  for (const settlement of settlements) {
    logger.debug('Settling intent', requestContext, methodContext, { intentId: settlement.intentId });
    const intentId = Buffer.from(settlement.intentId.slice(2), 'hex');
    const [intentStatusPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from('everclear_spoke'), Buffer.from('-'), Buffer.from('intent_status'), intentId],
      spokeAddress,
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
          recipientTokenAccount: intentStatus.accounts[6].pubkey,
          vaultTokenAccount: intentStatus.accounts[7].pubkey,
        })
        .instruction(),
    );

    await anchor.web3.sendAndConfirmTransaction(anchor.getProvider().connection, transaction, [signer]);

    settlement.status = TIntentStatus.Settled;
  }

  // Update the status of the settlements in the database
  await database.saveSettlementIntents(settlements);

  logger.info('Completed processing Solana settlements', requestContext, methodContext);
};
