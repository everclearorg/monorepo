import { createLoggingContext, jsonifyError } from '@chimera-monorepo/utils';
import { getContext, setupSubgraphReader } from '../../watcher';
import interval from 'interval-promise';
import { getConfig, getSubgraphReaderConfig, shouldReloadEverclearConfig } from '../../config';
import { ChainService } from '@chimera-monorepo/chainservice';

/**
 * Bind the Everclear configuration changes and reload if necessary.
 */
export const bindConfig = () => {
  const context = getContext();
  const { requestContext, methodContext } = createLoggingContext(bindConfig.name);
  interval(async () => {
    try {
      const { reloadConfig, reloadSubgraph } = await shouldReloadEverclearConfig();
      if (reloadConfig) {
        const config = await getConfig();
        context.config = config;
        const hubChainServiceConfig: Record<string, object> = {
          [context.config.hub.domain]: {
            providers: context.config.hub.providers,
          },
        };

        context.adapters.chainservice = new ChainService(
          context.logger.child({ module: 'ChainService', level: context.config.logLevel }),
          { ...context.config.chains, ...hubChainServiceConfig },
          context.adapters.wallet,
          true, // Ghost instance, in the event that this is running in the same process as a solver.
        );
      }

      if (reloadSubgraph) {
        const { domain: hubDomain, ...remainder } = context.config.hub;
        context.adapters.subgraph = await setupSubgraphReader(
          getSubgraphReaderConfig({ ...context.config.chains, [hubDomain]: remainder }),
          context.logger,
          requestContext,
        );
      }
    } catch (e: unknown) {
      context.logger.error(
        'Error binding everclear config changes, waiting for next loop',
        requestContext,
        methodContext,
        jsonifyError(e as Error),
      );
    }
  }, context.config.reloadConfigInterval);
};
