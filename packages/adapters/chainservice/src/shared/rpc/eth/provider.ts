import { EverclearError, delay, domainToChainId, parseHostname } from '@chimera-monorepo/utils';
import { constants, providers, utils, Wallet } from 'ethers';

import { parseError, RpcError, ServerError, StallTimeout } from '../../errors';
import { ISigner, ReadTransaction, WriteTransaction } from '../../types';
import { RpcProvider, SignerTypeMaps } from '..';
import { Interface } from 'ethers/lib/utils';

export const { StaticJsonRpcProvider } = providers;

// TODO: Wrap metrics in a type, and add a getter for it for logging purposes (after sync() calls, for example)
// TODO: Should be a multiton mapped by URL (such that no duplicate instances are created).
/**
 * @classdesc An extension of StaticJsonRpcProvider that manages a providers chain synchronization status
 * and intercepts all RPC send() calls to ensure that the provider is in sync.
 */
class BaseSyncProvider extends StaticJsonRpcProvider {
  private readonly connectionInfo: utils.ConnectionInfo;
  public readonly name: string;

  public synced = true;
  public lag = 0;
  public priority = 0;

  private static readonly N_SAMPLES = 100;
  // Denominator is the target reliability sample size.
  private static readonly RELIABILITY_STEP = 1 / BaseSyncProvider.N_SAMPLES;
  // A metric used for measuring reliability, based on the number of successful calls / last N calls made.
  public reliability = 1.0;

  // Used for tracking how many calls we've made in the last second.
  private cpsTimestamps: number[] = [];
  public get cps(): number {
    // Average CPS over the last 10 seconds.
    const now = Date.now();
    this.cpsTimestamps = this.cpsTimestamps.filter((ts) => now - ts < 10_000);
    return this.cpsTimestamps.length / 10;
  }
  private latencies: number[] = [];
  public get latency(): number {
    if (this.latencies.length === 0) {
      return 0.0;
    }
    // Average execution time over the last N samples.
    this.latencies = this.latencies.slice(-BaseSyncProvider.N_SAMPLES);
    return this.latencies.reduce((a, b) => a + b, 0) / this.latencies.length;
  }

  // This variable is used to track the last block number this provider synced to, and is kept separately from the
  // inherited `blockNumber` property (which is a getter that uses an update method).
  private _syncedBlockNumber = -1;
  public get syncedBlockNumber(): number {
    return this._syncedBlockNumber;
  }

  constructor(
    _connectionInfo: utils.ConnectionInfo | string,
    public readonly domain: number,
    private readonly stallTimeout = 10_000,
    private readonly debugLogging = false,
  ) {
    // NOTE: super (StaticJsonRpc) uses the hard-coded chainId when instantiated for all future
    // .getNetwork() requests, so it is important to use the chainId here, not the domain
    super(_connectionInfo, domainToChainId(domain));
    this.connectionInfo = typeof _connectionInfo === 'string' ? { url: _connectionInfo } : _connectionInfo;
    this.name = parseHostname(this.connectionInfo.url)
      ? parseHostname(this.connectionInfo.url)!.split('.').slice(0, -1).join('.')
      : this.connectionInfo.url;
  }

  /**
   * Synchronizes the provider with chain by checking the current block number and updating the syncedBlockNumber
   * property.
   */
  public async sync(): Promise<void> {
    const blockNumber = await this.getBlockNumber();
    this.debugLog('SYNCING_BLOCK_EVENT', blockNumber, this.syncedBlockNumber);
    this._syncedBlockNumber = blockNumber;
  }

