import {
  createLoggingContext,
  createRequestContext,
  delay,
  jsonifyError,
  Logger,
  EverclearError,
  RequestContext,
} from '@chimera-monorepo/utils';
import { BigNumber, constants, utils, BigNumberish, providers } from 'ethers';

import { validateProviderConfig, ChainConfig } from './config';
import {
  ConfigurationError,
  GasEstimateInvalid,
  parseError,
  RpcError,
  ServerError,
  OperationTimeout,
  TransactionReadError,
  TransactionReverted,
  ProviderCache,
  ReadTransaction,
  OnchainTransaction,
  StallTimeout,
  WriteTransaction,
  QuorumNotMet,
  RpcProvider,
  getRpcClient,
  ISigner,
  ITransactionReceipt,
  MissingSigner,
  ITransactionRequest,
} from './shared';
import { axiosGet } from './mockable';

// TODO: Move to config; alternatively, configure based on time, not blocks.
// A provider must be within this many blocks of the "leading" provider (provider with the highest block) to be considered in-sync.
const PROVIDER_MAX_LAG = 30;
// Default value for block period time (in ms) if we're unable to attain that info from the providers for some reason.
const DEFAULT_BLOCK_PERIOD = 2_000;

type ChainRpcProviderCache = { gasPrice: BigNumber; transactionCount: number };

// TODO: Multiton?
/**
 * @classdesc An aggregator for all the providers that are used to make RPC calls on a specified chain. Only
 * 1 aggregator should exist per chain. Responsible for provider fallback capabilities, syncing, and caching.
 */
export class RpcProviderAggregator {
  // The array of underlying RpcProviders.
  private readonly providers: RpcProvider[];
  // The provider that's most in sync with the chain, and has an active block listener.
  public leadProvider: RpcProvider | undefined;

  private readonly signer?: ISigner;

  private lastUsedGasPrice: BigNumber | undefined = undefined;

  // Cached decimal values per asset. Saved separately from main cache as decimals obviously don't expire.
  private cachedDecimals: Record<string, number> = {};
  // Cached block length in time (ms), used for optimizing waiting periods.
  private blockPeriod: number = DEFAULT_BLOCK_PERIOD;

  // Cache of transient data (i.e. data that can change per block).
  private cache: ProviderCache<ChainRpcProviderCache>;

  /**
   * A class for managing the usage of an ethers FallbackProvider, and for wrapping calls in
   * retries. Will ensure provider(s) are ready before any use case.
   *
   * @param logger - Logger used for logging.
   * @param signer - Signer instance or private key used for signing transactions.
   * @param domain - The ID of the chain for which this class's providers will be servicing.
   * @param chainConfig - Configuration for this specified chain, including the providers we'll
   * be using for it.
   * @param config - The shared ChainServiceConfig with general configuration.
   *
   * @throws ChainError.reasons.ProviderNotFound if no valid providers are found in the
   * configuration.
   */
  constructor(
    protected readonly logger: Logger,
    public readonly domain: number,
    protected readonly config: ChainConfig,
    signer?: ISigner | string,
  ) {
    const { requestContext, methodContext } = createLoggingContext('ChainRpcProvider.constructor');

    // Register a provider for each url.
    // Make sure all providers are ready()
    const providerConfigs = this.config.providers;
    const filteredConfigs = providerConfigs.filter((config) => {
      const valid = validateProviderConfig(config);
      if (!valid) {
        this.logger.warn('Configuration was invalid for provider.', requestContext, methodContext, {
          config,
        });
      }
      return valid;
    });
    if (filteredConfigs.length > 0) {
      const hydratedConfigs = filteredConfigs.map((config) => ({
        provider: getRpcClient(this.domain, config.url),
        priority: config.priority ?? 1,
        weight: config.weight ?? 1,
        stallTimeout: config.stallTimeout,
      }));
      this.providers = hydratedConfigs.map((p) => p.provider);
    } else {
      // Not enough valid providers were found in configuration.
      // We must throw here, as the consumer won't be able to support this chain without valid provider configs.
      throw new ConfigurationError(
        [
          {
            parameter: 'providers',
            error: 'No valid providers were supplied in configuration for this chain.',
            value: providerConfigs,
          },
        ],
        {
          domain,
        },
      );
    }

    if (signer) {
      this.signer = this.providers[0].getSigner(signer);
    } else {
      this.signer = undefined;
    }

    // TODO: Make ttl/btl values below configurable ?
    this.cache = new ProviderCache<ChainRpcProviderCache>(this.logger, {
      gasPrice: {
        ttl: 30_000,
      },
      transactionCount: {
        ttl: 2_000,
      },
    });

    // This initial call of sync providers will start the first block listener (on the lead provider) and set up
    // the cache with correct initial values (as well as establish which providers are out-of-sync).
    this.syncProviders();

    // Set up the initial value for block period. Will run asyncronously, and update the value (from the default) when
    // it completes.
    this.setBlockPeriod();
  }

