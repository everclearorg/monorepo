// tron/types/tronweb.d.ts

declare module 'tronweb' {
  interface TronWebOptions {
    fullHost: string;
    privateKey?: string;
  }

  /**
   * Sub-interface for TronWeb.utils.abi
   */
  interface TronWebUtilsAbi {
    encodeFunctionCall(fnABI: any, args: any[]): string;
    encodeFunctionSignature(fnABI: any): string;
    encodeParams(params: { type: string; value: any }[]): string;
    decodeParams(types: any[], encoded: string): any[];
    // Extend as needed
  }

  /**
   * Sub-interface for TronWeb.utils
   */
  interface TronWebUtils {
    abi: TronWebUtilsAbi;
  }

  /**
   * Broadcast return type for TronWeb transactions
   */
  interface BroadcastReturn {
    result: boolean;
    code?: string;
    message?: string;
    txid?: string;
  }

  /**
   * Main TronWeb class definition
   */
  export class TronWeb {
    constructor(options: TronWebOptions | { fullHost: string; privateKey: string });

    // Contract factory
    contract(...args: any[]): any;

    // Address helpers as instance properties
    address: {
      toHex(address: string): string;
      fromHex(hex: string): string;
    };

    // Address helpers as static properties
    static address: {
      toHex(address: string): string;
      fromHex(hex: string): string;
    };

    // Utils (instance & static)
    static utils: TronWebUtils;
    utils: TronWebUtils;

    // TRX‑related remote procedure calls
    trx: {
      getBalance(address: string): Promise<number>;
      getAccountResources(address: string): Promise<any>;
      /**
       * Fetch a raw transaction by its hash / ID
       * Equivalent to `tronWeb.trx.getTransaction(txId)`
       */
      getTransaction(txId: string): Promise<any>;
      /**
       * Fetch execution info / receipt for a given transaction
       * Equivalent to `tronWeb.trx.getTransactionInfo(txId)`
       */
      getTransactionInfo(txId: string): Promise<any>;
      /**
       * Broadcast a signed transaction to the network
       */
      broadcast(transaction: any): Promise<BroadcastReturn>;
      /**
       * Sign a transaction
       */
      sign(transaction: any): Promise<any>;
      /**
       * Send a raw transaction to the network
       */
      sendRawTransaction(signedTransaction: any): Promise<BroadcastReturn>;
      // …extend with more methods as required
    };

    transactionBuilder: {
      createSmartContract(params: {
        abi: any[];
        bytecode: string;
        feeLimit?: number;
        callValue?: number;
        parameters?: unknown[];
      }): Promise<any>;

      triggerConstantContract(
        contractAddress: string,
        functionSelectorOrData: string, // TronWeb lets you pass full 0x‑data
        feeLimit: number,
        callValue: number,
        parameter?: string,
        issuerAddress?: string,
      ): Promise<{
        result: { result: boolean; code?: string; message?: string };
        constant_result: string[];
      }>;

      triggerSmartContract(
        contractAddress: string,
        functionSelector: string,
        options: {
          feeLimit?: number;
          callValue?: number;
          permissionId?: number;
        },
        parameters?: any[],
        issuerAddress?: string,
      ): Promise<{
        result: { result: boolean; code?: string; message?: string };
        transaction: any;
      }>;

      sendTrx(
        to: string,
        amount: number,
      ): Promise<any>;

      extendExpiration(
        transaction: any,
        expiration: number,
      ): Promise<any>;
    };

    defaultAddress: {
      base58: string;
      hex: string;
    };
  }

  export default TronWeb;
}
