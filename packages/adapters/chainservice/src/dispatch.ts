import PriorityQueue from 'p-queue';
import {
  createLoggingContext,
  delay,
  getUuid,
  jsonifyError,
  Logger,
  EverclearError,
  RequestContext,
} from '@chimera-monorepo/utils';
import { chainWrapper } from '@chimera-monorepo/utils';
import interval from 'interval-promise';

import {
  BadNonce,
  TransactionReplaced,
  TransactionReverted,
  OperationTimeout,
  TransactionBackfilled,
  InitialSubmitFailure,
  TransactionProcessingError,
  NotEnoughConfirmations,
  TransactionAlreadyKnown,
  Gas,
  WriteTransaction,
  OnchainTransaction,
  TransactionBuffer,
  ITransactionReceipt,
  ISigner,
  getVmFromDomainId,
} from './shared';
import { ChainConfig } from './config';
import { RpcProviderAggregator } from './aggregator';

// TODO: Merge responsibility with ChainService.
/**
 * @classdesc Transaction lifecycle manager.
 */
export class TransactionDispatch {
  private loopsRunning = false;

  // Based on default per account rate limiting on geth.
  // TODO: Make this a configurable value, since the dev may be able to implement or may be using a custom geth node.
  static MAX_INFLIGHT_TRANSACTIONS = 64;
  // Maximum number of mine/resubmit attempts before giving up on a transaction.
  static MAX_MINE_ATTEMPTS = 10;
  // A 10-minute timeout to prevent indefinite blocking when sending fails.
  static SEND_TIMEOUT = 10 * 60 * 1_000;
  // Buffer of in-flight transactions waiting to get 1 confirmation.
  private inflightBuffer: TransactionBuffer;

  // TODO: Cap this buffer as well. # of inflight txs max * # of confirmations needed seems reasonable as a max # of waiting-for-x-confirmations queue length
  // Buffer of mined transactions waiting for X confirmations.
  private minedBuffer: TransactionBuffer;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private readonly queue = new PriorityQueue({ concurrency: 1 });

  // The current nonce of the signer is tracked locally here. It will be used for comparison
  // to the nonce we get back from the pending transaction count call to our providers.
  // NOTE: Should not be accessed outside of the helper methods, getNonce and incrementNonce.
  private nonce = 0;
  private lastReceivedTxCount = -1;

  /**
   * Transaction lifecycle management class. Delegates RPC operations
   * to RpcProviderAggregator while managing the transaction lifecycle.
   *
   * @param logger Logger used for logging.
   * @param domain The ID of the chain for which this class's providers will be servicing.
   * @param config Configuration for this specified chain, including the providers we'll
   * be using for it.
   * @param rpcProvider A provider for RPC operations.
   * @param startLoops Whether to start background loops immediately.
   *
   * @throws ChainError.reasons.ProviderNotFound if no valid providers are found in the
   * configuration.
   */
  constructor(
    private readonly logger: Logger,
    public readonly domain: number,
    private readonly config: ChainConfig,
    private readonly rpcProvider: RpcProviderAggregator,
    startLoops = true,
  ) {
    this.inflightBuffer = new TransactionBuffer(logger, TransactionDispatch.MAX_INFLIGHT_TRANSACTIONS, {
      name: 'INFLIGHT',
      domain: this.domain,
    });
    this.minedBuffer = new TransactionBuffer(logger, undefined, {
      name: 'MINED',
      domain: this.domain,
    });
    if (startLoops) {
      this.startLoops();
    }
  }

  /**
   * Start background loops for mining and confirming transactions.
   */
  private startLoops() {
    if (!this.loopsRunning) {
      this.loopsRunning = true;
      // Use interval promise to make sure loop iterations don't overlap.
      interval(async () => await this.mineLoop(), 2_000);
      interval(async () => await this.confirmLoop(), 2_000);
    }
  }

