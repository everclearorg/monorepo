/* eslint-disable @typescript-eslint/no-explicit-any */
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import {
  createMethodContext,
  createRequestContext,
  getChainData,
  Logger,
  sendHeartbeat,
} from '@chimera-monorepo/utils';
import { closeDatabase, getDatabase } from '@chimera-monorepo/database';

import { bind } from '../bindings';
import { CartographerConfig, getConfig } from '../config';
import { context } from '../shared';
import { runMigration } from '../lib/operations';
import { getSubgraphReaderConfig } from '../lib/operations/helper';

export const makePoller = async (_configOverride?: CartographerConfig) => {
  const requestContext = createRequestContext('Poller Init');
  context.adapters = {} as any;

  /// MARK - Config
  // Get ChainData and parse out configuration.
  const chainData = await getChainData();
  context.chainData = chainData;
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

  // Subgraph reader setup
  context.logger.info('Subgraph reader setup in progress...', requestContext, methodContext, {});
  context.adapters.subgraph = SubgraphReader.create(getSubgraphReaderConfig(context.config));
  context.logger.info('Subgraph reader setup is done!', requestContext, methodContext, {});

  // Database setup
  context.adapters.database = await getDatabase(context.config.database, context.logger);

  // TODO: Validate subgraph and database connections ?

  /// MARK - Bindings
  context.logger.info(`${context.config.service} poller initialized!`, requestContext, methodContext, {
    domains: context.domains,
  });
  console.log(
    `                                                                                         
          _/_/_/_/  _/      _/  _/_/_/_/  _/_/_/      _/_/_/  _/        _/_/_/_/    _/_/    _/_/_/    
          _/        _/      _/  _/        _/    _/  _/        _/        _/        _/    _/  _/    _/   
        _/_/_/    _/      _/  _/_/_/    _/_/_/    _/        _/        _/_/_/    _/_/_/_/  _/_/_/      
        _/          _/  _/    _/        _/    _/  _/        _/        _/        _/    _/  _/    _/     
      _/_/_/_/      _/      _/_/_/_/  _/    _/    _/_/_/  _/_/_/_/  _/_/_/_/  _/    _/  _/    _/                                                                                                  
     `,
  );

  await runMigration(context);
  await bind(context);
  await closeDatabase();
  if (context.config.healthUrls[context.config.service] !== undefined) {
    const url = context.config.healthUrls[context.config.service]!;
    await sendHeartbeat(url, context.logger);
  }
};