  /**
   * Send the transaction request to the provider.
   *
   * @remarks This method is set to access protected since it should really only be used by the inheriting class,
   * TransactionDispatch, as of the time of writing this.
   *
   * @param tx The transaction used for the request.
   *
   * @returns The ethers TransactionResponse.
   */
  protected async sendTransaction(transaction: OnchainTransaction) {
    this.checkSigner();
    // NOTE: We do not use execute for this call as it should be delegated to fallback provider, who
    // will call the method on all providers.
    // TODO: We may want to adapt execute to take on this functionality as it's the last step towards
    // making fallback provider obsolete (and making this class the real fallback provider).
    const toSend = {
      ...transaction.params,
      gasLimit: transaction.params.gasLimit ? BigNumber.from(transaction.params.gasLimit) : undefined,
      gasPrice: transaction.params.gasPrice ? BigNumber.from(transaction.params.gasPrice) : undefined,
      value: BigNumber.from(transaction.params.value || 0),
    };
    return await this.leadProvider!.connect(this.signer!).sendTransaction(toSend as unknown as ITransactionRequest);
  }

  /**
   * Get the receipt for the transaction with the specified hash, optionally blocking
   * until a specified timeout.
   *
   * @param hash - The hexadecimal hash string of the transaction.
   * @param confirmations - Optional parameter to override the configured number of confirmations
   * required to validate the receipt.
   * @param timeout - Optional timeout parameter in ms to override the configured parameter.
   *
   * @returns The ethers TransactionReceipt, if mined, otherwise null.
   */
  public async confirmTransaction(
    transaction: OnchainTransaction,
    confirmations: number = this.config.confirmations,
    timeout: number = this.config.confirmationTimeout,
  ) {
    const start = Date.now();
    // Using a timed out variable calculated at the end of the loop - this way we can be sure at
    // least one iteration is completed here.
    let timedOut = false;
    let remainingConfirmations = confirmations;
    let mined = false;
    let reverted: ITransactionReceipt[] = [];
    let errors: EverclearError[] = [];
    while (!timedOut) {
      errors = [];
      reverted = [];
      // Populate a list of promises to retrieve every receipt for every hash.
      const _receipts = transaction.responses.map(async (response) => {
        try {
          return await this.getTransactionReceipt(response.hash);
        } catch (error: unknown) {
          errors.push(error as EverclearError);
          return null;
        }
      });
      // Wait until all the 'receipts' (or errors) have been pushed to the list.
      const receipts = (await Promise.all(_receipts)).filter(
        (r) => r !== null && r !== undefined,
      ) as providers.TransactionReceipt[];

      for (const receipt of receipts) {
        if (receipt!.status === 1) {
          // Receipt status is successful, check to see if we have enough confirmations.
          mined = true;
          remainingConfirmations = confirmations - receipt!.confirmations;
          if (remainingConfirmations <= 0) {
            return receipt;
          }
        } else {
          // Receipt status indicates tx was reverted.
          reverted.push(receipt);
        }
      }

      if (!mined) {
        // If the tx was not mined yet, the tx may have been reverted (or other errors may have occurred).
        if (reverted.length > 0) {
          throw new TransactionReverted(TransactionReverted.reasons.CallException, reverted[0]!);
        } else if (errors.length > 0) {
          throw errors[0];
        }
      }

      // If we timed out this round, no need to wait.
      timedOut = Date.now() - start >= timeout;
      if (!timedOut) {
        // If we haven't resolved yet, wait for the designated parity (or target blocks) before we check again.
        await this.wait(remainingConfirmations);
      }
    }
    throw new OperationTimeout({
      targetConfirmations: confirmations,
      remainingConfirmations,
      reverted,
      errors,
      timeout,
      timedOut,
      mined,
    });
  }

