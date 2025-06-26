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

  for (const providerUrl of providers) {
    const connection = new anchor.web3.Connection(providerUrl);
    const wallet = new anchor.Wallet(anchor.web3.Keypair.generate());
    const provider = new anchor.AnchorProvider(connection, wallet);
    const spokeAddress = new anchor.web3.PublicKey(config.solana.spokeAddress);
    const spokeIdl = await anchor.Program.fetchIdl(spokeAddress, provider);
    const spoke = new anchor.Program(spokeIdl as anchor.Idl, provider) as unknown as anchor.Program<EverclearSpoke>;
    const [spokeStateAddress] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from('spoke-state')],
      spokeAddress,
    );

    try {
      const spokeState = await spoke.account.spokeState.fetch(spokeStateAddress);
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
