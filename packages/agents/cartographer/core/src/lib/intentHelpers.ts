import { OriginIntent, Logger, createLoggingContext, jsonifyError } from '@chimera-monorepo/utils';
import { CartographerConfig } from '../config';

export const computeIsSwap = (
  intent: OriginIntent,
  config: CartographerConfig,
  logger: Logger,
): boolean => {
  const { requestContext, methodContext } = createLoggingContext('computeIsSwap');

  let isSwap = false;
  try {
    const originChain = config.chains[intent.origin];
    const destinationChain = intent.destinations.length > 0 ? config.chains[intent.destinations[0]] : null;

    if (originChain?.assets && destinationChain?.assets) {
      const inputAssetConfig = Object.values(originChain.assets).find(
        (asset) => asset.address.toLowerCase() === intent.inputAsset.toLowerCase(),
      );
      const outputAssetConfig = Object.values(destinationChain.assets).find(
        (asset) => asset.address.toLowerCase() === intent.outputAsset.toLowerCase(),
      );

      if (inputAssetConfig && outputAssetConfig) {
        if (
          typeof inputAssetConfig.tickerHash === 'string' &&
          typeof outputAssetConfig.tickerHash === 'string'
        ) {
          isSwap = inputAssetConfig.tickerHash.toLowerCase() !== outputAssetConfig.tickerHash.toLowerCase();
        } else {
          isSwap = false;
          logger.warn('Missing tickerHash on asset config when computing is_swap flag', requestContext, methodContext, {
            intentId: intent.id,
            inputAsset: intent.inputAsset,
            outputAsset: intent.outputAsset,
            inputTickerHash: inputAssetConfig.tickerHash,
            outputTickerHash: outputAssetConfig.tickerHash,
          });
        }
        logger.debug('Computed is_swap flag', requestContext, methodContext, {
          intentId: intent.id,
          inputAsset: intent.inputAsset,
          outputAsset: intent.outputAsset,
          inputTickerHash: inputAssetConfig.tickerHash,
          outputTickerHash: outputAssetConfig.tickerHash,
          isSwap,
        });
      } else {
        logger.debug('Could not find asset configs for intent', requestContext, methodContext, {
          intentId: intent.id,
          inputAsset: intent.inputAsset,
          outputAsset: intent.outputAsset,
          foundInputAsset: !!inputAssetConfig,
          foundOutputAsset: !!outputAssetConfig,
        });
      }
    }
  } catch (error) {
    logger.error('Error computing is_swap flag', requestContext, methodContext, jsonifyError(error as Error), {
      intentId: intent.id,
    });
  }

  return isSwap;
};