  /**
   * Overridden RPC send method. If the provider is currently out of sync, this method will
   * now throw an RpcError indicating such. This way, we ensure an out of sync provider is never
   * consulted (except when checking the block number, which is used for syncing).
   *
   * @param method - RPC method name.
   * @param params - RPC method params.
   * @returns any - RPC response.
   * @throws RpcError - If the provider is currently out of sync.
   */
  public async send(method: string, params: Array<unknown>): Promise<unknown> {
    // provider.ready returns a Promise which will stall until the network has been established, ignoring
    // errors due to the target node not being active yet. This will ensure we wait until the node is up
    // and running smoothly.
    const ready = await this.ready;
    if (!ready) {
      throw new RpcError(RpcError.reasons.OutOfSync, {
        provider: this.name,
        domain: this.domain,
        lastSyncedBlockNumber: this.syncedBlockNumber,
        synced: this.synced,
        lag: this.lag,
        ready,
      });
    }

    // TODO: Make # of retries configurable?
    const errors: Error[] = [];
    let sendTimestamp = -1;
    for (let i = 1; i <= 5; i++) {
      try {
        sendTimestamp = Date.now();
        this.cpsTimestamps.push(sendTimestamp);
        return await Promise.race(
          [
            new Promise((resolve, reject) => {
              super
                .send(method, params)
                .then((res) => {
                  this.updateMetrics(true, sendTimestamp, i, method, params);
                  resolve(res);
                })
                .catch((e) => {
                  const error = parseError(e);
                  reject(error);
                });
            }),
          ].concat(
            this.stallTimeout
              ? [
                  // eslint-disable-next-line no-async-promise-executor
                  new Promise(async (_, reject) => {
                    await delay(this.stallTimeout);
                    reject(
                      new StallTimeout({
                        attempt: i,
                        provider: this.name,
                        domain: this.domain,
                        stallTimeout: this.stallTimeout,
                        errors,
                      }),
                    );
                  }),
                ]
              : [],
          ),
        );
      } catch (_error: unknown) {
        const error = _error as EverclearError;
        this.updateMetrics(false, sendTimestamp, i, method, params, {
          type: error.type.toString(),
          context: error.context,
        });
        if (error.type === RpcError.type) {
          // e.g. ConnectionReset, NetworkError, etc.
          // This type of error indicates we should retry the call attempt with this provider again.
          errors.push(error);
        } else {
          // e.g. a TransactionReverted, TransactionReplaced, etc.
          // NOTE: If this is a StallTimeout or ServerError, we should assume this provider is unresponsive
          // at the moment, and throw.
          throw error;
        }
      }
    }

    throw new RpcError(RpcError.reasons.FailedToSend, {
      provider: this.name,
      domain: this.domain,
      errors,
    });
  }

  private updateMetrics(
    success: boolean,
    sendTimestamp: number,
    iteration: number,
    method: string,
    params: unknown[],
    error?: { type: string; context: unknown },
  ) {
    const latency = +((Date.now() - sendTimestamp) / 1000).toFixed(2);
    this.latencies.push(latency);

    if (success) {
      this.reliability = Math.min(1, +(this.reliability + BaseSyncProvider.RELIABILITY_STEP).toFixed(2));
    } else if (error?.type === RpcError.type) {
      // If the error is an RPC Error, update reliability to reflect provider misbehavior.
      this.reliability = Math.max(0, +(this.reliability - BaseSyncProvider.RELIABILITY_STEP).toFixed(2));
    } else if (error?.type === StallTimeout.type || error?.type === ServerError.type) {
      // If the provider really is not responding in stallTimeout time (by default 10s!) or giving bad responses,
      //  we should assume it is unresponsive in general and severely penalize reliability score as a result.
      this.reliability = 0;
    }

    this.debugLog(
      success ? 'RPC_CALL' : 'RPC_ERROR',
      `#${iteration}`,
      method,
      this.cps,
      latency,
      this.reliability,
      // TODO: Logging params for these methods is for debugging purposes only.
      ['eth_getBlockByNumber', 'eth_getTransactionByHash', 'eth_getTransactionReceipt'].includes(method)
        ? params.length > 0
          ? params[0]
          : params
        : '',
      error ? error.type : '',
      error ? error.context : '',
    );
  }

  private debugLog(message: string, ...args: unknown[]) {
    if (this.debugLogging) {
      // eslint-disable-next-line
      console.log(`[${Date.now()}]`, `(${this.name})`, message, ...args);
    }
  }
}

export class SyncProvider implements RpcProvider {
  private readonly provider: BaseSyncProvider;
  constructor(
    connectionInfo: utils.ConnectionInfo | string,
    domain: number,
    stallTimeout = 10_000,
    debugLogging = false,
  ) {
    this.provider = new BaseSyncProvider(connectionInfo, domain, stallTimeout, debugLogging);
  }

