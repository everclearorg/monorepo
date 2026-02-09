import {
  createLoggingContext,
  delay,
  jsonifyError,
  Logger,
  EverclearError,
  RequestContext,
  domainToChainId,
} from '@chimera-monorepo/utils';
import { chainWrapper } from '@chimera-monorepo/utils';

import { validateProviderConfig, ChainConfig } from './config';
import {
  ConfigurationError,
  GasEstimateInvalid,
  OperationTimeout,
  TransactionReadError,
  TransactionReverted,
  ReadTransaction,
  OnchainTransaction,
  WriteTransaction,
  RpcProvider,
  getRpcClient,
  ISigner,
  ITransactionReceipt,
  MissingSigner,
  ITransactionRequest,
  getVmFromDomainId,
  SupportedVms,
} from './shared';
import { axiosGet } from './mockable';

// Default value for block period time (in ms) if we're unable to attain that info from the providers for some reason.
const DEFAULT_BLOCK_PERIOD = 2_000;

/**
 * @classdesc An aggregator for RPC calls on a specified chain. Uses a single viem public client
 * with multiple provider URLs for RPC rotation. Primarily serves as an RPC method execute wrapper.
 */
export class RpcProviderAggregator {
  // Single RPC provider with multiple URLs (handled by viem fallback transport)
  private readonly provider: RpcProvider;

  private signer?: ISigner;

  private lastUsedGasPrice: bigint | undefined = undefined;

  // Cached decimal values per asset. Saved separately as decimals don't expire.
  private cachedDecimals: Record<string, number> = {};
  // Cached block length in time (ms), used for optimizing waiting periods.
  private blockPeriod: number = DEFAULT_BLOCK_PERIOD;

