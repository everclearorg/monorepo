import { constants } from 'ethers';
import { createLoggingContext, Logger, RequestContext } from '@chimera-monorepo/utils';

import { ChainServiceConfig, validateChainServiceConfig, ChainConfig } from './config';
import { ReadTransaction, ConfigurationError, ProviderNotConfigured, WriteTransaction, ISigner } from './shared';
import { RpcProviderAggregator } from './aggregator';

// TODO: Rename to BlockchainService
// TODO: I do not like that this is generally a passthrough class now - all it handles is the mapping. We should
// probably just expose a provider getter method and have the consumer call that to access the target ChainRpcProvider
// directly.

/**
 * @classdesc Performs onchain reads with embedded retries.
 */
export class ChainReader {
  protected providers: Map<number, RpcProviderAggregator> = new Map();
  protected readonly config: ChainServiceConfig;

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
   */
  constructor(
    protected readonly logger: Logger,
    config: unknown,
    signer?: ISigner | string,
  ) {
    const { requestContext } = createLoggingContext(this.constructor.name);
    // Set up the config.
    this.config = validateChainServiceConfig(config);
    this.setupProviders(requestContext, signer);
  }

  /// CHAIN READING METHODS
  /**
   * Create a non-state changing contract call. Returns hexdata that needs to be decoded.
   *
   * @param tx - ReadTransaction to create contract call
   * @param tx.domain - Chain to read transaction on
   * @param tx.to - Address to execute read on
   * @param tx.data - Calldata to send
   * @param blockTag - (optional) Block tag to query, defaults to latest
   *
   * @returns Encoded hexdata representing result of the read from the chain.
   */
  public async readTx(tx: ReadTransaction, blockTag: number | string): Promise<string> {
    return await this.getProvider(tx.domain).readContract(tx, blockTag);
  }

  /**
   * Gets the asset balance for a specified address for the specified chain. Optionally pass in the
   * assetId; by default, gets the native asset.
   *
   * @param domain - The ID of the chain for which this call is related.
   * @param address - The hexadecimal string address whose balance we are getting.
   * @param assetId (default = ETH) - The ID (address) of the asset whose balance we are getting.
   * @param abi - The ABI of the token contract to use for interfacing with it, if applicable (non-native).
   * Defaults to ERC20.
   *
   * @returns BigNumber representing the current value held by the wallet at the
   * specified address.
   */
  public async getBalance(domain: number, address: string, assetId = constants.AddressZero): Promise<string> {
    return await this.getProvider(domain).getBalance(address, assetId);
  }
  /**
   * Get the current gas price for the chain for which this instance is servicing.
   *
   * @param domain - The ID of the chain for which this call is related.
   * @param requestContext - The request context.
   * @returns BigNumber representing the current gas price.
   */
  public async getGasPrice(domain: number, requestContext: RequestContext): Promise<string> {
    return await this.getProvider(domain).getGasPrice(requestContext);
  }

  /**
   * Gets the decimals for an asset by domain
   *
   * @param domain - The ID of the chain for which this call is related.
   * @param assetId - The hexadecimal string address whose decimals we are getting.
   * @returns number representing the decimals of the asset
   */
  public async getDecimalsForAsset(domain: number, assetId: string): Promise<number> {
    return await this.getProvider(domain).getDecimalsForAsset(assetId);
  }

  /**
   * Gets a block
   *
   * @param domain - The ID of the chain for which this call is related.
   * @returns block representing the specified
   */
  public async getBlock(domain: number, blockHashOrBlockTag: number | string) {
    return await this.getProvider(domain).getBlock(blockHashOrBlockTag);
  }

  /**
   * Gets the current blocktime
   *
   * @param domain - The ID of the chain for which this call is related.
   * @returns number representing the current blocktime
   */
  public async getBlockTime(domain: number): Promise<number> {
    return await this.getProvider(domain).getBlockTime();
  }