  /**
   * Execute a read transaction using the passed in transaction data, which includes
   * the target contract which we are reading from.
   *
   * @param tx - Minimal transaction data needed to read from chain.
   * @param blockTag - Block number to look at, defaults to latest
   *
   * @returns A string of data read from chain.
   * @throws ChainError.reasons.ContractReadFailure in the event of a failure
   * to read from chain.
   */
  public async readContract(tx: ReadTransaction, blockTag: number | string): Promise<string> {
    return this.execute<string>(false, async (provider: RpcProvider) => {
      try {
        return await provider.call(tx, blockTag);
      } catch (error: unknown) {
        throw new TransactionReadError(TransactionReadError.reasons.ContractReadError, { error });
      }
    });
  }

  /**
   * Get the onchain transaction corresponding with the given hash.
   *
   * @param tx - Either the string hash of the transaction to retrieve, or the OnchainTransaction object.
   *
   * @returns An array of TransactionResponses (the transaction data), or null. If the array is all null, then the
   * transaction and any/all replacements could not be found. Only 1 element in the array should ever be not null.
   */
  public async getTransaction(tx: string | OnchainTransaction) {
    if (typeof tx === 'string') {
      return this.execute(false, async (provider: RpcProvider) => {
        return [await provider.getTransaction(tx)];
      });
    }
    const errors: EverclearError[] = [];
    const txs = await Promise.all(
      tx.responses.map(async (response) => {
        try {
          return this.execute(false, async (provider: RpcProvider) => {
            return await provider.getTransaction(response.hash);
          });
        } catch (error: unknown) {
          errors.push(error as EverclearError);
          return undefined;
        }
      }),
    );
    if (errors.length === tx.responses.length) {
      // All of the executions failed. This indicates a fundamental problem, like all RPC providers are failing.
      // Throw the first error received.
      throw errors[0];
    }
    return txs;
  }

  /**
   * Estimate gas cost for the specified transaction.
   *
   * @remarks
   *
   * Because estimateGas is almost always our "point of failure" - the point where its
   * indicated by the provider that our tx would fail on chain - and ethers obscures the
   * revert error code when it fails through its typical API, we had to implement our own
   * estimateGas call through RPC directly.
   *
   * @param transaction - The ethers TransactionRequest data in question.
   *
   * @returns A BigNumber representing the estimated gas value.
   */
  public async estimateGas(transaction: WriteTransaction): Promise<string> {
    const { gasLimitInflation } = this.config;

    return this.execute(false, async (provider: RpcProvider) => {
      const result = await provider.estimateGas(transaction);
      try {
        return BigNumber.from(result)
          .add(gasLimitInflation ? BigNumber.from(gasLimitInflation) : 0)
          .toString();
      } catch (error: unknown) {
        throw new GasEstimateInvalid(result.toString(), {
          error: (error as Error).message,
        });
      }
    });
  }