  /**
   * Check for mined transactions in the inflight buffer; if any are present it will wait for 1 confirmation
   * and then push the transaction to the mined buffer for each one in FIFO order.
   */
  private async mineLoop() {
    const { requestContext, methodContext } = createLoggingContext(this.mineLoop.name);
    let transaction: OnchainTransaction | undefined = undefined;
    try {
      while (this.inflightBuffer.length > 0) {
        // Shift the first transaction from the buffer and get it mined.
        transaction = this.inflightBuffer.shift();
        if (!transaction) {
          // This shouldn't happen, but this block is a necessity for compilation.
          return;
        }
        const meta = {
          shouldResubmit: false,
          shouldBump: false,
        };
        let mineAttempts = 0;
        while (!transaction.didMine && !transaction.error) {
          mineAttempts++;
          if (mineAttempts > TransactionDispatch.MAX_MINE_ATTEMPTS) {
            transaction.error = new OperationTimeout({
              message: `Transaction exceeded maximum mine attempts (${TransactionDispatch.MAX_MINE_ATTEMPTS})`,
              domain: this.domain,
              nonce: transaction.nonce,
            });
            break;
          }
          try {
            if (meta.shouldResubmit) {
              if (meta.shouldBump) {
                await this.bump(transaction);
              }
              await this.submit(transaction);
            }
            await this.mine(transaction);
            this.minedBuffer.push(transaction);
            break;
          } catch (_error: unknown) {
            const error = _error as EverclearError & { name?: string; shortMessage?: string; reason?: string };
            this.logger.debug('Received error waiting for transaction to be mined.', requestContext, methodContext, {
              domain: this.domain,
              txsId: transaction.uuid,
              error,
            });

            // Check if this is a TransactionReceiptNotFoundError (from viem) - handle it similarly to OperationTimeout
            const isReceiptNotFoundError =
              (error as any).name === 'TransactionReceiptNotFoundError' ||
              (error as any).shortMessage?.includes('could not be found');

            if (error.type === OperationTimeout.type || error.type === BadNonce.type || isReceiptNotFoundError) {
              // Check to see if the transaction did indeed make it to chain.
              const responses = await this.rpcProvider.getTransaction(transaction);
              if (responses.every((response) => response === null)) {
                // If all responses are null, then this transaction was not found / does not exist.
                this.logger.warn('Transaction was not found on chain!', requestContext, methodContext, {
                  domain: this.domain,
                  transaction: transaction.loggable,
                  responses,
                });

                // Check to see if this nonce has already been mined.
                const transactionCount = await this.rpcProvider.getTransactionCount('latest');
                if (transactionCount > transaction.nonce) {
                  // Transaction must have been replaced by another.
                  transaction.error = new TransactionBackfilled({
                    latestTransactionCount: transactionCount,
                    nonce: transaction.nonce,
                  });
                } else {
                  // This transaction does not exist, and this nonce is still the blockade. We should
                  // resubmit immediately using the same nonce without bumping.
                  meta.shouldResubmit = true;
                  meta.shouldBump = false;
                }
              } else {
                // Transaction was found on chain.
                const response = responses.find((response) => response !== null);
                if (response?.confirmations && response?.confirmations > 0) {
                  // Transaction was mined! We should immediately continue to the next loop without
                  // resubmitting and let the mine function get the receipt.
                  meta.shouldResubmit = false;
                  meta.shouldBump = false;
                  continue;
                }
                // For TransactionReceiptNotFoundError, if the transaction exists, continue waiting
                // as the receipt might just not be indexed yet by the RPC provider.
                if (isReceiptNotFoundError) {
                  meta.shouldResubmit = false;
                  meta.shouldBump = false;
                  continue;
                }
                // Transaction was found, but it's not going through. We should bump the gas and submit
                // a replacement to speed things up.
                meta.shouldResubmit = true;
                meta.shouldBump = true;
              }
            } else if (
              error.type === TransactionReverted.type &&
              (error as TransactionReverted).reason === TransactionReverted.reasons.InsufficientFunds
            ) {
              /**
               * If we get an insufficient funds error during a resubmit, we should log this critical
               * alert but continue to try to mine whatever txs we've sent so far, on the basis that
               * the EOA owner will eventually refill the account (and we'll eventually) be able to
               * bump.
               *
               * Set shouldResubmit to false; next time around it will only attempt to mine. Should the
               * mine timeout again, it will go back to attempting to resubmit - allowing us to a chance
               * to respond to a refill for the gas money for this signer.
               */
              this.logger.error(
                'SIGNER HAS INSUFFICIENT FUNDS TO SUBMIT TRANSACTION (FOR GAS BUMP).',
                requestContext,
                methodContext,
                jsonifyError(error),
                {
                  domain: this.domain,
                  transaction: transaction.loggable,
                },
              );
              meta.shouldResubmit = false;
              meta.shouldBump = false;
            } else {
              transaction.error = error;
            }
          }
        }
        // If any errors occurred, fail that transaction and move on.
        if (transaction.error) {
          await this.fail(transaction);
        }
      }
    } catch (error: unknown) {
      this.logger.error('Error in mine loop.', requestContext, methodContext, jsonifyError(error as EverclearError), {
        handlingTransaction: transaction ? transaction.loggable : undefined,
      });
    }
  }

