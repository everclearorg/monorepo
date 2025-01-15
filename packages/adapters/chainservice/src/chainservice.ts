import { providers } from 'ethers';
import { createLoggingContext, Logger, EverclearError, RequestContext } from '@chimera-monorepo/utils';

import { ChainConfig } from './config';
import { WriteTransaction, ConfigurationError, ProviderNotConfigured, ITransactionReceipt, ISigner } from './shared';
import { ChainReader } from './chainreader';
import { TransactionDispatch } from './dispatch';

// TODO: Should take on the logic of Dispatch (rename to TransactionDispatch) and consume ChainReader instead of extending it.
/**
 * @classdesc Handles submitting, confirming, and bumping gas of arbitrary transactions onchain. Also performs onchain reads with embedded retries
 */
export class ChainService extends ChainReader {
  // TODO: #152 Add an object/dictionary statically to the class prototype mapping the
  // signer to a flag indicating whether there is an instance using that signer.
  // This will prevent two queue instances using the same signer and therefore colliding.
  // Idea is to have essentially a modified 'singleton'-like pattern.
  // private static _instances: Map<string, ChainService> = new Map();
  private static instance?: ChainService;

  /**
   * A singleton-like interface for handling all logic related to conducting on-chain transactions.
   *
   * @remarks
   * Using the Signer instance passed into this constructor outside of the context of this
   * class is not recommended, and may cause issues with nonce being tracked improperly
   * due to the caching mechanisms used here.
   *
   * @param logger The Logger used for logging.
   * @param signer The Signer or Wallet instance, or private key, for signing transactions.
   * @param config At least a partial configuration used by ChainService for chains,
   * providers, etc.
   * @param ghostInstance Used in the event that we are conducting an integration test (which will have
   * multiple txservice instances) and want to prevent this instantiation from being saved as the singleton.
   */
  constructor(logger: Logger, config: unknown, signer: string | ISigner, _ghostInstance = false) {
    super(logger, config, signer);
    const { requestContext, methodContext } = createLoggingContext('ChainService.constructor');
    // TODO: #152 See above TODO. Should we have a getInstance() method and make constructor private ??
    // const _signer: string = typeof signer === "string" ? signer : signer.getAddress();
    // if (ChainService._instances.has(_signer)) {}
    if (ChainService.instance) {
      const msg = 'CRITICAL: ChainService.constructor was called twice! Please report this incident.';
      const error = new EverclearError(msg);
      logger.error(msg, requestContext, methodContext, error, {
        instance: ChainService.instance.toString(),
      });
      throw error;
    }
    // Set the singleton instance.
    if (!_ghostInstance) {
      ChainService.instance = this;
    }
  }

  /**
   * Send specified transaction on specified chain and wait for the configured number of confirmations.
   * Will emit events throughout its lifecycle.
   *
   * @param tx - Tx to send
   * @param tx.domain - Domain identifier of chain to send transaction on
   * @param tx.to - Address to send tx to
   * @param tx.value - Value to send tx with
   * @param tx.data - Calldata to execute
   * @param tx.from - (optional) Account to send tx from
   *
   * @returns TransactionReceipt once the tx is mined if the transaction was successful.
   *
   * @throws TransactionError with one of the reasons specified in ValidSendErrors. If another error occurs,
   * something went wrong within ChainService process.
   * @throws ChainServiceFailure, which indicates something went wrong with the service logic.
   */
  public async sendTx(tx: WriteTransaction, context: RequestContext): Promise<ITransactionReceipt> {
    const { requestContext, methodContext } = createLoggingContext(this.sendTx.name, context);
    this.logger.debug('Method start', requestContext, methodContext, {
      tx: { ...tx, value: tx.value.toString(), data: `${tx.data.substring(0, 9)}...` },
    });
    return await this.getProvider(tx.domain).send(tx, context);
  }

  /// HELPERS
  /**
   * Helper to wrap getting signer address for specified domain.
   * @returns The signer address for that chain.
   * @throws TransactionError.reasons.ProviderNotFound if provider is not configured for
   * that ID.
   */
  public getAddress(): Promise<string> {
    // Ensure that a signer, provider, etc are present to execute on this domain.
    const [chain, provider] = [...this.providers.entries()][0];
    if (!chain) {
      throw new ProviderNotConfigured(chain.toString());
    }
    return provider.getAddress();
  }

  /**
   * Helper to wrap getting provider for specified domain.
   * @param domain The domain of the chain for which we want a provider.
   * @returns The ChainRpcProvider for that chain.
   * @throws TransactionError.reasons.ProviderNotFound if provider is not configured for
   * that ID.
   */
  public getProvider(domain: number): TransactionDispatch {
    // Ensure that a signer, provider, etc are present to execute on this domain.
    if (!this.providers.has(domain)) {
      throw new ProviderNotConfigured(domain.toString());
    }
    return this.providers.get(domain)! as TransactionDispatch;
  }

  // TODO: Use a generic type in ChainReader.setupProviders for this method such that we don't have to overload it here.
  /**
   * Populate the provider mapping using chain configurations.
   * @param context - The request context object used for logging.
   * @param signer - The signer that will be used for onchain operations.
   */
  protected setupProviders(context: RequestContext, signer: string) {
    const { methodContext } = createLoggingContext(this.setupProviders.name, context);
    // For each domain / provider, map out all the utils needed for each chain.
    Object.keys(this.config).forEach((_domain) => {
      // Convert to number
      const domain = +_domain;
      // Get this chain's config.
      const chain: ChainConfig = this.config[domain];
      // Ensure at least one provider is configured.
      if (chain.providers.length === 0) {
        const error = new ConfigurationError(
          [
            {
              parameter: 'providers',
              error: 'No valid providers were supplied in configuration for this chain.',
              value: providers,
            },
          ],
          {
            domain,
          },
        );
        this.logger.error('Failed to create transaction service', context, methodContext, error.toJson(), {
          domain,
          providers,
        });
        throw error;
      }
      const provider = new TransactionDispatch(this.logger, domain, chain, signer);
      this.providers.set(domain, provider);
    });
  }
}
