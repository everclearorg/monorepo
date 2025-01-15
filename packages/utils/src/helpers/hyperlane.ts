import { axiosGet } from './axios';
import { Client, cacheExchange, fetchExchange } from '@urql/core';
import { Interface } from 'ethers/lib/utils';
import { ethers } from 'ethers';
import { getBestProvider } from './provider';

export const HyperlaneStatus = {
  none: 'none',
  pending: 'pending',
  delivered: 'delivered',
  relayable: 'relayable',
} as const;
export type HyperlaneStatus = (typeof HyperlaneStatus)[keyof typeof HyperlaneStatus];

export type HyperlaneMessageResponse = {
  id: string;
  status: HyperlaneStatus;
  body: string;
  originMailbox: string;
  originDomainId: number;
  destinationDomainId: number;
  destinationMailbox?: string;
  recipient: string;
  sender: string;
  nonce: number;
};

export const HYPERLANE_GRAPHQL_URL = 'https://explorer4.hasura.app/v1/graphql';

export function stringToPostgresBytea(hexString: string) {
  const trimmed = hexString.startsWith('0x') ? hexString.substring(2).toLowerCase() : hexString.toLowerCase();
  const prefix = `\\x`;
  return `${prefix}${trimmed}`;
}

export function postgresByteaToString(byteString: string) {
  const trimmed = byteString.startsWith('\\x') ? byteString.substring(2) : byteString;
  return byteString.startsWith('0x') ? trimmed : `0x${trimmed}`;
}

export const MessageQuery = `
query ($id: bytea!) {
  message_view(
    where: {msg_id: {_eq: $id}}
    limit: 10
  ) {
    msg_id
    nonce
    sender
    recipient
    is_delivered
    message_body
    origin_mailbox
    origin_domain_id
    origin_chain_id
    destination_chain_id
    destination_domain_id
    destination_mailbox
    send_occurred_at
    delivery_occurred_at
    delivery_latency
    num_payments
    total_payment
    total_gas_amount
  }
}`;

export const getMailboxInterface = (): Interface => {
  // Only need the `process` and `delivered` functions.
  return new Interface([
    {
      type: 'function',
      name: 'process',
      inputs: [
        {
          name: 'metadata',
          type: 'bytes',
          internalType: 'bytes',
        },
        {
          name: 'message',
          type: 'bytes',
          internalType: 'bytes',
        },
      ],
      outputs: [],
      stateMutability: 'payable',
    },
    {
      type: 'function',
      name: 'delivered',
      inputs: [
        {
          name: 'messageId',
          type: 'bytes32',
          internalType: 'bytes32',
        },
      ],
      outputs: [
        {
          name: '',
          type: 'bool',
          internalType: 'bool',
        },
      ],
      stateMutability: 'view',
    },
    {
      anonymous: false,
      inputs: [
        {
          indexed: true,
          internalType: 'address',
          name: 'sender',
          type: 'address',
        },
        {
          indexed: true,
          internalType: 'uint32',
          name: 'destination',
          type: 'uint32',
        },
        {
          indexed: true,
          internalType: 'bytes32',
          name: 'recipient',
          type: 'bytes32',
        },
        {
          indexed: false,
          internalType: 'bytes',
          name: 'message',
          type: 'bytes',
        },
      ],
      name: 'Dispatch',
      type: 'event',
    },
  ]);
};

export const getGatewayInterface = (): Interface => {
  return new Interface([
    {
      inputs: [],
      name: 'mailbox',
      outputs: [
        {
          internalType: 'address',
          name: '',
          type: 'address',
        },
      ],
      stateMutability: 'view',
      type: 'function',
    },
  ]);
};

export const getHyperlaneMessageStatusViaGraphql = async (
  id: string, // message identifier
): Promise<HyperlaneMessageResponse | undefined> => {
  const client = new Client({
    url: HYPERLANE_GRAPHQL_URL,
    exchanges: [cacheExchange, fetchExchange],
  });
  const parsed = stringToPostgresBytea(id);
  const { data } = (await client.query(MessageQuery, { id: parsed }).toPromise()) ?? {};
  if (!data || !data.message_view || !data.message_view.length) {
    return undefined;
  }
  const [message] = data.message_view;

  return {
    id: postgresByteaToString(message.msg_id),
    status: message.is_delivered ? 'delivered' : 'pending',
    body: postgresByteaToString(message.message_body),
    originDomainId: message.origin_domain_id,
    destinationDomainId: message.destination_domain_id,
    recipient: postgresByteaToString(message.recipient),
    sender: postgresByteaToString(message.sender),
    nonce: message.nonce,
    destinationMailbox: message.destination_mailbox ? postgresByteaToString(message.destination_mailbox) : undefined,
    originMailbox: postgresByteaToString(message.origin_mailbox),
  };
};

// NOTE: rest api down, maybe comes back?
export const getHyperlaneMessageStatusViaRestApi = async (
  messageId: string,
): Promise<HyperlaneMessageResponse | undefined> => {
  // Integrate the hyperlane explorer api from https://explorer.hyperlane.xyz/api-docs.

  const baseUrl = 'https://explorer.hyperlane.xyz/api';
  const action = 'module=message&action=get-messages';
  const url = `${baseUrl}?${action}&id=${messageId}`;

  try {
    const {
      data: {
        result: [result],
      },
    } = await axiosGet<{ result: HyperlaneMessageResponse[] }>(url);
    return result;
  } catch (err: unknown) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    console.error(`Error getting hyperlane message status. messageId: ${messageId}. ${(err as any).message}`);
  }

  return undefined;
};

export const getHyperlaneMessageStatus = async (messageId: string): Promise<HyperlaneMessageResponse | undefined> => {
  return (
    (await getHyperlaneMessageStatusViaRestApi(messageId)) ?? (await getHyperlaneMessageStatusViaGraphql(messageId))
  );
};

/**
 * Check the delivered status of hyperlane message on the destination.
 *
 * @param messageId - The given hyperlane message Id.
 * @param rpcUrls - The list of rpc endpoint.
 * @param gateway - The gateway contract on the target domain.
 *
 * @returns - If it's delivered, returns true. If not, returns false.
 */
export const getHyperlaneMsgDelivered = async (
  messageId: string,
  rpcUrls: string[],
  gateway: string,
): Promise<boolean> => {
  const bestProvider = await getBestProvider(rpcUrls);

  // If there's no working rpc url, returns `delivered` false.
  if (!bestProvider) return false;

  const gatewayContract = new ethers.Contract(
    gateway,
    getGatewayInterface(),
    new ethers.providers.JsonRpcProvider(bestProvider),
  );
  const mailbox = await gatewayContract.mailbox();

  const mailboxContract = new ethers.Contract(
    mailbox,
    getMailboxInterface(),
    new ethers.providers.JsonRpcProvider(bestProvider),
  );

  return await mailboxContract.delivered(messageId);
};