  /**
   * Check for mined transactions in the mined buffer; if any are present it will wait for the target confirmations for each
   * one in FIFO order.
   */
  private async confirmLoop() {
    const { requestContext, methodContext } = createLoggingContext(this.confirmLoop.name);
    const promises: Promise<void>[] = [];
    while (this.minedBuffer.length > 0) {
      const transaction = this.minedBuffer.shift()!;
      promises.push(
        new Promise<void>((resolve) => {
          // Checks to make sure we hit the target number of confirmations.
          this.confirm(transaction)
            .then(() => resolve())
            .catch((error) => {
              this.logger.debug(
                'Received error waiting for transaction to be confirmed:',
                requestContext,
                methodContext,
                {
                  domain: this.domain,
                  txsId: transaction.uuid,
                  error,
                },
              );
              transaction.error = error;
              this.fail(transaction).then(() => resolve());
            });
        }),
      );
    }
    await Promise.all(promises);
  }

  /**
   * Determine the nonce assignment for a transaction based on the current state, as well as what nonces have already
   * been attempted, etc.
   * @remarks
   * This should only ever be called within the queue in the send() method.
   *
   * @param attemptedNonces - Array of nonces that have already been attempted, in order of attempt.
   * @param error - (optional) The last error that was thrown when attempting to send an initial transaction.
   * @param previousNonce - (optional) The previous nonce assigned. Should only be defined if the error argument is also
   * passed in.
   * @returns object - containing nonce, backfill, and transactionCount.
   */
  private async determineNonce(
    attemptedNonces: number[],
    error?: BadNonce,
  ): Promise<{ nonce: number; backfill: boolean; transactionCount: number }> {
    const transactionCount = await this.rpcProvider.getTransactionCount('latest');

    // Set the nonce initially to the last used nonce. If no nonce has been used yet (i.e. this is the first initial send attempt),
    // set to whichever value is higher: local nonce or txcount. This should almost always be our local nonce, but often both will be the same.
    let nonce =
      attemptedNonces.length > 0 ? attemptedNonces[attemptedNonces.length - 1] : Math.max(this.nonce, transactionCount);
    // If backfill conditions are met, then we should instead set the nonce to the backfill value.
    const backfill = transactionCount < this.lastReceivedTxCount;
    if (backfill) {
      // If for some reason the transaction count we received from the provider is lower than the last once we received (meaning nonce
      // backtracked), we should start at the lower value instead. This will backfill any nonce gaps that may have been left behind
      // as a result of provider connection issues and/or reorgs.
      // NOTE: If this backfill replaces an "existing" faulty transaction (i.e. one that the provider doesn't actually have in mempool),
      // the push operation to the inflight buffer we do in the send method will handle replacing/killing the faulty transaction.
      nonce = transactionCount;
    } else if (error) {
      if (
        error.reason === BadNonce.reasons.NonceExpired ||
        // TODO: Should replacement underpriced result in us raising the gas price and attempting to override the transaction?
        // Or should we treat the nonce as expired?
        error.reason === BadNonce.reasons.ReplacementUnderpriced
      ) {
        // If we are here, likely one of following has occurred:
        // 1. Signer used outside of this class to send tx (should never happen).
        // 2. The EOA was rebooted, and our nonce has not yet caught up with that in the current pending pool of txs.
        // 3. We just performed a backfill operation, and are now catching back up to the *actual* nonce.
        if (!attemptedNonces.includes(transactionCount)) {
          // If we have not tried mined tx count, let's try that next.
          nonce = transactionCount;
        } else {
          // If we haven't tried the up-to-date tx count (latest or pending), let's try that next.
          const pendingTransactionCount = await this.rpcProvider.getTransactionCount('pending');
          if (!attemptedNonces.includes(pendingTransactionCount)) {
            nonce = pendingTransactionCount;
          } else {
            // If mined and pending tx count fail, we should just increment the nonce by 1 until we get a nonce we haven't tried.
            // This is sort of a spray-and-pray solution, but it's the best we can do when providers aren't giving us more reliable info.
            // Set the nonce to the lowest/min value in the array of attempted nonce first.
            nonce = Math.min(...attemptedNonces);
            while (attemptedNonces.includes(nonce)) {
              nonce++;
            }
          }
        }
      } else if (error.reason === BadNonce.reasons.NonceIncorrect) {
        // It's unknown whether nonce was too low or too high. For safety, we're going to set the nonce to the latest transaction count
        // and retry (continually). Eventually the transaction count will catch up to / converge on the correct number.
        // NOTE: This occasionally happens because a provider falls behind in terms of the current mempool and hasn't registered a tx yet.
        // Regardless of whether we've already attempted this nonce, we're going to try it again.
        nonce = transactionCount;
      }
    }

    // Set lastReceivedTxCount - this will be used in future calls of this method to determine if we need to backtrack nonce (i.e. backfill).
    this.lastReceivedTxCount = transactionCount;
    attemptedNonces.push(nonce);
    return { nonce, backfill, transactionCount };
  }

