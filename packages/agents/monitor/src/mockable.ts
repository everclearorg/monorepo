/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  axiosGet as _axiosGet,
  axiosPost as _axiosPost,
  getDefaultABIConfig as _getDefaultABIConfig,
  getTokenPriceFromCoingecko as _getTokenPriceFromCoingecko,
  getEverclearConfig as _getEverclearConfig,
  getTokenPriceFromChainlink as _getTokenPriceFromChainlink,
  getTokenPriceFromUniV2 as _getTokenPriceFromUniV2,
  getTokenPriceFromUniV3 as _getTokenPriceFromUniV3,
  getHyperlaneMessageStatus as _getHyperlaneMessageStatus,
  getHyperlaneMsgDelivered as _getHyperlaneMsgDelivered,
  sendAlerts as _sendAlerts,
  resolveAlerts as _resolveAlerts,
  getSsmParameter as _getSsmParameter,
  getMailboxInterface as _getMailboxInterface,
  type Abi,
} from '@chimera-monorepo/utils';

// Create a mock getContract function that returns a basic contract-like object
export const getContract = (address: string, abi: Abi): any => {
  return {
    address,
    abi,
    interface: {
      // Mock interface methods that the calling code expects
      encodeFunctionData: (functionName: string, args: any[] = []) => {
        return `0x${functionName}${args.join('')}`;
      },
      decodeFunctionResult: (functionName: string, data: string) => {
        // Return an object with the expected properties
        return {
          0: data,
          tickerHash: data,
          _maxDiscountDbps: '0',
          _discountPerEpoch: '0',
          _prioritizedStrategy: '0',
          map: (fn: any) => [fn(data)],
          length: 1,
          [Symbol.iterator]: function* () {
            yield data;
          },
        } as any;
      },
      getFunction: (functionName: string) => ({
        format: () => `${functionName}()`,
      }),
      getEvent: (eventName: string) => ({
        format: () => `${eventName}()`,
      }),
      getEventTopic: (event: any) => `0x${event.format().replace(/[()]/g, '')}`,
      parseLog: (log: any) => ({
        args: {
          message: log.data,
          status: 1, // Mock status
        },
      }),
    },
    // Add any other methods that might be needed
  };
};

export const axiosGet = _axiosGet;
export const getHyperlaneMessageStatus = _getHyperlaneMessageStatus;
export const getDefaultABIConfig = _getDefaultABIConfig;
export const getTokenPriceFromCoingecko = _getTokenPriceFromCoingecko;
export const getEverclearConfig = _getEverclearConfig;
export const getTokenPriceFromChainlink = _getTokenPriceFromChainlink;
export const getTokenPriceFromUniV2 = _getTokenPriceFromUniV2;
export const getTokenPriceFromUniV3 = _getTokenPriceFromUniV3;
export const getHyperlaneMsgDelivered = _getHyperlaneMsgDelivered;
export const sendAlerts = _sendAlerts;
export const resolveAlerts = _resolveAlerts;
export const getSsmParameter = _getSsmParameter;
export const getMailboxInterface = _getMailboxInterface;
