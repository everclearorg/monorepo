import { sendWithRelayerWithBackup } from '@chimera-monorepo/adapters-relayer';
import {
  QueueType,
  Queue,
  RequestContext,
  createLoggingContext,
  domainToChainId,
  jsonifyError,
  getNtpTimeSeconds,
} from '@chimera-monorepo/utils';
import { Interface, arrayify, keccak256, defaultAbiCoder } from 'ethers/lib/utils';
import { WriteTransaction } from '@chimera-monorepo/chainservice';
import { getContext } from '../../context';
import { getQueueMethodName, getTypeHash } from './getMessageQueueConstants';
import { RelayerSendFailed } from '../../errors/tasks';
import { BigNumber } from 'ethers';

const DEFAULT_SIGNATURE_TTL = 60 * 60; // 60 minutes

// NOTE: these values are stored onchain, and should be pulled from hub
const BASE_GAS = 40_000; // base gas for a transaction
const DEFAULT_GAS_BUFFER = 10_000; // 10% stored onchain
const DESTINATION_GAS_CONSUMPTION: Record<QueueType, number> = {
  [QueueType.Intent]: 1_750_000, // generous assumptions, variable gas consumption.
  [QueueType.Settlement]: 50_000, // NOTE: also stored onchain, should ideally be pulled from settler.
  [QueueType.Fill]: 1_750_000, // generous assumptions, variable gas consumption.
  [QueueType.Deposit]: 0, // Deposit queue is not a message queue, irrelevant
};

// NOTE: When sending messages from hub, may hit the gas limit on the origin if the destination chain
// has a higher gas limit. These values are derived from forge.
const MAX_SETTLEMENT_DEQUEUE = 900;

const DEFAULT_HYPERLANE_BUFFER = 15_000; // 15%
const BPS_DENOMINATOR = 100_000;