  /**
   * A class for managing RPC calls on a specified chain. Uses a single viem public client
   * with multiple provider URLs for RPC rotation.
   *
   * @param logger - Logger used for logging.
   * @param domain - The ID of the chain for which this class's provider will be servicing.
   * @param config - Configuration for this specified chain, including the providers we'll
   * be using for it.
   *
   * @throws ChainError.reasons.ProviderNotFound if no valid providers are found in the
   * configuration.
   */
  constructor(
    protected readonly logger: Logger,
    public readonly domain: number,
    protected readonly config: ChainConfig,
  ) {
    const { requestContext, methodContext } = createLoggingContext('RpcProviderAggregator.constructor');

    // Collect all URLs from provider configs
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

    if (filteredConfigs.length === 0) {
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

    // Collect all URLs from all provider configs
    const urls = filteredConfigs.map((config) => config.url);

    // Create a single provider with all URLs (viem will handle RPC rotation via fallback transport)
    this.provider = getRpcClient(this.domain, urls);

    // Set up the initial value for block period. Will run asynchronously, and update the value (from the default) when
    // it completes.
    this.setBlockPeriod();
  }

  public async setSigner(signer: ISigner | string) {
    // Use chain-specific private key if available, otherwise use the global signer
    if (this.config.privateKey) {
      this.signer = await this.provider.getSigner(this.config.privateKey);
    } else if (signer) {
      this.signer = await this.provider.getSigner(signer);
    } else {
      this.signer = undefined;
    }
  }

  /**
   * Send the transaction request to the provider.
   *
   * @remarks This method is set to access protected since it should really only be used by the inheriting class,
   * TransactionDispatch, as of the time of writing this.
   *
   * @param transaction The transaction used for the request.
   *
   * @returns The TransactionResponse.
   */
  public async sendTransaction(transaction: OnchainTransaction) {
    console.log(`=== sendTransaction called with domain ${this.domain} ===`);
    this.checkSigner();

    const toSend = {
      ...transaction.params,
      gasLimit: transaction.params.gasLimit ? BigInt(transaction.params.gasLimit) : undefined,
      gasPrice: transaction.params.gasPrice ? BigInt(transaction.params.gasPrice) : undefined,
      value: BigInt(transaction.params.value || 0),
    } as unknown as ITransactionRequest;

    // Add chainId for EVM chains to ensure EIP-155 compliance (replay protection)
    if (getVmFromDomainId(this.domain) === SupportedVms.evm) {
      toSend.chainId = domainToChainId(this.domain);
    }

    const provider = await this.provider.connect(this.signer!);
    return provider.sendTransaction(toSend);
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
   * @returns The ITransactionReceipt, if mined, otherwise null.
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
      ) as ITransactionReceipt[];

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
          // Check if all errors are TransactionReceiptNotFoundError - if so, verify the transaction exists
          // before throwing. The transaction might be confirmed, but the RPC hasn't indexed it yet.
          const allReceiptNotFoundErrors = errors.every(
            (error: any) => error.name === 'TransactionReceiptNotFoundError' || error.shortMessage?.includes('could not be found'),
          );
          if (allReceiptNotFoundErrors && transaction.responses.length > 0) {
            // Check if the transaction exists on-chain using getTransaction
            try {
              const txResponses = await this.getTransaction(transaction);
              const txExists = txResponses.some((tx) => tx !== null && tx !== undefined);
              if (txExists) {
                // Transaction exists but receipt not available yet - continue waiting
                // Don't throw, just continue the loop
              } else {
                // Transaction doesn't exist - throw the error
                throw errors[0];
              }
            } catch {
              // If getTransaction fails, throw the original error
              throw errors[0];
            }
          } else {
            throw errors[0];
          }
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
    try {
      return await this.provider.call(tx, blockTag);
    } catch (error: unknown) {
      throw new TransactionReadError(TransactionReadError.reasons.ContractReadError, { error });
    }
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
      const transaction = await this.provider.getTransaction(tx);
      return [transaction];
    }
    const errors: EverclearError[] = [];
    const txs = await Promise.all(
      tx.responses.map(async (response) => {
        try {
          return await this.provider.getTransaction(response.hash);
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
   * @param transaction - The transaction data in question.
   *
   * @returns A BigNumber representing the estimated gas value.
   */
  public async estimateGas(transaction: WriteTransaction): Promise<string> {
    const { gasLimitInflation } = this.config;

    const result = await this.provider.estimateGas(transaction);
    try {
      return (BigInt(result) + (gasLimitInflation ? BigInt(gasLimitInflation) : BigInt(0))).toString();
    } catch (error: unknown) {
      throw new GasEstimateInvalid(result.toString(), {
        error: (error as Error).message,
      });
    }
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

    const { gasPriceInitialBoostPercent, gasPriceMinimum, gasPriceMaximum, gasPriceMaxIncreaseScalar } = this.config;
    let gasPrice: bigint | undefined = undefined;

    // Use gas station APIs, if available.
    const gasStations = this.config.gasStations ?? [];
    for (let i = 0; i < gasStations.length; i++) {
      const uri = gasStations[i];
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let response: any;
      try {
        response = await axiosGet(uri);
        if (response && response.data) {
          const { fast } = response.data as unknown as { fast: string | number };
          if (fast) {
            gasPrice = chainWrapper.parseGwei(fast.toString());
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
      gasPrice = BigInt(await this.provider.getGasPrice());
      if (useInitialBoost) {
        gasPrice = gasPrice + (gasPrice * BigInt(gasPriceInitialBoostPercent)) / BigInt(100);
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
      const curbedPrice = (this.lastUsedGasPrice * BigInt(gasPriceMaxIncreaseScalar)) / BigInt(100);
      if (gasPrice > curbedPrice) {
        this.logger.debug('Hit the gas price curbed maximum.', requestContext, methodContext, {
          domain: this.domain,
          gasPrice: chainWrapper.formatGwei(gasPrice),
          curbedPrice: chainWrapper.formatGwei(curbedPrice),
          gasPriceMaxIncreaseScalar,
          lastUsedGasPrice: chainWrapper.formatGwei(this.lastUsedGasPrice),
        });
        gasPrice = curbedPrice;
        hitMaximum = true;
      }
    }

    // Final step to ensure we remain within reasonable, configured bounds for gas price.
    // If the gas price is less than absolute gas minimum, bump it up to minimum.
    // If it's greater than (or equal to) the absolute maximum, set it to that maximum (and log).
    const min = BigInt(gasPriceMinimum);
    const max = BigInt(gasPriceMaximum);
    // TODO: Could use a more sustainable method of separating out gas price abs min for certain
    // chains (such as arbitrum or zksync here) in particular:
    if (gasPrice < min && ![1634886255, 1734439522, 2053862243, 2053862260, 728126428].includes(this.domain)) {
      gasPrice = min;
    } else if (gasPrice >= max) {
      this.logger.warn('Hit the gas price absolute maximum.', requestContext, methodContext, {
        domain: this.domain,
        gasPrice: chainWrapper.formatGwei(gasPrice),
        absoluteMax: chainWrapper.formatGwei(max),
      });
      gasPrice = max;
      hitMaximum = true;
    }

    // Update our last used gas price with this tx's gas price. This may be used to determine the cap of
    // subsuquent tx's gas price.
    this.lastUsedGasPrice = gasPrice;

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
    return await this.provider.getBalance(address, assetId);
  }

  /**
   * Get the decimals for the ERC20 token contract.
   *
   * @param address The hexadecimal string address of the asset.
   *
   * @returns A number representing the current decimals.
   */
  public async getDecimalsForAsset(assetId: string): Promise<number> {
    if (this.cachedDecimals[assetId]) {
      return this.cachedDecimals[assetId];
    }

    if (assetId === chainWrapper.zeroAddress) {
      this.cachedDecimals[assetId] = 18;
      return 18;
    }

    const decimals = await this.provider.getDecimals(assetId);
    this.cachedDecimals[assetId] = decimals;
    return decimals;
  }

  /**
   * Gets the current block number.
   *
   * @returns A number representing the current block number.
   */
  public async getBlock(blockHashOrBlockTag: number | string) {
    return await this.provider.getBlock(blockHashOrBlockTag);
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
    const block = await this.provider.getBlock(blockTag);
    return block.timestamp;
  }

  /**
   * Gets the current block number.
   *
   * @returns A number representing the current block number.
   */
  public async getBlockNumber(): Promise<number> {
    return await this.provider.getBlockNumber();
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
    return await this.provider.getTransactionReceipt(hash);
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
    return await this.provider.getCode(address);
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
    return await this.provider.estimateGas(tx);
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
    this.checkSigner();
    return await this.provider.getTransactionCount(await this.signer!.getAddress(), blockTag);
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
   * Helper method to stall, possibly until we've surpassed a specified number of blocks.
   *
   * @param numBlocks (default: 1) - the number of blocks to wait.
   */
  private async wait(numBlocks = 1): Promise<void> {
    const pollPeriod = numBlocks * (this.blockPeriod ?? 2_000);
    await delay(pollPeriod);
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
