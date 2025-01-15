import { canonizeId, createLoggingContext, getMaxTxNonce } from '@chimera-monorepo/utils';

import { getContext } from '../../shared';
import { hexlify, solidityKeccak256 } from 'ethers/lib/utils';

export const updateDepositors = async () => {
  const {
    config: {
      chains,
      hub: { domain: hubDomain },
    },
    adapters: { subgraph, database },
    logger,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateDepositors.name);
  const spokes = Object.keys(chains);

  logger.debug('Method start', requestContext, methodContext, {
    hubDomain,
    spokes,
  });

  const depositors = await Promise.all(
    spokes.map(async (spoke) => {
      // Retrieve the most recent tx nonce
      const latestTxNonce = await database.getCheckPoint('depositors_' + spoke);
      logger.debug('Retrieving depositor data', requestContext, methodContext, {
        spoke,
        latestTxNonce,
      });
      const events = await subgraph.getDepositorEvents(spoke, latestTxNonce);
      return events.map((e) => ({ ...e, domain: spoke }));
    }),
  );
  const updatedCheckpoints = depositors.map((depositor) => {
    return getMaxTxNonce(depositor);
  });

  // Save the depositors
  const flat = depositors.flat();
  const ids = Array.from(new Set(flat.map((f) => hexlify(canonizeId(f.depositor)))));
  logger.debug('Saving depositors', requestContext, methodContext, { ids });
  await database.saveDepositors(ids.map((id) => ({ id })));

  // Get the asset hash for each of the entries
  const withAssetHash = flat.map((f) => ({
    ...f,
    assetHash: solidityKeccak256(['address', 'uint32'], [f.asset, f.domain]),
  }));

  // Only take the latest event for each asset hash
  const uniqueAssetHashes = Array.from(new Set(withAssetHash.map((f) => f.assetHash)));
  const latestEvents = uniqueAssetHashes.map((hash) => {
    return withAssetHash.filter((f) => f.assetHash === hash).sort((a, b) => b.timestamp - a.timestamp)[0];
  });

  const balances = latestEvents.map((f) => {
    return {
      ...f,
      id: f.assetHash,
      asset: hexlify(canonizeId(f.asset)),
      account: hexlify(canonizeId(f.depositor)),
    };
  });
  logger.debug('Saving balances', requestContext, methodContext, { balances });
  await database.saveBalances(balances);

  await Promise.all(
    spokes.map((spoke, idx) => {
      if (depositors[idx].length === 0) {
        // dont save checkpoint
        return;
      }
      return database.saveCheckPoint('depositors_' + spoke, updatedCheckpoints[idx]);
    }),
  );

  logger.debug('Saved depositors', requestContext, methodContext, { spokes, depositors, updatedCheckpoints });
};

export const updateAssets = async () => {
  const {
    config: {
      hub: { domain: hubDomain },
    },
    adapters: { subgraph, database },
    logger,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateAssets.name);

  logger.debug('Retrieving tokens and asset data', requestContext, methodContext, {
    hubDomain,
  });

  const [tokens, assets] = await subgraph.getTokens(hubDomain);

  await database.saveTokens(tokens);
  await database.saveAssets(assets);

  logger.debug('Saved tokens and assets', requestContext, methodContext, { hubDomain });
};