export const dispatchMessageQueueViaRelayers = async (
  type: QueueType,
  queue: Queue,
  sortedContents: unknown[], // OriginIntent, DestinationIntent, HubIntent
  _requestContext: RequestContext,
): Promise<string[]> => {
  const {
    config: { chains, hub, abis },
    logger,
    adapters: { relayers, wallet, chainservice },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(dispatchMessageQueueViaRelayers.name, _requestContext);
  logger.debug('Method started', requestContext, methodContext, { type, queue });
  const spokes = Object.keys(chains).filter((d) => d !== hub.domain);

  // Ensure the spoke is configured
  if (!chains[queue.domain]) {
    logger.warn('Missing chain config', requestContext, methodContext, {
      queue,
      spokes,
      hub: hub.domain,
    });
    return [];
  }

  // Get addresses from deployment
  const transactionDomain = queue.type === 'SETTLEMENT' ? hub.domain : queue.domain;
  const { gateway, everclear } =
    transactionDomain === hub.domain ? hub.deployments : chains[transactionDomain].deployments ?? {};
  if (!gateway || !everclear) {
    logger.warn('Missing gateway or everclear address', requestContext, methodContext, {
      queue,
      spoke: queue.domain,
      chains,
    });
    return [];
  }
  const everclearIface = new Interface(transactionDomain === hub.domain ? abis.hub.everclear : abis.spoke.everclear);

  // Get the number of elements to dequeue
  // Maxes are defined by the lowest block gas limit on the message route.
  // Message route is defined by origin chain, the queue type, and the environment
  // hub chain.

  // Get the destination. If transacting on hub, destination is the spoke and vice versa.
  const destinationDomain = transactionDomain === hub.domain ? queue.domain : hub.domain;
  const blockLimit = BigNumber.from(chains[destinationDomain].gasLimit!);
  const bufferMultiple = BigNumber.from(BPS_DENOMINATOR + DEFAULT_GAS_BUFFER).div(BPS_DENOMINATOR);
  const gasAvailable = blockLimit
    .mul(BPS_DENOMINATOR)
    .div(BPS_DENOMINATOR + DEFAULT_GAS_BUFFER)
    .sub(BASE_GAS);
  const calculatedMax = gasAvailable.div(DESTINATION_GAS_CONSUMPTION[type]).toNumber();
  const maxDequeue = type === QueueType.Settlement ? Math.min(calculatedMax, MAX_SETTLEMENT_DEQUEUE) : calculatedMax;

  if (maxDequeue === 0) {
    logger.warn('Unable to retrieve max dequeue elements', requestContext, methodContext, {
      transactionDomain,
      destinationDomain,
      bufferMultiple: bufferMultiple.toString(),
      blockLimit: blockLimit.toString(),
    });
    return [];
  }

  const totalIntents = queue.size;
  logger.debug('Processing queue', requestContext, methodContext, { type, queue, totalIntents, maxDequeue });

  // Dequeue in batches
  // This handles the case where the queue is too large to dequeue in a single transaction
  // Can happen in failure scenarios where the queue is not processed for a long time

  // Get the nonce for the signer (each transaction in the batch must increment the nonce)

  // Use `pending` block tag for hub chains because they're lazy blockchains right now.
  const blockTag = transactionDomain == hub.domain ? 'pending' : 'latest';

  const walletAddr = await wallet.getAddress();
  const encodedNonce = await chainservice.readTx(
    {
      to: everclear,
      data: everclearIface.encodeFunctionData('nonces', [walletAddr]),
      domain: +transactionDomain,
    },
    blockTag,
  );
  let [nonce] = everclearIface.decodeFunctionResult('nonces', encodedNonce) as [BigNumber];

  const taskIds: Record<number, string> = {};
  for (let i = 0; i < totalIntents; i += maxDequeue) {
    const toDequeue = Math.min(maxDequeue, totalIntents - i);
    // Trim intents to match max elements, sorted by block number
    const trimmedIntents = sortedContents.slice(i, i + toDequeue);

    // NOTE: the signature _must_ include the relayer address, meaning a different
    // relayer transaction will be required for each configured relayer.
    const errors: Error[] = [];
    for (const relayer of relayers) {
      try {
        logger.debug('Generating transaction for relayer', requestContext, methodContext, {
          relayer: relayer.type,
          queue,
          toDequeue,
          owner: walletAddr,
        });
        const relayerAddress = await relayer.instance.getRelayerAddress(domainToChainId(transactionDomain));

        // Generate the signature
        const ttl = getNtpTimeSeconds() + DEFAULT_SIGNATURE_TTL;
        logger.debug('Generating signature', requestContext, methodContext, {
          typeHash: getTypeHash(type),
          domain: transactionDomain,
          toDequeue,
          relayerAddress,
          ttl,
          nonce: nonce.toString(),
          signer: walletAddr,
        });

        // NOTE: Settlement queue encodes buffer after the nonce. Spoke queues do not.
        const types = ['bytes32', 'uint32', 'uint32', 'address', 'uint256', 'uint256', 'uint256'];
        const payload = defaultAbiCoder.encode(types, [
          getTypeHash(type),
          queue.domain,
          toDequeue,
          relayerAddress,
          ttl,
          nonce,
          DEFAULT_HYPERLANE_BUFFER,
        ]);
        const digest = keccak256(payload);
        const signature = await wallet.signMessage(arrayify(digest));
        logger.info('Generated signature', requestContext, methodContext, {
          typeHash: getTypeHash(type),
          domain: transactionDomain,
          toDequeue,
          relayerAddress,
          ttl,
          nonce: nonce.toString(),
          payload,
          signature,
          signer: walletAddr,
        });

        const tx: WriteTransaction = {
          data: everclearIface.encodeFunctionData(getQueueMethodName(type), [
            queue.domain,
            type === 'INTENT' ? trimmedIntents : toDequeue,
            relayerAddress,
            ttl,
            nonce,
            DEFAULT_HYPERLANE_BUFFER,
            signature,
          ]),
          to: everclear,
          value: '0',
          domain: +transactionDomain,
        };

        logger.debug('Sending process queue transaction to relayer', requestContext, methodContext, {
          type,
          queue,
          toDequeue,
          relayerAddress,
          ttl,
          nonce: nonce.toString(),
          signature,
          payload,
          tx,
        });

        const { taskId, relayerType } = await sendWithRelayerWithBackup(
          domainToChainId(tx.domain),
          tx.domain.toString(),
          tx.to,
          tx.data,
          tx.value,
          [relayer],
          chainservice,
          logger,
          requestContext,
        );
        logger.info('Dispatched queue', requestContext, methodContext, {
          type,
          taskId,
          relayerType,
          queue,
        });
        taskIds[i] = taskId;
        // exit early if the task was dispatched
        break;
      } catch (e) {
        logger.error('Failed to dispatch queue', requestContext, methodContext, jsonifyError(e as Error), {
          relayer: relayer.type,
          type,
          queue,
          toDequeue,
        });
        errors.push(e as Error);
      }
    }

    // Error if all relayers fail for any batch
    if (errors.length === relayers.length) {
      logger.info('Failed to dispatch full queue', requestContext, methodContext, {
        completed: Object.keys(taskIds).length,
        pending: totalIntents - Object.keys(taskIds).length,
        tasks: Object.values(taskIds),
        type,
        queue,
      });
      throw new RelayerSendFailed(
        queue.domain,
        relayers.map((r) => r.type),
        errors,
      );
    }

    // Increment the nonce for the next batch
    nonce = nonce.add(1);
    // FIXME: Should process the full batch
    break;
  }
  return Object.values(taskIds);
};