  /// LIFECYCLE
  /**
   *
   * @param minTx - Minimum transaction params needed to form a transaction.
   * @param context - Request context object used for logging.
   *
   * @returns A list of receipts or errors that occurred for each.
   */
  public async send(minTx: WriteTransaction, context: RequestContext): Promise<ITransactionReceipt> {
    console.log(`=== DISPATCH SEND called for domain ${this.domain} ===`);
    const method = this.send.name;
    const { requestContext, methodContext } = createLoggingContext(method, context);
    const txsId = getUuid();
    this.logger.debug('Method start', requestContext, methodContext, {
      domain: this.domain,
      txsId,
    });

    // get formatted transaction
    const result = await this.queue.add(
      async (): Promise<{ value: OnchainTransaction | EverclearError; success: boolean }> => {
        try {
          // Wait until there's room in the buffer.
          if (this.inflightBuffer.isFull) {
            this.logger.warn('Inflight buffer is full! Waiting in queue to send.', requestContext, methodContext, {
              domain: this.domain,
              bufferLength: this.inflightBuffer.length,
              txsId,
            });
            while (this.inflightBuffer.isFull) {
              // TODO: This delay was raised to help alleviate a "trickling bottleneck" when the inflight buffer remains full for
              // an extended period. An alternative: maybe we should wait until the buffer falls *below* a certain threshold?
              await delay(10_000);
            }
          }

          // TODO: Remove hardcoded (exposed gasLimitInflation config var should replace this).
          const gas: Gas = {
            limit: '0',
            price: '0',
          };
          let nonce = 0;
          let backfill = false;
          let transactionCount = 0;
          const attemptedNonces: number[] = [];

          if (getVmFromDomainId(this.domain) !== 'svm') {
            // Estimate gas here will throw if the transaction is going to revert on-chain for "legit" reasons. This means
            // that, if we get past this method, we can *generally* assume that the transaction will go through on submit - although it's
            // still possible to revert due to a state change below.
            const [gasLimit, gasPrice, nonceInfo] = await Promise.all([
              minTx.gasLimit ? Promise.resolve(minTx.gasLimit) : this.rpcProvider.estimateGas(minTx),
              minTx.gasPrice ? Promise.resolve(minTx.gasPrice) : this.rpcProvider.getGasPrice(requestContext),
              this.determineNonce(attemptedNonces),
            ]);
            gas.limit = gasLimit;
            gas.price = gasPrice;
            nonce = nonceInfo.nonce;
            backfill = nonceInfo.backfill;
            transactionCount = nonceInfo.transactionCount;
          }

          switch (this.domain) {
            // Arbitrum gasLimit hardcode
            case 42161:
            case 421614:
              gas.limit = '20000000';
              break;
            // ZkSync gasLimit hardcode
            case 300:
            case 324:
              gas.limit = '30000000';
              break;
          }

          // Here we are going to ensure our initial submit gets through at the correct nonce. If all goes well, it should
          // go through on the first try.
          let transaction: OnchainTransaction | undefined = undefined;
          let lastErrorReceived: Error | undefined = undefined;

          // It should never take more than MAX_INFLIGHT_TRANSACTIONS + 2 iterations to get the transaction through.
          let iterations = 0;
          while (
            iterations < TransactionDispatch.MAX_INFLIGHT_TRANSACTIONS + 2 &&
            (!transaction || !transaction.didSubmit)
          ) {
            iterations++;
            // Create a new transaction instance to track lifecycle. We will be submitting below.
            transaction = new OnchainTransaction(
              requestContext,
              minTx,
              nonce,
              gas,
              {
                confirmationTimeout: this.config.confirmationTimeout,
                confirmationsRequired: this.config.confirmations,
              },
              txsId,
            );
            this.logger.debug('Sending initial submit for transaction.', requestContext, methodContext, {
              domain: this.domain,
              iterations,
              lastErrorReceived,
              transaction: transaction.loggable,
              nonceInfo: {
                attemptedNonces,
                backfill: backfill ?? undefined,
                transactionCount,
                localNonce: this.nonce,
                assignedNonce: nonce,
              },
            });
            try {
              if (backfill) {
                const replaced = this.inflightBuffer.getTxByNonce(transaction.nonce);
                // Lets make sure we only replace/backfill a transaction that did not actually make it to chain.
                if (replaced) {
                  transaction.gas.price = replaced.gas.price;
                }
              }
              await this.submit(transaction);
            } catch (_error: unknown) {
              const error = _error as EverclearError & { reason: string };
              if (error.type === BadNonce.type) {
                lastErrorReceived = new Error(error.reason);
                ({ nonce, backfill, transactionCount } = await this.determineNonce(attemptedNonces, error));
                continue;
              } else if (error.type === TransactionAlreadyKnown.type) {
                // Ignore, indicates provider already has this tx indexed, meaning it was sent properly.
                break;
              }
              // This could be a reverted error, etc.
              throw error;
            }
          }
          if (!transaction || transaction.responses.length === 0) {
            throw new InitialSubmitFailure(
              'Transaction never submitted: exceeded maximum iterations in initial submit loop.',
            );
          }
          // Push submitted transaction to inflight buffer.
          this.inflightBuffer.push(transaction);
          // Increment the successful nonce, and assign our local nonce to that value.
          this.nonce = nonce + 1;
          return { value: transaction, success: true };
        } catch (error: unknown) {
          return { value: error as EverclearError, success: false };
        }
      },
    );

    if (!result?.success) {
      throw result?.value ?? new EverclearError('UnknownError', 'Unknown error occurred.');
    }

    const transaction = result.value as OnchainTransaction;
    // Wait for transaction to be picked up by the mine and confirm loops and closed out.
    const sendStart = Date.now();
    while (!transaction.didFinish && !transaction.error) {
      if (Date.now() - sendStart >= TransactionDispatch.SEND_TIMEOUT) {
        transaction.error = new OperationTimeout({
          message: 'Transaction send timed out waiting for mine/confirm loops to finish',
          domain: this.domain,
          nonce: transaction.nonce,
          timeout: TransactionDispatch.SEND_TIMEOUT,
        });
        break;
      }
      await delay(1_000);
    }

    if (transaction.error) {
      // If a transaction fails and it didn't get mined, we may need to backfill its nonce.
      if (!transaction.didMine) {
        this.logger.warn(
          "Transaction failed, and was never mined. Rewinding local nonce to this transaction's nonce for backfill.",
          requestContext,
          methodContext,
          {
            domain: this.domain,
            transaction: transaction.loggable,
            txsId,
          },
        );
        this.nonce = transaction.nonce;
      }
      throw transaction.error;
    }

    if (!transaction.receipt) {
      throw new TransactionProcessingError(TransactionProcessingError.reasons.NoReceipt, method);
    }

    return transaction.receipt;
  }

