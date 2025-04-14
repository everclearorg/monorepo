import { createLoggingContext, SOLANA_CHAINID, EverclearSpoke } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { NoProvidersConfigured, UnableToGetSpokeState } from '../types';
import * as anchor from '@coral-xyz/anchor';

export const getLastSolanaIntentNonce = async (): Promise<number> => {
  const { config, logger } = getContext();
  const { requestContext, methodContext } = createLoggingContext(getLastSolanaIntentNonce.name);

  const providers = config.chains[SOLANA_CHAINID].providers;
  if (!providers || !providers.length) {
    throw new NoProvidersConfigured({
      domain: SOLANA_CHAINID,
    });
  }

  for (const provider of providers) {
    anchor.setProvider(anchor.AnchorProvider.local(provider));
    const program = anchor.workspace.EverclearSpoke as anchor.Program<EverclearSpoke>;
    const [spokeStateAddress] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from('spoke-state')],
      program.programId,
    );

    try {
      const spokeState = await program.account.spokeState.fetch(spokeStateAddress);
      return spokeState.nonce.toNumber();
    } catch (error) {
      logger.warn('Solana spoke state fetching failed', requestContext, methodContext, {
        provider,
        error,
      });
    }
  }

  throw new UnableToGetSpokeState();
};
