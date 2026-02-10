import {
  Logger,
  RelayerType,
  createLoggingContext,
  jsonifyError,
  sendHeartbeat,
  logFileDescriptorUsage,
  shouldExitForFileDescriptors,
  EverclearSpoke,
  SOLANA_CHAINID,
} from '@chimera-monorepo/utils';
import { Relayer, setupEverclearRelayer, setupGelatoRelayer } from '@chimera-monorepo/adapters-relayer';
import { Web3Signer } from '@chimera-monorepo/adapters-web3signer';
import { LighthouseConfig, LighthouseService } from './config';
import { ChainService, SafeService, EthWallet } from '@chimera-monorepo/chainservice';
import { Database, getDatabase } from '@chimera-monorepo/database';
import { HistoricPrice } from './tasks/reward/historicPrice';
import * as anchor from '@coral-xyz/anchor';
import idlFile from './idl/everclear_spoke.json';
import stagingIdlFile from './idl/everclear_spoke.staging.json';

export type LighthouseContext = {
  logger: Logger;
  config: LighthouseConfig;
  historicPrice: HistoricPrice;
  adapters: {
    wallet: Web3Signer | EthWallet;
    database: Database;
    chainservice: ChainService;
    safeservice: SafeService;
    relayers: { instance: Relayer; apiKey: string; type: RelayerType }[];
    solana?: {
      connection: anchor.web3.Connection;
      spoke: anchor.Program<EverclearSpoke>;
      signer: anchor.web3.Keypair;
    };
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

  // Log file descriptor usage at the start of invocation
  let logger: Logger | undefined;
  try {
    // Create a temporary logger for file descriptor logging before context is fully initialized
    logger = new Logger({
      level: config.logLevel || 'info',
      name: 'lighthouse',
    });
    logFileDescriptorUsage(logger);

    // Exit early if the file descriptor usage is too high, otherwise it will fail with EMFILE error later on.
    if (shouldExitForFileDescriptors()) {
      logger.error('Exiting due to high file descriptor usage', requestContext, methodContext);
      return;
    }
  } catch (e: unknown) {
    // If logging fails, continue anyway (don't block execution)
    console.warn('Failed to log file descriptor usage:', e);
  }

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
        ? new EthWallet(config.signer)
        : EthWallet.fromMnemonic(config.signer);

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
      const relayer =
        relayerConfig.type == RelayerType.Gelato
          ? await setupGelatoRelayer(relayerConfig.apiKey)
          : relayerConfig.type == RelayerType.Everclear
            ? await setupEverclearRelayer(relayerConfig.url)
            : undefined;
      if (!relayer) {
        throw new Error(`Unknown relayer configured, relayer: ${relayerConfig}`);
      }
      context.adapters.relayers.push({
        instance: relayer,
        apiKey: relayerConfig.apiKey,
        type: relayerConfig.type as RelayerType,
      });
    }

    // Adapters - Solana (only for solana service, reuse connection to avoid EMFILE errors)
    const chainConfig = context.config.chains[SOLANA_CHAINID];
    if (service === 'solana' && chainConfig) {
      if (chainConfig.providers && chainConfig.providers.length > 0 && context.config.solana?.signer) {
        const idl =
          context.config.environment === 'production'
            ? JSON.parse(JSON.stringify(idlFile))
            : JSON.parse(JSON.stringify(stagingIdlFile));

        const connection = new anchor.web3.Connection(chainConfig.providers[0]);
        const signer = anchor.web3.Keypair.fromSecretKey(
          new Uint8Array(
            context.config.solana.signer
              .slice(1, context.config.solana.signer.length - 1)
              .split(',')
              .map(Number),
          ),
        );
        const wallet = new anchor.Wallet(signer);
        const provider = new anchor.AnchorProvider(connection, wallet, { commitment: 'confirmed' });
        const spoke = new anchor.Program(idl, provider) as anchor.Program<EverclearSpoke>;

        context.adapters.solana = {
          connection,
          spoke,
          signer,
        };
      }
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

    // Log file descriptor usage after context setup (before task execution)
    logFileDescriptorUsage(context.logger);

    // Start the lighthouse task
    await task();

    // Log file descriptor usage after task completion
    logFileDescriptorUsage(context.logger);
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