  /**
   * Get the current gas price for the chain for which this instance is servicing.
   *
   * @param context - RequestContext instance in which we are executing this method.
   * @param useInitialBoost (default: true) - boolean indicating whether to use the configured initial boost
   * percentage value.
   *
   * @returns The BigNumber value for the current gas price.
   */
  public async getGasPrice(context: RequestContext, useInitialBoost = true): Promise<string> {
    const { requestContext, methodContext } = createLoggingContext(this.getGasPrice.name, context);

    // Check if there is a hardcoded value specified for this chain. This should usually only be set
    // for testing/overriding purposes.
    const hardcoded = this.config.hardcodedGasPrice;
    if (hardcoded) {
      this.logger.info('Using hardcoded gas price for chain', requestContext, methodContext, {
        domain: this.domain,
        hardcoded,
      });
      return hardcoded;
    }

    // Check if there is a valid (non-expired) gas price available.
    if (this.cache.data.gasPrice) {
      return this.cache.data.gasPrice.toString();
    }

    const { gasPriceInitialBoostPercent, gasPriceMinimum, gasPriceMaximum, gasPriceMaxIncreaseScalar } = this.config;
    let gasPrice: BigNumber | undefined = undefined;

    // Use gas station APIs, if available.
    const gasStations = this.config.gasStations ?? [];
    for (let i = 0; i < gasStations.length; i++) {
      const uri = gasStations[i];
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let response: any;
      try {
        response = await axiosGet(uri);
        if (response && response.data) {
          const { fast } = response.data as unknown as { fast: BigNumberish };
          if (fast) {
            gasPrice = utils.parseUnits(fast.toString(), 'gwei');
            break;
          }
        }
        this.logger.debug('Gas station response did not have expected params', requestContext, methodContext, {
          uri,
          data: response.data,
        });
      } catch (e: unknown) {
        this.logger.debug('Gas station not responding correctly', requestContext, methodContext, {
          uri,
          res: response ? (response?.data ? response.data : response) : undefined,
          error: jsonifyError(e as EverclearError),
        });
      }
    }

    if (!gasPrice) {
      // If we did not have a gas station API to use, or the gas station failed, use the provider's getGasPrice method.
      gasPrice = BigNumber.from(
        await this.execute<string>(false, async (provider: RpcProvider) => {
          return await provider.getGasPrice();
        }),
      );
      if (useInitialBoost) {
        gasPrice = gasPrice.add(gasPrice.mul(gasPriceInitialBoostPercent).div(100));
      }
    }

    // Apply a curbing function (if applicable) - this will curb the effect of dramatic network gas spikes.
    let hitMaximum = false;
    if (
      gasPriceMaxIncreaseScalar !== undefined &&
      gasPriceMaxIncreaseScalar > 100 &&
      this.lastUsedGasPrice !== undefined
    ) {
      // If we have a configured cap scalar, and the gas price is greater than that cap, set it to the cap.
      const curbedPrice = this.lastUsedGasPrice.mul(gasPriceMaxIncreaseScalar).div(100);
      if (gasPrice.gt(curbedPrice)) {
        this.logger.debug('Hit the gas price curbed maximum.', requestContext, methodContext, {
          domain: this.domain,
          gasPrice: utils.formatUnits(gasPrice, 'gwei'),
          curbedPrice: utils.formatUnits(curbedPrice, 'gwei'),
          gasPriceMaxIncreaseScalar,
          lastUsedGasPrice: utils.formatUnits(this.lastUsedGasPrice, 'gwei'),
        });
        gasPrice = curbedPrice;
        hitMaximum = true;
      }
    }

    // Final step to ensure we remain within reasonable, configured bounds for gas price.
    // If the gas price is less than absolute gas minimum, bump it up to minimum.
    // If it's greater than (or equal to) the absolute maximum, set it to that maximum (and log).
    const min = BigNumber.from(gasPriceMinimum);
    const max = BigNumber.from(gasPriceMaximum);
    // TODO: Could use a more sustainable method of separating out gas price abs min for certain
    // chains (such as arbitrum or zksync here) in particular:
    if (gasPrice.lt(min) && ![1634886255, 1734439522, 2053862243, 2053862260].includes(this.domain)) {
      gasPrice = min;
    } else if (gasPrice.gte(max)) {
      this.logger.warn('Hit the gas price absolute maximum.', requestContext, methodContext, {
        domain: this.domain,
        gasPrice: utils.formatUnits(gasPrice, 'gwei'),
        absoluteMax: utils.formatUnits(max, 'gwei'),
      });
      gasPrice = max;
      hitMaximum = true;
    }

    // Update our last used gas price with this tx's gas price. This may be used to determine the cap of
    // subsuquent tx's gas price.
    this.lastUsedGasPrice = gasPrice;

    // We only want to cache the gas price if we didn't hit the maximum.
    if (!hitMaximum) {
      this.cache.set({ gasPrice });
    }

    return gasPrice.toString();
  }

  /**
   * Get the current balance for the specified address.
   *
   * @param address - The hexadecimal string address whose balance we are getting.
   * @param assetId - The ID (address) of the asset whose balance we are getting.
   *
   * @returns A BigNumber representing the current value held by the wallet at the
   * specified address.
   */
  public async getBalance(address: string, assetId: string): Promise<string> {
    return this.execute<string>(false, async (provider: RpcProvider) => {
      return await provider.getBalance(address, assetId);
    });
  }

