import * as fs from 'fs';
import {
  getEverclearConfig as _getEverclearConfig,
  axiosGet as _axiosGet,
  axiosPost as _axiosPost,
} from '@chimera-monorepo/utils';
import { Contract, ContractInterface, providers } from 'ethers';
import { Twilio as _twilio } from 'twilio';
import { MessageInstance } from 'twilio/lib/rest/api/v2010/account/message';
import { createClient as _createClient } from 'redis';

import fastify, { FastifyInstance } from 'fastify';

export const getFastifyInstance = (): FastifyInstance => {
  return fastify();
};

export const existsSync = fs.existsSync;
export const readFileSync = fs.readFileSync;

export const getEverclearConfig = _getEverclearConfig;

export const getContract = (address: string, abi: ContractInterface, provider?: providers.JsonRpcProvider) =>
  new Contract(address, abi, provider);

export const axiosPost = _axiosPost;
export const axiosGet = _axiosGet;

export const Twilio = _twilio;

export const createClient = _createClient;

export const sendMessageViaTwilio = async (
  accountSid: string,
  authToken: string,
  textContext: { body: string; to: string; from: string },
): Promise<MessageInstance> => {
  const client = new Twilio(accountSid, authToken);
  return await client.messages.create(textContext);
};