  /**
   * Gets the current block number
   *
   * @param domain - The ID of the chain for which this call is related.
   * @returns number representing the current block
   */
  public async getBlockNumber(domain: number): Promise<number> {
    return await this.getProvider(domain).getBlockNumber();
  }

  /**
   * Gets a trsanction receipt by hash
   *
   * @param domain - The ID of the chain for which this call is related.
   * @returns number representing the current blocktime
   */
  public async getTransactionReceipt(domain: number, hash: string) {
    return await this.getProvider(domain).getTransactionReceipt(hash);
  }

  /**
   * Returns a hexcode string representation of the contract code at the given
   * address. If there is no contract deployed at the given address, returns "0x".
   *
   * @param address - contract address.
   *
   * @returns Hexcode string representation of contract code.
   */
  public async getCode(domain: number, address: string): Promise<string> {
    return await this.getProvider(domain).getCode(address);
  }

  /**
   * Checks estimate for gas limit for given transaction on given chain.
   *
   * @param domain - chain on which the transaction is intended to be executed.
   * @param tx - transaction to check gas limit for.
   *
   * @returns BigNumber representing the estimated gas limit in gas units.
   * @throws Error if the transaction is invalid, or would be reverted onchain.
   */
  public async getGasEstimate(domain: number, tx: WriteTransaction): Promise<string> {
    return await this.getProvider(domain).getGasEstimate(tx);
  }

  /**
   * Checks estimate for gas limit for given transaction on given chain. Includes revert
   * error codes if failure occurs.
   *
   * @param domain - chain on which the transaction is intended to be executed.
   * @param tx - transaction to check gas limit for.
   *
   * @returns BigNumber representing the estimated gas limit in gas units.
   * @throws Error if the transaction is invalid, or would be reverted onchain.
   */
  public async getGasEstimateWithRevertCode(tx: WriteTransaction): Promise<string> {
    return await this.getProvider(tx.domain).estimateGas(tx);
  }

  /// CONTRACT READ METHODS

  /**
   * Helper to check for chain support gently.
   *
   * @param domain - domain of the chain to check
   * @returns boolean indicating whether chain of domain is supported by the service
   */
  public isSupportedChain(domain: number): boolean {
    return this.providers.has(domain);
  }

  /// HELPERS
  /**
   * Helper to wrap getting provider for specified domain.
   * @param domain The ID of the chain for which we want a provider.
   * @returns The ChainRpcProvider for that chain.
   * @throws TransactionError.reasons.ProviderNotFound if provider is not configured for
   * that ID.
   */
  protected getProvider(domain: number): RpcProviderAggregator {
    // Ensure that a signer, provider, etc are present to execute on this domain.
    if (!this.providers.has(domain)) {
      throw new ProviderNotConfigured(domain.toString());
    }
    return this.providers.get(domain)!;
  }

  /**
   * Populate the provider mapping using chain configurations.
   * @param context - The request context object used for logging.
   * @param signer - The signer that will be used for onchain operations.
   */
  protected setupProviders(context: RequestContext, signer?: ISigner | string) {
    const { methodContext } = createLoggingContext(this.setupProviders.name, context);
    // For each domain / provider, map out all the utils needed for each chain.
    Object.keys(this.config).forEach((domain) => {
      // Get this chain's config.
      const chain: ChainConfig = this.config[domain];
      // Ensure at least one provider is configured.
      if (chain.providers.length === 0) {
        const error = new ConfigurationError(
          [
            {
              parameter: 'providers',
              error: 'No valid providers were supplied in configuration for this chain.',
              value: chain.providers,
            },
          ],
          {
            domain,
          },
        );
        this.logger.error('Failed to create transaction service', context, methodContext, error.toJson(), {
          domain,
          providers: chain.providers,
        });
        throw error;
      }
      const domainNumber = parseInt(domain);
      const provider = new RpcProviderAggregator(this.logger, domainNumber, chain, signer);
      this.providers.set(domainNumber, provider);
    });
  }
}
