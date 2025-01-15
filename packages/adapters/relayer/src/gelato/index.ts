import { GELATO_SERVER } from '@chimera-monorepo/utils';
import { GelatoRelay } from '@gelatonetwork/relay-sdk';

import { Relayer } from '..';

import { getRelayerAddress, getTaskStatus, send, waitForTaskCompletion } from './gelato';
export let url: string;
export let gelatoRelay: GelatoRelay;

export const setupRelayer = async (_url?: string): Promise<Relayer> => {
  gelatoRelay = new GelatoRelay();
  url = _url ?? GELATO_SERVER;
  return {
    getRelayerAddress,
    send,
    getTaskStatus,
    waitForTaskCompletion,
  };
};
