import { EverclearError, delay, domainToChainId, parseHostname, ERC20Abi } from '@chimera-monorepo/utils';
import { chainWrapper, type PublicClient } from '@chimera-monorepo/utils';

import { parseError, RpcError, ServerError, StallTimeout } from '../../errors';
import { ISigner, ReadTransaction, WriteTransaction, ITransactionReceipt, ITransactionResponse, IBlock } from '../../types';
import { RpcProvider } from '..';
import { EthWallet } from './wallet';

// TODO: Wrap metrics in a type, and add a getter for it for logging purposes (after sync() calls, for example)
// TODO: Should be a multiton mapped by URL (such that no duplicate instances are created).
/**
 * @classdesc A provider that manages chain synchronization status
 * and intercepts all RPC send() calls to ensure that the provider is in sync.
 */
class BaseSyncProvider {
  public readonly rpcUrls: string[];
  public readonly name: string;
  public readonly domain: number;
  public readonly stallTimeout: number;
  public readonly client: PublicClient;

  public synced = true;
  public lag = 0;
  public priority = 0;

  private static readonly N_SAMPLES = 100;
  // Denominator is the target reliability sample size.
  private static readonly RELIABILITY_STEP = 1 / BaseSyncProvider.N_SAMPLES;
  // A metric used for measuring reliability, based on the number of successful calls / last N calls made.
  public reliability = 1.0;

  // Used for tracking how many calls we've made in the last second.
  public cpsTimestamps: number[] = [];
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
  public set syncedBlockNumber(value: number) {
    this._syncedBlockNumber = value;
  }

