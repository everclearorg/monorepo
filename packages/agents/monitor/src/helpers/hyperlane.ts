import {
  RequestContext,
  canonizeId,
  createLoggingContext,
  jsonifyError,
  HyperlaneMessageResponse,
  HyperlaneStatus,
  getMailboxInterface,
  Message,
} from '@chimera-monorepo/utils';
import { Interface, hexlify, solidityPack } from 'ethers/lib/utils';
import { NoDispatchEventOnMessage, NoGatewayConfigured } from '../types/errors';
import { getContext } from '../context';
import { getHyperlaneMessageStatus, getHyperlaneMsgDelivered } from './../mockable';
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
  const gatewayIface = new Interface(abis.spoke.gateway);
  const encodedMailbox = await chainreader.readTx(
    {
      to: gateway,
      domain: +message.destinationDomain,
      data: gatewayIface.encodeFunctionData('mailbox'),
    },
    'latest',
  );
  const [mailbox] = gatewayIface.decodeFunctionResult('mailbox', encodedMailbox);
  logger.debug('Got mailbox from gateway', requestContext, methodContext, { mailbox, gateway });
  const iface = getMailboxInterface();
  const providers =
    +message.destinationDomain === +hub.domain ? hub.providers : chains[message.destinationDomain]?.providers;

  const delivered = await getHyperlaneMsgDelivered(id, providers, gateway);

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
      to: mailbox,
      domain: +message.destinationDomain,
      data: iface.encodeFunctionData('process', [
        '0x', // TODO: ensure no metadata
        hyperlaneMessage,
      ]),
      value: '0',
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
  const dispatchEvent = iface.getEvent('Dispatch');
  const log = receipt.logs.find((log) => log.topics.includes(iface.getEventTopic(dispatchEvent)));
  if (!log) {
    throw new NoDispatchEventOnMessage(message.id, message.transactionHash);
  }
  const parsed = iface.parseLog(log);
  return parsed.args.message;
};

export const getDispatchedMessage = (message: HyperlaneMessageResponse) => {
  const { destinationDomainId, body, originDomainId, recipient, nonce, sender } = message;

  const dispatched = solidityPack(
    // version, nonce, origin, sender, destination, receiver, body
    ['uint8', 'uint32', 'uint32', 'bytes32', 'uint32', 'bytes32', 'bytes'],
    [3, nonce, originDomainId, hexlify(canonizeId(sender)), destinationDomainId, hexlify(canonizeId(recipient)), body],
  );
  return dispatched;
};
