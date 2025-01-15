import { Relayer } from '..';

import { everclearRelayerSend, getRelayerAddress, getTaskStatus, waitForTaskCompletion } from './everclear';

export let url: string;

export const setupRelayer = async (_url: string): Promise<Relayer> => {
  url = _url;
  return {
    getRelayerAddress,
    send: everclearRelayerSend,
    getTaskStatus,
    waitForTaskCompletion,
  };
};