  /**
   * Get the decimals for the ERC20 token contract.
   *
   * @param address The hexadecimal string address of the asset.
   *
   * @returns A number representing the current decimals.
   */
  public async getDecimalsForAsset(assetId: string): Promise<number> {
    return this.execute<number>(false, async (provider: RpcProvider) => {
      if (this.cachedDecimals[assetId]) {
        return this.cachedDecimals[assetId];
      }

      if (assetId === constants.AddressZero) {
        this.cachedDecimals[assetId] = 18;
        return 18;
      }

      // Get provider
      const decimals = await provider.getDecimals(assetId);
      this.cachedDecimals[assetId] = decimals;
      return decimals;
    });
  }

  /**
   * Gets the current block number.
   *
   * @returns A number representing the current block number.
   */
  public async getBlock(blockHashOrBlockTag: number | string) {
    return this.execute(false, async (provider) => {
      return await provider.getBlock(await blockHashOrBlockTag);
    });
  }

  /**
   * Gets the current blocktime.
   *
   * @param blockTag (default: "latest") - The block tag to get the blocktime for, could be a block number or a block hash.
   * By default, this will get the current blocktime.
   *
   * @returns A number representing the current blocktime.
   */
  public async getBlockTime(blockTag = 'latest'): Promise<number> {
    return this.execute<number>(false, async (provider: RpcProvider) => {
      const block = await provider.getBlock(blockTag);
      return block.timestamp;
    });
  }

  /**
   * Gets the current block number.
   *
   * @returns A number representing the current block number.
   */
  public async getBlockNumber(): Promise<number> {
    return this.execute<number>(false, async (provider: RpcProvider) => {
      return await provider.getBlockNumber();
    });
  }

  /**
   * Gets the signer's address.
   *
   * @returns A hash string address belonging to the signer.
   */
  public async getAddress(): Promise<string> {
    this.checkSigner();
    return await this.signer!.getAddress();
  }

  /**
   * Retrieves a transaction's receipt by the transaction hash.
   *
   * @param hash - the transaction hash to get the receipt for.
   *
   * @returns A TransactionReceipt instance.
   */
  public async getTransactionReceipt(hash: string) {
    return this.execute(false, async (provider: RpcProvider) => {
      const receipt = await provider.getTransactionReceipt(hash);
      return receipt;
    });
  }

  /**
   * Returns a hexcode string representation of the contract code at the given
   * address. If there is no contract deployed at the given address, returns "0x".
   *
   * @param address - contract address.
   *
   * @returns Hexcode string representation of contract code.
   */
  public async getCode(address: string): Promise<string> {
    return this.execute<string>(false, async (provider: RpcProvider) => {
      return await provider.getCode(address);
    });
  }

  /**
   * Checks estimate for gas limit for given transaction on given chain.
   *
   * @param tx - transaction to check gas limit for.
   *
   * @returns BigNumber representing the estimated gas limit in gas units.
   * @throws Error if the transaction is invalid, or would be reverted onchain.
   */
  public async getGasEstimate(tx: ReadTransaction | WriteTransaction): Promise<string> {
    return this.execute<string>(false, async (provider: RpcProvider) => {
      return await provider.estimateGas(tx);
    });
  }

  /**
   * Gets the current transaction count.
   *
   * @param blockTag (default: "latest") - The block tag to get the transaction count for. Use "latest" mined-only transactions.
   * Use "pending" for transactions that have not been mined yet, but will (supposedly) be mined in the pending
   * block (essentially, transactions included in the mempool, but this behavior is not consistent).
   *
   * @returns Number of transactions sent AKA the current nonce.
   */
  public async getTransactionCount(blockTag = 'latest'): Promise<number> {
    // TODO: Cache both latest and pending transaction counts separately?
    if (this.cache.data.transactionCount && blockTag === 'latest') {
      return this.cache.data.transactionCount;
    }

    return this.execute<number>(true, async (provider: RpcProvider) => {
      const transactionCount = await provider.getTransactionCount(await this.signer!.getAddress(), blockTag);
      this.cache.set({ transactionCount });
      return transactionCount;
    });
  }

  /// HELPERS
  /**
   * A helper to throw a custom error if the method requires a signer but no signer has
   * been injected into the provider.
   *
   * @throws EverclearError if signer is required and not provided.
   */
  private checkSigner() {
    if (!this.signer) {
      throw new MissingSigner();
    }
  }