  /**
   * Submit an OnchainTransaction to the chain.
   *
   * @param transaction - OnchainTransaction object to modify based on submit result.
   */
  private async submit(transaction: OnchainTransaction) {
    console.log(`=== DISPATCH SUBMIT called for domain ${this.domain} ===`);
    const method = this.submit.name;
    const { requestContext, methodContext } = createLoggingContext(method, transaction.context);
    this.logger.debug('Method start', requestContext, methodContext, {
      domain: this.domain,
      txsId: transaction.uuid,
    });

    // Check to make sure we haven't already mined this transaction.
    if (transaction.didFinish) {
      throw new TransactionProcessingError(TransactionProcessingError.reasons.SubmitOutOfOrder, method);
    }

    // Increment transaction # attempts made.
    transaction.attempt++;

    // Send the tx.
    try {
      console.log(`=== DISPATCH SUBMIT about to call sendTransaction ===`);
      const response = await this.rpcProvider.sendTransaction(transaction);
      // Add this response to our local response history.
      if (transaction.hashes.includes(response.hash)) {
        // Duplicate response? This should never happen.
        throw new TransactionProcessingError(TransactionProcessingError.reasons.DuplicateHash, method, {
          domain: this.domain,
          response,
          transaction: transaction.loggable,
        });
      }
      transaction.responses.push(response);

      this.logger.info(`Tx submitted.`, requestContext, methodContext, {
        domain: this.domain,
        response: {
          hash: response.hash,
          nonce: response.nonce,
          gasPrice: response.gasPrice ? chainWrapper.formatGwei(BigInt(response.gasPrice)) : undefined,
          gasLimit: response.gasLimit.toString(),
        },
        transaction: transaction.loggable,
      });
    } catch (_error: unknown) {
      const error = _error as EverclearError;
      // If we end up with an error, it should be thrown here. But first, log loudly if we get an insufficient
      // funds error.
      if (
        error.type === TransactionReverted.type &&
        (error as TransactionReverted).reason === TransactionReverted.reasons.InsufficientFunds
      ) {
        this.logger.error(
          'SIGNER HAS INSUFFICIENT FUNDS TO SUBMIT TRANSACTION.',
          requestContext,
          methodContext,
          jsonifyError(error),
          {
            domain: this.domain,
            transaction: transaction.loggable,
          },
        );
      }
      throw error;
    }
  }

