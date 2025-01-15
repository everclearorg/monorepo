import { Logger } from '../logging';

import { axiosPost } from './axios';

export const sendHeartbeat = async (url: string, logger: Logger, retries?: number) => {
  logger.info('Sending a heartbeat message', undefined, undefined, { url });
  const response = await axiosPost(url, undefined, undefined, retries);
  logger.info('Heartbeat sent', undefined, undefined, { response: response?.data });
  return response?.data;
};
