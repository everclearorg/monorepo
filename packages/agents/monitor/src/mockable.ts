import { Contract, ContractInterface, providers } from 'ethers';
import {
  axiosGet as _axiosGet,
  axiosPost as _axiosPost,
  getDefaultABIConfig as _getDefaultABIConfig,
  getTokenPriceFromCoingecko as _getTokenPriceFromCoingecko,
  getEverclearConfig as _getEverclearConfig,
  getBestProvider as _getBestProvider,
  getTokenPriceFromChainlink as _getTokenPriceFromChainlink,
  getTokenPriceFromUniV2 as _getTokenPriceFromUniV2,
  getTokenPriceFromUniV3 as _getTokenPriceFromUniV3,
  getHyperlaneMessageStatus as _getHyperlaneMessageStatus,
  getHyperlaneMsgDelivered as _getHyperlaneMsgDelivered,
  sendAlerts as _sendAlerts,
  resolveAlerts as _resolveAlerts,
  getSsmParameter as _getSsmParameter,
} from '@chimera-monorepo/utils';

export const getContract = (address: string, abi: ContractInterface, provider?: providers.JsonRpcProvider) =>
  new Contract(address, abi, provider);

export const axiosGet = _axiosGet;
export const axiosPost = _axiosPost;
export const getHyperlaneMessageStatus = _getHyperlaneMessageStatus;
export const getDefaultABIConfig = _getDefaultABIConfig;
export const getTokenPriceFromCoingecko = _getTokenPriceFromCoingecko;
export const getEverclearConfig = _getEverclearConfig;
export const getBestProvider = _getBestProvider;
export const getTokenPriceFromChainlink = _getTokenPriceFromChainlink;
export const getTokenPriceFromUniV2 = _getTokenPriceFromUniV2;
export const getTokenPriceFromUniV3 = _getTokenPriceFromUniV3;
export const getHyperlaneMsgDelivered = _getHyperlaneMsgDelivered;
export const sendAlerts = _sendAlerts;
export const resolveAlerts = _resolveAlerts;
export const getSsmParameter = _getSsmParameter;
