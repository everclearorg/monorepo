/* eslint-disable @typescript-eslint/no-explicit-any */
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import {
  createMethodContext,
  createRequestContext,
  getChainData,
  Logger,
  sendHeartbeat,
} from '@chimera-monorepo/utils';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { getDatabase } from '@chimera-monorepo/database';
import { CartographerConfig, getSubgraphReaderConfig } from '@chimera-monorepo/cartographer-core';

import { bind } from '../bindings';
import { getConfig } from '../config';
import { context } from '../shared';

export const makePoller = async (_configOverride?: CartographerConfig) => {
  const requestContext = createRequestContext('Poller Init');
  context.adapters = {} as any;

  /// MARK - Config
  // Get ChainData and parse out configuration.
  context.chainData = await getChainData();
  context.config = _configOverride ?? (await getConfig());

  context.logger = new Logger({
    level: context.config.logLevel,
    name: `cartographer-${context.config.service}`,
    formatters: {
      level: (label) => {
        return { level: label.toUpperCase() };
      },
    },
  });

  const methodContext = createMethodContext(`makePoller-${context.config.service}`);
  context.logger.info('Config generated', requestContext, methodContext, { config: context.config });

  /// MARK - Adapters

  // ChainReader setup
  context.adapters.chainreader = new ChainReader(context.logger.child({ module: 'ChainReader' }), {
    ...context.config.chains,
    [context.config.hub.domain]: context.config.hub,
  });

  // Subgraph reader setup
  context.logger.info('Subgraph reader setup in progress...', requestContext, methodContext, {});
  context.adapters.subgraph = SubgraphReader.create(getSubgraphReaderConfig(context.config));
  context.logger.info('Subgraph reader setup is done!', requestContext, methodContext, {});

  // Database setup
  context.adapters.database = await getDatabase(context.config.database, context.logger);

  /// MARK - Bindings
  context.logger.info(`${context.config.service} poller initialized!`, requestContext, methodContext, {
    domains: context.domains,
  });
  context.logger.info(
    `
          _/_/_/_/  _/      _/  _/_/_/_/  _/_/_/      _/_/_/  _/        _/_/_/_/    _/_/    _/_/_/
          _/        _/      _/  _/        _/    _/  _/        _/        _/        _/    _/  _/    _/
        _/_/_/    _/      _/  _/_/_/    _/_/_/    _/        _/        _/_/_/    _/_/_/_/  _/_/_/
        _/          _/  _/    _/        _/    _/  _/        _/        _/        _/    _/  _/    _/
      _/_/_/_/      _/      _/_/_/_/  _/    _/    _/_/_/  _/_/_/_/  _/_/_/_/  _/    _/  _/    _/
     `,
  );

  await bind(context);
  if (context.config.healthUrls[context.config.service] !== undefined) {
    const url = context.config.healthUrls[context.config.service]!;
    await sendHeartbeat(url, context.logger);
  }
};