  /**
   * Wait for an OnchainTransaction to be mined (1 confirmation).
   *
   * @param transaction - OnchainTransaction object to modify based on mine result.
   */
  private async mine(transaction: OnchainTransaction) {
    const method = this.mine.name;
    const { requestContext, methodContext } = createLoggingContext(method, transaction.context);
    this.logger.debug('Method start', requestContext, methodContext, {
      domain: this.domain,
      txsId: transaction.uuid,
    });

    // Ensure we've submitted at least 1 tx.
    if (!transaction.didSubmit) {
      throw new TransactionProcessingError(TransactionProcessingError.reasons.MineOutOfOrder, method, {
        domain: this.domain,
        transaction: transaction.loggable,
      });
    }

    try {
      // Get receipt for tx with at least 1 confirmation. If it times out (using default, configured timeout),
      // it will throw a TransactionTimeout error.
      const receipt = await this.rpcProvider.confirmTransaction(transaction, 1);

      // Sanity checks.
      if (receipt.status === 0) {
        // This should never occur. We should always get a TransactionReverted error in this event.
        throw new TransactionProcessingError(TransactionProcessingError.reasons.DidNotThrowRevert, method, {
          domain: this.domain,
          receipt,
          transaction: transaction.loggable,
        });
      } else if (receipt.confirmations < 1) {
        // Again, should never occur.
        throw new TransactionProcessingError(TransactionProcessingError.reasons.InsufficientConfirmations, method, {
          domain: this.domain,
          receipt: transaction.receipt,
          confirmations: receipt.confirmations,
          transaction: transaction.loggable,
        });
      }

      // Set transaction's receipt.
      transaction.receipt = receipt as ITransactionReceipt;
    } catch (_error: unknown) {
      if ((_error as EverclearError).type === TransactionReplaced.type) {
        const error = _error as TransactionReplaced;
        this.logger.debug(
          'Received TransactionReplaced error - but this may be expected behavior.',
          requestContext,
          methodContext,
          {
            domain: this.domain,
            error,
            transaction: transaction.loggable,
          },
        );

        // Sanity check.
        if (!error.replacement || !error.receipt) {
          throw new TransactionProcessingError(TransactionProcessingError.reasons.ReplacedButNoReplacement, method, {
            domain: this.domain,
            replacement: error.replacement,
            receipt: error.receipt,
            transaction: transaction.loggable,
          });
        }

        // Validate that we've been replaced by THIS transaction (and not an unrecognized transaction).
        if (
          transaction.responses.length < 2 ||
          !transaction.responses.map((response) => response.hash).includes(error.replacement.hash)
        ) {
          throw error;
        }
        // error.receipt - the receipt of the replacement transaction (a TransactionReceipt)
        transaction.receipt = error.receipt as ITransactionReceipt;
      } else if ((_error as EverclearError).type === TransactionReverted.type) {
        const error = _error as TransactionReverted;
        // NOTE: This is the official receipt with status of 0, so it's safe to say the
        // transaction was in fact reverted and we should throw here.
        transaction.receipt = error.receipt as ITransactionReceipt;
        throw error;
      } else {
        throw _error;
      }
    }

    this.logger.info(`Tx mined.`, requestContext, methodContext, {
      domain: this.domain,
      receipt: {
        transactionHash: transaction.receipt.transactionHash,
        blockNumber: transaction.receipt.blockNumber,
      },
      transaction: transaction.loggable,
    });
  }

