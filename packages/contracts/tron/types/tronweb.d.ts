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
    // Add whatever else you need from TronWeb.utils.abi
  }

  /**
   * Sub-interface for TronWeb.utils
   */
  interface TronWebUtils {
    abi: TronWebUtilsAbi;
    // Possibly more, like code for SHA3, etc. if you use them
    // sha3(...): string;   // for example
  }

  /**
   * Main TronWeb class definition
   */
  export class TronWeb {
    constructor(options: TronWebOptions | { fullHost: string; privateKey: string });

    // The important fix is here, so you can do tronWeb.contract(...):
    contract(...args: any[]): any;

    // For address conversions as instance methods:
    address: {
      toHex(address: string): string;
      fromHex(hex: string): string;
    };

    // Also as static methods on the class:
    static address: {
      toHex(address: string): string;
      fromHex(hex: string): string;
    };

    // Add the utils interface so you can do TronWeb.utils.abi.encodeFunctionCall or tronWeb.utils.abi....
    static utils: TronWebUtils;
    utils: TronWebUtils;

    trx: {
      getBalance(address: string): Promise<number>;
      getAccountResources(address: string): Promise<any>;
      // etc.
    };

    transactionBuilder: {
      createSmartContract(params: {
        abi: any[];
        bytecode: string;
        feeLimit?: number;
        callValue?: number;
        parameters?: unknown[];
      }): Promise<any>;
      // etc.
    };

    defaultAddress: {
      base58: string;
      hex: string;
    };
  }

  export default TronWeb;
}
