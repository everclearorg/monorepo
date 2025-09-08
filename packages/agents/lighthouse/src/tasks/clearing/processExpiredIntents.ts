import { getContext } from '../../context';
import { createLoggingContext, domainToChainId } from '@chimera-monorepo/utils';
import { sendWithRelayerWithBackup } from '@chimera-monorepo/adapters-relayer';
import { chainWrapper } from '@chimera-monorepo/utils';

/**
 * @notice Inserts any intents that have expired inot the queue. These are
 * intents that were not boosted by any solvers, and have timed out, or
 * were never intended to be boosted by solvers.
 * @dev Calls `storeIntent` ahd `handleExpiredInt` on the hub.
 * @dev Improvement: Cap the number of intentIds to process in a single transaction.
 */
export const processExpiredIntents = async () => {
  // Get the config
  const {
    config: { chains, hub, abis },
    logger,
    adapters: { database, chainservice, relayers },
  } = getContext();
  // Create logging context
  const { requestContext, methodContext } = createLoggingContext(processExpiredIntents.name);
  logger.info('Method started', requestContext, methodContext, { chains, hub });

  // Get the intent buffer from the hub
  const encodedExpiry = await chainservice.readTx(
    {
      data: chainWrapper.encodeFunctionData({
        abi: abis.hub.everclear,
        functionName: 'expiryTimeBuffer',
        args: [],
      }),
      domain: +hub.domain,
      to: hub.deployments.everclear,
      funcSig: 'expiryTimeBuffer()',
    },
    'latest',
  );
  const expiry = chainWrapper.decodeFunctionResult({
    abi: abis.hub.everclear,
    functionName: 'expiryTimeBuffer',
    data: encodedExpiry as `0x${string}`,
  }) as unknown as bigint;

  // Get the expired intents from the database (keyed by destination domain);
  const expired = await database.getExpiredIntents(hub.domain, Object.keys(chains), expiry.toString());

  if (expired.length === 0) {
    logger.info('No expired intents to process', requestContext, methodContext);
    return;
  }
  const logCtx = expired.map((e) => ({
    id: e.id,
    ttl: e.ttl,
    timestamp: e.timestamp,
    origin: e.origin,
    destinations: e.destinations,
  }));
  logger.debug('Expired intents', requestContext, methodContext, {
    expired: logCtx,
  });

  if (expired.length == 0) return;

  const data = chainWrapper.encodeFunctionData({
    abi: abis.hub.everclear,
    functionName: 'handleExpiredIntents',
    args: [expired.map((e) => e.id)],
  });
  logger.info('Submitting expired intents to relayer', requestContext, methodContext, {
    intents: logCtx.filter((i) => !!expired.find((f) => f!.id === i.id)),
    transaction: {
      data,
      chain: domainToChainId(hub.domain),
      to: hub.deployments.everclear,
    },
  });

  // Call the `expiredIntents` method on the hub
  const { taskId, relayerType } = await sendWithRelayerWithBackup(
    domainToChainId(hub.domain),
    hub.domain,
    hub.deployments.everclear,
    data,
    '0',
    'handleExpiredIntents(uint256[])',
    relayers,
    chainservice,
    logger,
    requestContext,
  );
  logger.info('Submitted expired settlement to relayer', requestContext, methodContext, {
    taskId,
    relayerType,
    expired: logCtx.filter((i) => !!expired.find((f) => f.id === i.id)),
  });
};
