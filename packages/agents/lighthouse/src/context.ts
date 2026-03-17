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

/**
 * Initializes the lighthouse context with all adapters.
 * Used by both the handler (BullMQ worker) mode and makeLighthouseTask.
 * @param config - Lighthouse configuration
 * @param logger - Logger instance to use for the context
 * @param initSolana - Whether to initialize Solana adapters (default: true)
 */
export const initializeLighthouseContext = async (
  config: LighthouseConfig,
  logger: Logger,
  initSolana = true,
): Promise<LighthouseContext> => {
  const { requestContext, methodContext } = createLoggingContext(initializeLighthouseContext.name);

  logFileDescriptorUsage(logger);

  if (shouldExitForFileDescriptors()) {
    throw new Error('File descriptor usage too high');
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  context.adapters = {} as any;
  context.config = config;
  context.logger = logger;

  context.historicPrice = new HistoricPrice(config.coingecko, config.network);

  // Adapters - web3 signer
  context.adapters.wallet = config.signer.startsWith('http')
    ? new Web3Signer(config.signer)
    : config.signer.startsWith('0x')
      ? new EthWallet(config.signer)
      : EthWallet.fromMnemonic(config.signer);

  // Adapters - chain service
  context.adapters.chainservice = new ChainService(
    logger.child({ module: 'ChainService', level: config.logLevel }),
    {
      ...config.chains,
      [config.hub.domain]: config.hub,
    },
    context.adapters.wallet,
    true,
  );

  // Adapters - Safe service
  context.adapters.safeservice = new SafeService(logger.child({ module: 'SafeService', level: config.logLevel }), {
    domain: config.hub.domain,
    provider: config.hub.providers[0],
    safe: config.safe,
  });

  // Adapters - Database
  context.adapters.database = await getDatabase(config.database.url, logger.child({ module: 'Database' }));

  // Adapters - relayers
  context.adapters.relayers = [];
  for (const relayerConfig of config.relayers) {
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

  // Adapters - Solana
  const chainConfig = config.chains[SOLANA_CHAINID];
  if (initSolana && chainConfig && chainConfig.providers && chainConfig.providers.length > 0 && config.solana?.signer) {
    const idl =
      config.environment === 'production'
        ? JSON.parse(JSON.stringify(idlFile))
        : JSON.parse(JSON.stringify(stagingIdlFile));

    const connection = new anchor.web3.Connection(chainConfig.providers[0]);
    const signer = anchor.web3.Keypair.fromSecretKey(
      new Uint8Array(
        config.solana.signer
          .slice(1, config.solana.signer.length - 1)
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

  context.logger.info('Lighthouse context initialized', requestContext, methodContext, {
    chains: [...Object.keys(config.chains)],
    hasSolana: !!context.adapters.solana,
  });

  return context;
};

export const makeLighthouseTask = async (
  task: () => Promise<void>,
  config: LighthouseConfig,
  service?: LighthouseService,
): Promise<void> => {
  const { requestContext, methodContext } = createLoggingContext(makeLighthouseTask.name);

  // Create logger with formatters for task mode
  const logger = new Logger({
    level: config.logLevel || 'info',
    name: 'lighthouse',
    formatters: {
      level: (label) => {
        return { level: label.toUpperCase() };
      },
    },
  });

  try {
    await initializeLighthouseContext(config, logger, service === 'solana');

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
    logFileDescriptorUsage(logger);

    // Start the lighthouse task
    await task();

    // Log file descriptor usage after task completion
    logFileDescriptorUsage(logger);
  } catch (e: unknown) {
    console.error('Error creating lighthouse context. Sad! :(', e);
    logger.error(
      'Error creating lighthouse context. Sad! :(',
      requestContext,
      methodContext,
      jsonifyError(e as Error),
      {
        service: config.service,
        chains: [...Object.keys(config.chains)],
      },
    );
  } finally {
    if (service && config.healthUrls[service]) {
      await sendHeartbeat(config.healthUrls[service], logger);
    } else if (service) {
      logger.warn('No health URL configured for service', requestContext, methodContext, { service });
    }
    logger.info('Lighthouse task complete!!!', requestContext, methodContext, {
      service: config.service,
      chains: [...Object.keys(config.chains)],
    });
  }
};
