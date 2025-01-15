import { Logger, RelayerType, createLoggingContext, jsonifyError, sendHeartbeat } from '@chimera-monorepo/utils';
import { Relayer, setupEverclearRelayer, setupGelatoRelayer } from '@chimera-monorepo/adapters-relayer';
import { Web3Signer } from '@chimera-monorepo/adapters-web3signer';
import { LighthouseConfig, LighthouseService } from './config';
import { ChainService, SafeService } from '@chimera-monorepo/chainservice';
import { Database, getDatabase } from '@chimera-monorepo/database';
import { Wallet } from 'ethers';
import { HistoricPrice } from './tasks/reward/historicPrice';

export type LighthouseContext = {
  logger: Logger;
  config: LighthouseConfig;
  historicPrice: HistoricPrice;
  adapters: {
    wallet: Web3Signer | Wallet;
    database: Database;
    chainservice: ChainService;
    safeservice: SafeService;
    relayers: { instance: Relayer; apiKey: string; type: RelayerType }[];
  };
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const context = {} as any;
export const getContext = (): LighthouseContext => context;

export const makeLighthouseTask = async (
  task: () => Promise<void>,
  config: LighthouseConfig,
  service: LighthouseService,
): Promise<void> => {
  const { requestContext, methodContext } = createLoggingContext(makeLighthouseTask.name);

  try {
    // Store the config
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    context.adapters = {} as any;
    context.config = config;

    context.historicPrice = new HistoricPrice(config.coingecko, config.network);

    // Make logger instance.
    context.logger = new Logger({
      level: context.config.logLevel,
      name: 'lighthouse',
      formatters: {
        level: (label) => {
          return { level: label.toUpperCase() };
        },
      },
    });

    // Adapters - web3 signer
    context.adapters.wallet = config.signer.startsWith('http')
      ? new Web3Signer(config.signer)
      : config.signer.startsWith('0x')
        ? new Wallet(config.signer)
        : Wallet.fromMnemonic(config.signer);

    // Adapters - chain service
    context.adapters.chainservice = new ChainService(
      context.logger.child({ module: 'ChainService', level: context.config.logLevel }),
      {
        ...context.config.chains,
        [context.config.hub.domain]: context.config.hub,
      },
      context.adapters.wallet,
      true, // Ghost instance
    );

    // Adapters - Safe service
    context.adapters.safeservice = new SafeService(
      context.logger.child({ module: 'SafeService', level: context.config.logLevel }),
      {
        domain: context.config.hub.domain,
        // NOTE: providers array was validated in ChainService
        provider: context.config.hub.providers[0],
        safe: context.config.safe,
      },
    );

    // Adapters - Database
    context.adapters.database = await getDatabase(
      config.database.url,
      context.logger.child({ module: 'ChainService' }),
    );

    // Adapters - relayers
    context.adapters.relayers = [];
    for (const relayerConfig of context.config.relayers) {
      const setupFunc =
        relayerConfig.type == RelayerType.Gelato
          ? setupGelatoRelayer
          : relayerConfig.type == RelayerType.Everclear
            ? setupEverclearRelayer
            : undefined;
      if (!setupFunc) {
        throw new Error(`Unknown relayer configured, relayer: ${relayerConfig}`);
      }

      const relayer = await setupFunc(relayerConfig.url);
      context.adapters.relayers.push({
        instance: relayer,
        apiKey: relayerConfig.apiKey,
        type: relayerConfig.type as RelayerType,
      });
    }

    context.logger.info('Lighthouse context setup complete!', requestContext, methodContext, {
      chains: [...Object.keys(context.config.chains)],
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

    // Start the lighthouse task
    await task();
  } catch (e: unknown) {
    console.error('Error creating lighthouse context. Sad! :(', e);
    context.logger.error(
      'Error creating lighthouse context. Sad! :(',
      requestContext,
      methodContext,
      jsonifyError(e as Error),
      {
        service: config.service,
        chains: [...Object.keys(context.config.chains)],
      },
    );
  } finally {
    if (context.config.healthUrls[service]) {
      await sendHeartbeat(context.config.healthUrls[service], context.logger);
    } else {
      context.logger.warn('No health URL configured for service', requestContext, methodContext, { service });
    }
    context.logger.info('Lighthouse task complete!!!', requestContext, methodContext, {
      service: config.service,
      chains: [...Object.keys(context.config.chains)],
    });
  }
};