  public get name(): string {
    return this.provider.name;
  }

  public get priority(): number {
    return this.provider.priority;
  }

  public set priority(updated: number) {
    this.provider.priority = updated;
  }

  public get lag(): number {
    return this.provider.lag;
  }

  public set lag(updated: number) {
    this.provider.lag = updated;
  }

  public get synced(): boolean {
    return this.provider.synced;
  }

  public set synced(updated: boolean) {
    this.provider.synced = updated;
  }

  public get reliability(): number {
    return this.provider.reliability;
  }

  public get latency(): number {
    return this.provider.latency;
  }

  public get cps(): number {
    return this.provider.cps;
  }

  public get syncedBlockNumber(): number {
    return this.provider.syncedBlockNumber;
  }

  public get internalProvider(): BaseSyncProvider {
    return this.provider;
  }

  // Env Methods
  public async sync(): Promise<void> {
    await this.provider.sync();
  }

  public async getGasPrice(): Promise<string> {
    return (await this.provider.getGasPrice()).toString();
  }

  public async getBlock(block: number | string) {
    return this.provider.getBlock(block);
  }

  public async getBlockNumber(): Promise<number> {
    return this.provider.getBlockNumber();
  }

  public async getCode(address: string) {
    return this.provider.getCode(address);
  }

  // Transaction Methods
  public getTransaction(hash: string) {
    return this.provider.getTransaction(hash);
  }

  public prepareRequest(method: string, params: unknown): [string, unknown[]] {
    return this.provider.prepareRequest(method, params);
  }

  public async getTransactionReceipt(hash: string) {
    return this.provider.getTransactionReceipt(hash);
  }

  public async estimateGas(tx: ReadTransaction | WriteTransaction) {
    // get formatted transaction
    const { domain, ...toCall } = tx;
    const formatted = {
      ...toCall,
      chainId: domainToChainId(domain),
    };
    return (await this.provider.estimateGas(formatted)).toString();
  }

  public send(method: string, params: unknown[]): Promise<unknown> {
    return this.provider.send(method, params);
  }

  public call(tx: ReadTransaction, block: number | string): Promise<string> {
    // get formatted transaction
    const { domain, ...toCall } = tx;
    const formatted = {
      ...toCall,
      chainId: domainToChainId(domain),
    };
    return this.provider.call(formatted, block);
  }

  // Token / Balance Methods
  public async getBalance(address: string, assetId: string): Promise<string> {
    if (assetId === constants.AddressZero) {
      return (await this.provider.getBalance(address)).toString();
    }
    const iface = new Interface(['function balanceOf(address owner) view returns (uint256)']);
    const encoded = await this.provider.call({
      to: assetId,
      data: iface.encodeFunctionData('balanceOf', [address]),
      chainId: domainToChainId(this.provider.domain),
    });
    const [balance] = iface.decodeFunctionResult('balanceOf', encoded);
    return balance.toString();
  }

  public async getDecimals(assetId: string): Promise<number> {
    const iface = new Interface([
      {
        type: 'function',
        name: 'decimals',
        inputs: [],
        outputs: [
          {
            name: '',
            type: 'uint8',
            internalType: 'uint8',
          },
        ],
        stateMutability: 'view',
      },
    ]);
    const encoded = await this.provider.call({
      to: assetId,
      data: iface.encodeFunctionData('decimals'),
      chainId: domainToChainId(this.provider.domain),
    });
    const [decimals] = iface.decodeFunctionResult('decimals', encoded);
    return decimals;
  }

  // Signer Methods
  public async getTransactionCount(address: string, block: number | string) {
    return this.provider.getTransactionCount(address, block);
  }

  public getSigner(signer: ISigner | string) {
    if (typeof signer === 'string') {
      return new Wallet(signer, this.provider);
    }
    return signer;
  }

  public connect(signer: ISigner | string): ISigner {
    return (signer as SignerTypeMaps['evm']).connect(this.provider);
  }
}