  constructor(
    _connectionInfo: { urls: string[] } | string[],
    domain: number,
    stallTimeout = 10_000,
    private readonly debugLogging = false,
  ) {
    this.domain = domain;
    this.stallTimeout = stallTimeout;

    if (Array.isArray(_connectionInfo)) {
      this.rpcUrls = _connectionInfo;
    } else {
      this.rpcUrls = _connectionInfo.urls;
    }

    const hostnames = this.rpcUrls
      .map(url => {
        const hostname = parseHostname(url);
        if (!hostname) return url;
        return hostname.split('.').slice(0, -1).join('.') || hostname;
      })
      .filter((name, index, array) => array.indexOf(name) === index); // Remove duplicates

    this.name = hostnames.join(',');

    const transport = this.rpcUrls.length > 1
      ? chainWrapper.fallback(this.rpcUrls.map(url => chainWrapper.http(url)), { rank: true })
      : chainWrapper.http(this.rpcUrls[0]);

    this.client = chainWrapper.createPublicClient({
      chain: {
        id: domainToChainId(domain),
        name: `Chain ${domain}`,
        nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
        rpcUrls: {
          default: { http: this.rpcUrls },
          public: { http: this.rpcUrls }
        },
        blockExplorers: {
          default: { name: 'Explorer', url: 'https://etherscan.io' }
        },
      },
      transport,
      batch: {
        multicall: true,
      },
    }) as PublicClient;
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
    // Check if provider is ready (synced)
    if (!this.synced) {
      throw new RpcError(RpcError.reasons.OutOfSync, {
        provider: this.name,
        domain: this.domain,
        lastSyncedBlockNumber: this.syncedBlockNumber,
        synced: this.synced,
        lag: this.lag,
        ready: false,
      });
    }

    // TODO: Make # of retries configurable?
    const errors: Error[] = [];
    let sendTimestamp = -1;
    for (let i = 1; i <= 5; i++) {
      try {
        sendTimestamp = Date.now();
        this.cpsTimestamps.push(sendTimestamp);
        console.log(`=== ETH PROVIDER SEND called with method: ${method}, domain: ${this.domain}, params:`, params);
        return await Promise.race(
          [
            new Promise(async (resolve, reject) => {
              try {
                const res = await this.client.request({
                  method: method as any,
                  params: params as any,
                });
                this.updateMetrics(true, sendTimestamp, i, method, params);
                resolve(res);
              } catch (e) {
                const error = parseError(e);
                reject(error);
              }
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

  public updateMetrics(
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

  // Core RPC Methods
  public async getGasPrice(): Promise<string> {
    const gasPrice = await this.client.getGasPrice();
    return gasPrice.toString();
  }

  public async getBlock(blockTag: number | string): Promise<IBlock> {
    const block = await this.client.getBlock({
      blockHash: typeof blockTag === 'string' && blockTag.startsWith('0x') ? blockTag as any : undefined,
      blockNumber: typeof blockTag === 'number' ? BigInt(blockTag) : undefined,
    });

    // Convert viem Block to IBlock
    return {
      hash: block.hash || '',
      parentHash: block.parentHash,
      number: Number(block.number),
      timestamp: Number(block.timestamp),
    };
  }

  public async getBlockNumber(): Promise<number> {
    const blockNumber = await this.client.getBlockNumber();
    return Number(blockNumber);
  }

  public async getCode(address: string): Promise<string> {
    const code = await this.client.getCode({ address: address as `0x${string}` });
    return code || '0x';
  }

  public async getTransaction(hash: string): Promise<ITransactionResponse | undefined> {
    try {
      const tx = await this.client.getTransaction({ hash: hash as any });
      if (!tx) return undefined;

      return {
        hash: tx.hash,
        nonce: Number(tx.nonce),
        gasLimit: tx.gas,
        gasPrice: tx.gasPrice,
        confirmations: 0, // Will be set by caller
      };
    } catch {
      return undefined;
    }
  }

  public async getTransactionReceipt(hash: string): Promise<ITransactionReceipt> {
    const receipt = await this.client.getTransactionReceipt({ hash: hash as any });

    return {
      transactionHash: receipt.transactionHash,
      blockNumber: Number(receipt.blockNumber),
      status: receipt.status === 'success' ? 1 : 0,
      confirmations: 0, // Will be set by caller
      logs: receipt.logs.map(log => ({
        address: log.address,
        topics: log.topics,
        data: log.data,
        blockNumber: Number(log.blockNumber),
        transactionHash: log.transactionHash,
        transactionIndex: Number(log.transactionIndex),
        logIndex: Number(log.logIndex),
        blockHash: log.blockHash,
        removed: log.removed,
      })),
    };
  }

  public async estimateGas(tx: any): Promise<string> {
    const gas = await this.client.estimateGas({
      account: tx.from,
      to: tx.to,
      value: tx.value ? BigInt(tx.value) : undefined,
      data: tx.data,
    });
    return gas.toString();
  }

  public async call(tx: any, block: string): Promise<string> {
    const result = await this.client.call({
      account: tx.from,
      to: tx.to,
      value: tx.value ? BigInt(tx.value) : undefined,
      data: tx.data,
      blockTag: block as any,
    });
    return (result as unknown as string) || '0x';
  }

  public async getBalance(address: string): Promise<string> {
    const balance = await this.client.getBalance({ address: address as `0x${string}` });
    return balance.toString();
  }

  public async getTransactionCount(address: string, block: string): Promise<number> {
    const count = await this.client.getTransactionCount({ address: address as `0x${string}`, blockTag: block as any });
    return Number(count);
  }
}

export class SyncProvider implements RpcProvider {
  private readonly provider: BaseSyncProvider;
  constructor(
    connectionInfo: { urls: string[] } | string[],
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

  public set syncedBlockNumber(value: number) {
    this.provider.syncedBlockNumber = value;
  }

  public get internalProvider(): BaseSyncProvider {
    return this.provider;
  }

  public get stallTimeout(): number {
    return this.provider.stallTimeout;
  }

  // Env Methods
  public async sync(): Promise<void> {
    await this.provider.sync();
  }

  public async getGasPrice(): Promise<string> {
    return await this.provider.getGasPrice();
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

  public async getTransactionReceipt(hash: string) {
    return this.provider.getTransactionReceipt(hash);
  }

  public async estimateGas(tx: ReadTransaction | WriteTransaction) {
    // get formatted transaction by excluding funcSig and getting chain id
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { domain, funcSig, ...toCall } = tx;
    const formatted = {
      ...toCall,
      chainId: domainToChainId(domain),
    };
    return await this.provider.estimateGas(formatted);
  }

  public send(method: string, params: unknown[]): Promise<unknown> {
    return this.provider.send(method, params);
  }

  public call(tx: ReadTransaction, block: number | string): Promise<string> {
    // get formatted transaction by excluding funcSig and getting chain id
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { domain, funcSig, ...toCall } = tx;
    const formatted = {
      ...toCall,
      chainId: domainToChainId(domain),
    };
    return this.provider.call(formatted, block.toString());
  }

  // Token / Balance Methods
  public async getBalance(address: string, assetId: string): Promise<string> {
    if (assetId === chainWrapper.zeroAddress) {
      return await this.provider.getBalance(address);
    }

    try {
      const balance = await this.provider.client.readContract({
        address: assetId as `0x${string}`,
        abi: ERC20Abi,
        functionName: 'balanceOf',
        args: [address as `0x${string}`],
      }) as bigint;
      return balance.toString();
    } catch (error) {
      // Fallback to direct RPC call if readContract fails
      const result = await this.provider.send('eth_call', [{
        to: assetId,
        data: '0x70a08231000000000000000000000000' + address.slice(2).padStart(64, '0'),
      }, 'latest']);
      return result as string;
    }
  }

  public async getDecimals(assetId: string): Promise<number> {
    try {
      const decimals = await this.provider.client.readContract({
        address: assetId as `0x${string}`,
        abi: ERC20Abi,
        functionName: 'decimals',
      }) as number;
      return Number(decimals);
    } catch (error) {
      // Fallback to direct RPC call if readContract fails
      const result = await this.provider.send('eth_call', [{
        to: assetId,
        data: '0x313ce567',
      }, 'latest']);
      return parseInt(result as string, 16);
    }
  }

  // Signer Methods
  public async getTransactionCount(address: string, block: number | string) {
    return this.provider.getTransactionCount(address, block.toString());
  }

  public async getSigner(signer: ISigner | string): Promise<ISigner> {
    if (typeof signer === 'string') {
      return new EthWallet(signer, { rpcUrls: this.provider.rpcUrls });
    }
    return signer;
  }

  public async connect(signer: ISigner | string): Promise<ISigner> {
    return this.getSigner(signer);
  }
}
