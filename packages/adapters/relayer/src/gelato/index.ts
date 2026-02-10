import {
  createGelatoEvmRelayerClient,
  GelatoEvmRelayerClient,
} from "@gelatocloud/gasless";

import { Relayer } from '..';

import { getRelayerAddress, getTaskStatus, send, waitForTaskCompletion, isChainSupportedByGelato } from './gelato';
export let gelatoRelay: GelatoEvmRelayerClient;

export const setupRelayer = async (apiKey: string): Promise<Relayer> => {
  gelatoRelay = createGelatoEvmRelayerClient({
    apiKey,
  });
  return {
    getRelayerAddress,
    send,
    getTaskStatus,
    waitForTaskCompletion,
    isChainSupported: isChainSupportedByGelato,
  };
};
