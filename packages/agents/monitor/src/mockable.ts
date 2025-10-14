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
  getMailboxInterface as _getMailboxInterface,
  getAccountResources as _getAccountResources,
  AssetConfig,
} from '@chimera-monorepo/utils';
import { fetchRelayerData as _fetchRelayerData } from './helpers/relayer';
import { getTronLastIntentNonce as _getTronLastIntentNonce } from './helpers/tron';

export const getContract = (address: string, abi: ContractInterface, provider?: providers.JsonRpcProvider) =>
  new Contract(address, abi, provider);

export const axiosGet = _axiosGet;
export const axiosPost = _axiosPost;
export const getHyperlaneMessageStatus = _getHyperlaneMessageStatus;
export const getDefaultABIConfig = _getDefaultABIConfig;
export const getTokenPriceFromCoingecko = _getTokenPriceFromCoingecko;
export const getEverclearConfig = _getEverclearConfig;
export const getBestProvider = _getBestProvider;
export const getTokenPriceFromChainlink = _getTokenPriceFromChainlink as (
  domain: string,
  priceFeed: string,
  provider: providers.JsonRpcProvider,
) => Promise<number>;
export const getTokenPriceFromUniV2 = _getTokenPriceFromUniV2 as (
  domain: string,
  pair: string,
  token0: AssetConfig,
  token1: AssetConfig,
  provier: providers.JsonRpcProvider,
) => Promise<number>;
export const getTokenPriceFromUniV3 = _getTokenPriceFromUniV3 as (
  domain: string,
  pool: string,
  token0: AssetConfig,
  token1: AssetConfig,
  provider: providers.JsonRpcProvider,
) => Promise<number>;
export const getHyperlaneMsgDelivered = _getHyperlaneMsgDelivered;
export const sendAlerts = _sendAlerts;
export const resolveAlerts = _resolveAlerts;
export const getSsmParameter = _getSsmParameter;
export const getMailboxInterface = _getMailboxInterface;
export const getAccountResources = _getAccountResources;
export const fetchRelayerData = _fetchRelayerData;
export const getTronLastIntentNonce = _getTronLastIntentNonce;
