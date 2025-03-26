// tron/types/tronweb.d.ts

declare module 'tronweb' {
  interface TronWebOptions {
    fullHost: string;
    privateKey?: string;
  }

  export class TronWeb {
    constructor(options: TronWebOptions | { fullHost: string; privateKey: string });

    // The important fix is here:
    contract(...args: any[]): any;

    static address: {
      toHex(address: string): string;
      fromHex(hex: string): string;
    };

    trx: {
      getBalance(address: string): Promise<number>;

      getAccountResources(address: string): Promise<any>;
    };

    transactionBuilder: {
      createSmartContract(params: {
        abi: any[];
        bytecode: string;
        feeLimit?: number;
        callValue?: number;
        parameters?: unknown[];
      }): Promise<any>;
      // you can add other methods if needed
    };

    defaultAddress: {
      base58: string;
      hex: string;
    };
  }

  export default TronWeb;
}
