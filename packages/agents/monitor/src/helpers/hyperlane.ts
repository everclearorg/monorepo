/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  canonizeId,
  chainWrapper,
  createLoggingContext,
  HyperlaneMessageResponse,
  HyperlaneStatus,
  isPolymerRoute,
  jsonifyError,
  Message,
  RequestContext,
  SOLANA_CHAINID,
} from '@chimera-monorepo/utils';
import { NoDispatchEventOnMessage, NoGatewayConfigured } from '../types';
import { getContext } from '../context';
import {
  getHyperlaneMessageStatus,
  getHyperlaneMsgDelivered,
  getMailboxInterface,
  getPolymerMsgDelivered,
} from '../mockable';
import { WriteTransaction } from '@chimera-monorepo/chainservice';

export const getMessageStatus = async (
  id: string,
  selfRelay = false,
  _requestContext?: RequestContext,
): Promise<{ status: HyperlaneStatus; relayTransaction?: WriteTransaction }> => {
  const { requestContext, methodContext } = createLoggingContext(getMessageStatus.name, _requestContext);
  const {
    logger,
    config: { chains, abis, hub },
    adapters: { chainreader, database },
  } = getContext();
  logger.debug('Method start', requestContext, methodContext, { id });

  const messages = await database.getMessagesByIds([id]);
  if (messages.length == 0) {
    return { status: 'none' };
  }
  const message = messages[0];

  if (!message.destinationDomain) {
    return { status: 'pending' };
  }
  // Check if destination is Solana chain
  if (message.destinationDomain === SOLANA_CHAINID) {
    logger.warn('Skipping Solana destination chain', requestContext, methodContext, {
      messageId: id,
      destinationDomain: message.destinationDomain,
    });
    return { status: 'none' };
  }

  // For Polymer-routed messages, query the Polymer relayer API instead of on-chain mailbox
  if (
    message.originDomain &&
    message.destinationDomain &&
    isPolymerRoute(message.originDomain, message.destinationDomain)
  ) {
    try {
      const status = await getPolymerMsgDelivered(id);
      return { status };
    } catch (e) {
      logger.error('Failed to get Polymer message status', requestContext, methodContext, jsonifyError(e as Error), {
        id,
        originDomain: message.originDomain,
        destinationDomain: message.destinationDomain,
      });
      return { status: 'pending' };
    }
  }

  // If the message is pending, check to see if it has been delivered onchain.
  // NOTE: graphql api returns `pending` if the message has been self-relayed.
  // Get the mailbox from the destination gateway contract and query directly.
  // NOTE: assumes alignment between hyperlane and everclear domains
  const gateway =
    +message.destinationDomain === +hub.domain
      ? hub.deployments.gateway
      : chains[message.destinationDomain]?.deployments?.gateway;
  if (!gateway) {
    throw new NoGatewayConfigured(message.destinationDomain, chains);
  }
  const encodedMailbox = await chainreader.readTx(
    {
      to: gateway,
      domain: +message.destinationDomain,
      data: chainWrapper.encodeFunctionData({
        abi: abis.spoke.gateway,
        functionName: 'mailbox',
      }),
      funcSig: 'mailbox()',
    },
    'latest',
  );
  const mailbox = chainWrapper.decodeFunctionResult({
    abi: abis.spoke.gateway,
    functionName: 'mailbox',
    data: encodedMailbox as `0x${string}`,
  }) as `0x${string}`;
  logger.debug('Got mailbox from gateway', requestContext, methodContext, { mailbox, gateway });
  const iface = getMailboxInterface();

  const delivered = await getHyperlaneMsgDelivered(
    id,
    gateway,
    (params) => chainreader.readTx(params, 'latest'), // Wrap ChainReader.readTx
    +message.destinationDomain,
    mailbox, // Pass mailbox to avoid redundant call
  );

  logger.debug('Queried destination mailbox', requestContext, methodContext, {
    delivered,
    mailbox,
    destination: message.destinationDomain,
    id,
  });
  if (delivered) {
    return { status: 'delivered' };
  }

  // Get the message from the hyperlane sdk
  const result = await getHyperlaneMessageStatus(id);
  logger.debug('Got hyperlane message', requestContext, methodContext, {
    result: { status: result?.status, destination: result?.destinationDomainId },
    id,
  });
  const validResult = result && Object.keys(result ?? {}).length > 0;

  if (!selfRelay && validResult) {
    return { status: result.status };
  }

  if (!validResult) {
    logger.warn('No result detected from hyperlane APIs', requestContext, methodContext, { id });
  }

  // Otherwise, check if it can be self-processed with an empty meta
  // Attempt to estimate the gas required to call `processMessage` on the mailbox
  try {
    logger.debug('Generating hyperlane relay tx', requestContext, methodContext);
    const hyperlaneMessage = validResult ? getDispatchedMessage(result) : await getDispatchedMessageFromEvent(message);
    const tx = {
      to: mailbox as `0x${string}`,
      domain: +message.destinationDomain,
      data: chainWrapper.encodeFunctionData({
        abi: iface,
        functionName: 'process',
        args: [
          '0x', // TODO: ensure no metadata
          hyperlaneMessage,
        ],
      }),
      value: '0',
      funcSig: 'process(bytes,bytes)',
    };
    logger.debug('Estimating gas for hyperlane relay tx', requestContext, methodContext, { tx });
    const gas = await chainreader.getGasEstimateWithRevertCode(tx);
    logger.info('Got for hyperlane relay tx', requestContext, methodContext, { tx, gas: gas.toString() });
    // Successfully estimates gas, ready for submission
    return { status: 'relayable', relayTransaction: tx };
  } catch (e) {
    logger.error(
      'Failed to generate relay transaction, status is pending',
      requestContext,
      methodContext,
      jsonifyError(e as Error),
      {
        message,
        result,
      },
    );
    return { status: 'pending' };
  }
};

export const getDispatchedMessageFromEvent = async (message: Message): Promise<string> => {
  // The message is emitted in the `Dispatch` event from the origin chain transaction
  const {
    adapters: { chainreader },
  } = getContext();

  const iface = getMailboxInterface();
  const receipt = await chainreader.getTransactionReceipt(+message.originDomain, message.transactionHash);
  const dispatchEventSignature = '0x3d0c9a00'; // keccak256('Dispatch(address,uint32,bytes32,bytes)')
  const log = receipt.logs.find((log) => log.topics.includes(dispatchEventSignature));
  if (!log) {
    throw new NoDispatchEventOnMessage(message.id, message.transactionHash);
  }

  try {
    const decodedLog = chainWrapper.decodeEventLog({
      abi: iface,
      data: log.data as `0x${string}`,
      topics: log.topics as [`0x${string}`, ...`0x${string}`[]],
    });

    return (decodedLog.args as any).message as string;
  } catch (error) {
    throw new NoDispatchEventOnMessage(message.id, message.transactionHash);
  }
};

export const getDispatchedMessage = (message: HyperlaneMessageResponse) => {
  const { destinationDomainId, body, originDomainId, recipient, nonce, sender } = message;

  return chainWrapper.encodePacked(
    // version, nonce, origin, sender, destination, receiver, body
    ['uint8', 'uint32', 'uint32', 'bytes32', 'uint32', 'bytes32', 'bytes'],
    [3, nonce, originDomainId, canonizeId(sender), destinationDomainId, canonizeId(recipient), body],
  );
};