  /**
   * Makes an attempt to confirm this transaction, waiting up to a designated period to achieve
   * a desired number of confirmation blocks. If confirmation times out, throws TimeoutError.
   * If all txs, including replacements, are reverted, throws TransactionReverted.
   *
   * @param transaction - OnchainTransaction object to modify based on confirm result.
   */
  private async confirm(transaction: OnchainTransaction) {
    const method = this.confirm.name;
    const { requestContext, methodContext } = createLoggingContext(method, transaction.context);
    this.logger.debug('Method start', requestContext, methodContext, {
      domain: this.domain,
      txsId: transaction.uuid,
      hashes: transaction.hashes,
    });

    // Ensure we've submitted a tx.
    if (!transaction.didSubmit) {
      throw new TransactionProcessingError(TransactionProcessingError.reasons.MineOutOfOrder, method, {
        domain: this.domain,
        transaction: transaction.loggable,
      });
    }

    if (!transaction.receipt) {
      throw new TransactionProcessingError(TransactionProcessingError.reasons.ConfirmOutOfOrder, method, {
        domain: this.domain,
        receipt: transaction.receipt === undefined ? 'undefined' : transaction.receipt,
        transaction: transaction.loggable,
      });
    }

    // Here we wait for the target confirmations.
    // TODO: Ensure we are comfortable with how this timeout period is calculated.
    const timeout = this.config.confirmationTimeout * this.config.confirmations * 2;
    let receipt: ITransactionReceipt;
    try {
      receipt = await this.rpcProvider.confirmTransaction(transaction, this.config.confirmations, timeout);
    } catch (error: unknown) {
      this.logger.error(
        'Did not get enough confirmations for a *mined* transaction! Did a re-org occur?',
        requestContext,
        methodContext,
        jsonifyError(error as EverclearError),
        {
          domain: this.domain,
          transaction: transaction.loggable,
          confirmations: transaction.receipt.confirmations,
          confirmationsRequired: this.config.confirmations,
        },
      );
      // No other errors should normally occur during this confirmation attempt. This could occur during a reorg.
      throw new NotEnoughConfirmations(
        this.config.confirmations,
        transaction.receipt.transactionHash,
        transaction.receipt.confirmations,
        {
          method,
          domain: this.domain,
          receipt: transaction.receipt,
          error: transaction.error,
          transaction: transaction.loggable,
        },
      );
    }

    // Sanity checks.
    if (receipt.status === 0) {
      // This should never occur. We should always get a TransactionReverted error in this event : and that error should
      // have been thrown in the mine() method.
      throw new TransactionProcessingError(TransactionProcessingError.reasons.DidNotThrowRevert, method, {
        domain: this.domain,
        receipt,
        transaction: transaction.loggable,
      });
    }

    transaction.receipt = receipt as ITransactionReceipt;

    this.logger.info(`Tx confirmed.`, requestContext, methodContext, {
      domain: this.domain,
      receipt: {
        transactionHash: transaction.receipt?.transactionHash,
        confirmations: transaction.receipt?.confirmations,
        blockNumber: transaction.receipt?.blockNumber,
      },
      transactionExecutionTime: Date.now() - transaction.timestamp,
      transaction: transaction.loggable,
    });
  }