  /**
   * The RPC method execute wrapper is used for wrapping and parsing errors, as well as ensuring that
   * providers are ready before any call is made. Also used for executing multiple retries for RPC
   * requests to providers. This is to circumvent any issues related to unreliable internet/network
   * issues, whether locally, or externally (for the provider's network).
   *
   * @param method - The method callback to execute and wrap in retries.
   * @returns The object of the specified generic type.
   * @throws EverclearError if the method fails to execute.
   */
  private async execute<T>(needsSigner: boolean, method: (provider: RpcProvider) => Promise<T>): Promise<T> {
    // If we need a signer, check to ensure we have one.
    if (needsSigner) {
      this.checkSigner();
    }

    const errors: EverclearError[] = [];
    const handleError = (e: unknown) => {
      // TODO: With the addition of RpcProvider, this parse call may be entirely redundant. Won't add any compute,
      // however, as it will return instantly if the error is already a EverclearError.
      const error = parseError(e);
      if (error.type === ServerError.type || error.type === RpcError.type || error.type === StallTimeout.type) {
        // If the method threw a StallTimeout, RpcError, or ServerError, that indicates a problem with the provider and not
        // the call - so we'll retry the call with a different provider (if available).
        errors.push(error);
      } else {
        // e.g. a TransactionReverted, TransactionReplaced, etc.
        throw error;
      }
    };

    const quorum = this.config.quorum ?? 1;
    if (quorum > 1) {
      // Consult ALL providers.
      const results: (T | undefined)[] = await Promise.all(
        this.providers.map(async (provider) => {
          try {
            return await method(provider);
          } catch (e: unknown) {
            handleError(e);
            return undefined;
          }
        }),
      );
      // Filter out undefined results.
      // NOTE: If there aren't any defined results, we'll proceed out of this code block and throw the
      // RpcError at the end of this method.
      const filteredResults: T[] = results.filter((item) => item !== undefined) as T[];
      if (filteredResults.length > 0) {
        // Pick the most common answer.
        let counts: Map<string, number> = new Map();
        counts = filteredResults.reduce((counts, item) => {
          // Stringify the key. We'll convert it back before returning.
          const key = JSON.stringify(item);
          counts.set(key, (counts.get(key) ?? 0) + 1);
          return counts;
        }, counts);
        const maxCount = Math.max(...Array.from(counts.values()));
        if (maxCount < quorum) {
          // Quorum is not met: we should toss this response as it could be unreliable.
          throw new QuorumNotMet(maxCount, quorum, {
            errors,
            providersCount: this.providers.length,
            responsesCount: filteredResults.length,
          });
        }
        // Technically it could be multiple top responses...
        const topResponses = Array.from(counts.keys()).filter((k) => counts.get(k)! === maxCount);
        if (topResponses.length > 0) {
          // Did we get multiple conflicting top responses? Worth logging.
          this.logger.info(
            'Received conflicting top responses from RPC providers.',
            createRequestContext(this.execute.name),
            undefined,
            {
              topResponses,
              providersCount: this.providers.length,
              responsesCount: filteredResults.length,
              requiredQuorum: quorum,
            },
          );
        }
        // We've been using string keys and need to convert back to the OG item type T.
        const stringifiedTopResponse = topResponses[0];
        for (const item of filteredResults) {
          if (JSON.stringify(item) === stringifiedTopResponse) {
            return item;
          }
        }
      }
    } else {
      // Shuffle the providers (with weighting towards better ones) and pick from the top.
      const shuffledProviders = this.shuffleSyncedProviders();
      for (const provider of shuffledProviders) {
        try {
          return await method(provider);
        } catch (e: unknown) {
          handleError(e);
        }
      }
    }

    throw new RpcError(RpcError.reasons.FailedToSend, { errors });
  }

