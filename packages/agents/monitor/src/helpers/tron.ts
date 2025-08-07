import { getContext } from '../context';
import { createLoggingContext, TRON_CHAINID } from '@chimera-monorepo/utils';
import { Interface } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';
import { TronChainNotConfigured, TronNonceReadFailed, TronSpokeAddressNotConfigured } from '../types';

/**
 * Get the latest nonce from the Tron spoke contract
 * Uses chainreader which has proper TronWeb integration
 */
export const getTronLastIntentNonce = async (): Promise<number> => {
  const {
    config: { chains, abis },
    logger,
    adapters: { chainreader },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(getTronLastIntentNonce.name);

  const chainConfig = chains[TRON_CHAINID];
  if (!chainConfig) {
    throw new TronChainNotConfigured();
  }

  const spokeAddress = chainConfig.deployments?.everclear;
  if (!spokeAddress) {
    throw new TronSpokeAddressNotConfigured();
  }

  try {
    const everclearIface = new Interface(abis.spoke.everclear);
    const encodedNonce = await chainreader.readTx(
      {
        to: spokeAddress,
        data: everclearIface.encodeFunctionData('nonce'),
        domain: +TRON_CHAINID,
        funcSig: everclearIface.getFunction('nonce').format(),
      },
      'latest',
    );
    const [nonce] = everclearIface.decodeFunctionResult('nonce', encodedNonce) as [BigNumber];

    logger.debug('Successfully retrieved Tron last intent nonce', requestContext, methodContext, {
      spokeAddress,
      nonce: nonce.toString(),
    });

    return nonce.toNumber();
  } catch (error) {
    logger.warn('Failed to read Tron last intent nonce from spoke contract', requestContext, methodContext, {
      error,
      spokeAddress,
    });
  }

  throw new TronNonceReadFailed();
};