  /**
   * Bump the gas price for this tx up by the configured percentage.
   *
   * @param transaction - OnchainTransaction object to modify based on bump result.
   */
  public async bump(transaction: OnchainTransaction) {
    const { requestContext, methodContext } = createLoggingContext(this.bump.name, transaction.context);
    const currentGasPrice = (transaction.gas.price ?? transaction.gas.maxPriorityFeePerGas)!;
    if (
      transaction.bumps >= transaction.hashes.length ||
      BigInt(currentGasPrice) >= BigInt(this.config.gasPriceMaximum)
    ) {
      // If we've already bumped this tx but it's failed to resubmit, we should return here without bumping.
      // The number of gas bumps we've done should always be less than the number of txs we've submitted.
      this.logger.warn('Bump skipped.', requestContext, methodContext, {
        domain: this.domain,
        bumps: transaction.bumps,
        gasPrice: chainWrapper.formatGwei(BigInt(currentGasPrice)),
        gasMaximum: chainWrapper.formatGwei(BigInt(this.config.gasPriceMaximum)),
      });
      return;
    }
    transaction.bumps++;
    // TODO: EIP-1559 support.
    // Get the current gas baseline price, in case it has changed drastically in the last block.
    let updatedGasPrice: bigint;
    try {
      updatedGasPrice = BigInt(await this.rpcProvider.getGasPrice(requestContext, false));
    } catch {
      updatedGasPrice = BigInt(this.config.gasPriceMinimum);
    }
    const determinedBaseline = updatedGasPrice > BigInt(currentGasPrice) ? updatedGasPrice : BigInt(currentGasPrice);
    // Scale up gas by percentage as specified by config.
    if (transaction.type === 0) {
      transaction.gas.price = (
        determinedBaseline +
        (determinedBaseline * BigInt(this.config.gasPriceReplacementBumpPercent)) / BigInt(100) +
        BigInt(1)
      ).toString();
    } else {
      transaction.gas.maxPriorityFeePerGas = (
        determinedBaseline +
        (determinedBaseline * BigInt(this.config.gasPriceReplacementBumpPercent)) / BigInt(100) +
        BigInt(1)
      ).toString();
    }

    this.logger.info(`Tx bumped.`, requestContext, methodContext, {
      domain: this.domain,
      updatedGasPrice: chainWrapper.formatGwei(updatedGasPrice),
      previousGasPrice: chainWrapper.formatGwei(BigInt(currentGasPrice)),
      transaction: transaction.loggable,
    });
  }

  /**
   * Handles OnchainTransaction failure.
   *
   * @param transaction - OnchainTransaction object to read from and modify based on fail event.
   */
  private async fail(transaction: OnchainTransaction) {
    const { requestContext, methodContext } = createLoggingContext(this.fail.name, transaction.context);
    this.logger.error(
      'Tx failed.',
      requestContext,
      methodContext,
      jsonifyError(transaction.error ?? new Error('No transaction error was present.')),
      {
        domain: this.domain,
        transaction: transaction.loggable,
      },
    );
  }
}
