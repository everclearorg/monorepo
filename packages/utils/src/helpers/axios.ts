/* eslint-disable @typescript-eslint/no-explicit-any */
import axios, { AxiosResponse, AxiosRequestConfig } from 'axios';

import { jsonifyError, EverclearError } from '../types';

export const delay = (ms: number): Promise<void> => new Promise((res: () => void): any => setTimeout(res, ms));

export class AxiosQueryError extends EverclearError {
  constructor(url: string, method: 'get' | 'post', data: any, errorObj: any) {
    super(`Error sending axios request to url ${url}`, { url, data, method, error: errorObj }, AxiosQueryError.name);
  }
}

const axiosQuery = async <R, D>(
  method: 'get' | 'post',
  url: string,
  data?: D,
  config?: AxiosRequestConfig,
  numAttempts = 30,
  retryDelay = 2000,
): Promise<R> => {
  let error;
  for (let i = 0; i < numAttempts; i++) {
    if (i > 0) await delay(retryDelay);
    try {
      const response = await axios[method](url, data, config);
      return response as R;
    } catch (err: unknown) {
      error = axios.isAxiosError(err)
        ? { error: err.toJSON(), status: err.response?.status }
        : jsonifyError(err as EverclearError);
    }
  }
  throw new AxiosQueryError(url, method, data, error);
};

export const axiosPost = async <T = any, R = AxiosResponse<T>, D = any>(
  url: string,
  data?: D,
  config?: AxiosRequestConfig,
  numAttempts = 30,
  retryDelay = 2000,
): Promise<R> => {
  return axiosQuery<R, D>('post', url, data, config, numAttempts, retryDelay);
};

export const axiosGet = async <T = any, R = AxiosResponse<T>, D = any>(
  url: string,
  data?: D,
  numAttempts = 5,
  retryDelay = 2000,
): Promise<R> => {
  return axiosQuery<R, D>('get', url, data, undefined, numAttempts, retryDelay);
};

/**
 * Returns domain name from url string
 * @param url The http or https string
 * @returns https://api.thegraph.com/subgraphs/name... => api.thegraph.com
 */
export const parseHostname = (url: string) => {
  const matches = /^https?:\/\/([^/?#]+)(?:[/?#]|$)/i.exec(url);
  return matches && matches[1];
};

export const formatUrl = (_url: string, endpoint: string, identifier?: string): string => {
  let url = `${_url}/${endpoint}`;
  if (identifier) {
    url += `${identifier}`;
  }
  return url;
};