  /**
   * Callback method used for handling a block update from synchronized providers.
   *
   * @remarks
   * Since being "in-sync" is actually a relative matter, it's possible to have all providers
   * be out of sync (e.g. 100 blocks behind the current block in reality), but also have them
   * be considered in-sync here, since we only use the highest block among our providers to determine
   * the "true" current block.
   *
   *
   * @param provider - RpcProvider instance this block update applies to.
   * @param blockNumber - Current block number (according to the provider).
   * @param url - URL of the provider.
   * @returns boolean indicating whether the provider is in sync.
   */
  protected async syncProviders(): Promise<void> {
    const { requestContext, methodContext } = createLoggingContext(this.syncProviders.name);

    // Reset the current lead provider.
    this.leadProvider = undefined;

    // First, sync all providers simultaneously.
    await Promise.all(
      this.providers.map(async (p) => {
        try {
          await p.sync();
        } catch (e: unknown) {
          this.logger.debug("Couldn't sync provider.", requestContext, methodContext, {
            error: jsonifyError(e as Error),
            provider: p.name,
          });
        }
      }),
    );

    // Find the provider with the highest block number and use that as source of truth.
    const highestBlockNumber = Math.max(...this.providers.map((p) => p.syncedBlockNumber));
    for (const provider of this.providers) {
      const providerBlockNumber = provider.syncedBlockNumber;
      provider.lag = highestBlockNumber - providerBlockNumber;

      // Set synced property, log if the provider went out of sync.
      const synced = provider.lag < PROVIDER_MAX_LAG;
      if (!synced && provider.synced) {
        // If the provider was previously synced but fell out of sync, debug log to notify.
        this.logger.debug('Provider fell out of sync.', undefined, undefined, {
          providerBlockNumber,
          provider: provider.name,
          lag: provider.lag,
        });
      }
      provider.synced = synced;
    }

    // We want to pick the lead provider here at random from the list of 0-lag providers to ensure that we distribute
    // our block listener RPC calls as evenly as possible across all providers.
    const leadProviders = this.shuffleSyncedProviders();
    this.leadProvider = leadProviders[0];

    this.logger.debug('Synced provider(s).', requestContext, methodContext, {
      highestBlockNumber,
      leadProvider: this.leadProvider.name,
      providers: this.providers.map((p) => ({
        url: p.name,
        blockNumber: p.syncedBlockNumber,
        lag: p.lag,
        synced: p.synced,
        metrics: {
          reliability: p.reliability,
          latency: p.latency,
          cps: p.cps,
          priority: p.priority,
        },
      })),
    });
  }

  /**
   * Helper method to stall, possibly until we've surpassed a specified number of blocks. Only works
   * with block number if we're running in synchronized mode.
   *
   * @param numBlocks (default: 1) - the number of blocks to wait.
   */
  private async wait(numBlocks = 1): Promise<void> {
    const pollPeriod = numBlocks * (this.blockPeriod ?? 2_000);
    await delay(pollPeriod);
  }

  /**
   * Helper method for getting tier-shuffled synced providers.
   *
   * @returns all in-sync providers in order of synchronicity with chain, with the lead provider
   * in the first position and the rest shuffled by tier (lag).
   */
  private shuffleSyncedProviders(): RpcProvider[] {
    // TODO: Should priority be a getter, and calculated internally?
    // Tiered shuffling: providers that have the same lag value (e.g. 0) will be shuffled so as to distribute RPC calls
    // as evenly as possible across all providers; at high load, this can translate to higher efficiency (each time we
    // execute an RPC call, we'll be hitting different providers).
    // Shuffle isn't applied to lead provider - instead, we just guarantee that it's in the first position.
    this.providers.forEach((p) => {
      p.priority =
        p.lag -
        (this.leadProvider && p.name === this.leadProvider.name ? 1 : Math.random()) -
        p.cps / this.config.maxProviderCPS -
        // Reliability factor reflects how often RPC errors are encountered, as well as timeouts.
        p.reliability * 10 +
        p.latency;
    });
    // Always start with the in-sync providers and then concat the out of sync subgraphs.
    return this.providers
      .filter((p) => p.synced)
      .sort((a, b) => a.priority - b.priority)
      .concat(this.providers.filter((p) => !p.synced).sort((a, b) => a.priority - b.priority));
  }

  private async setBlockPeriod(): Promise<void> {
    try {
      const currentBlock = await this.getBlock('latest');
      const previousBlock = await this.getBlock(currentBlock.parentHash);
      this.blockPeriod = currentBlock.timestamp - previousBlock.timestamp;
    } catch (error: unknown) {
      // If we can't get the block period, we'll just use a default value.
      this.logger.warn('Could not get block period time, using default.', undefined, undefined, {
        domain: this.domain,
        error,
        default: DEFAULT_BLOCK_PERIOD,
      });
    }
  }
}
