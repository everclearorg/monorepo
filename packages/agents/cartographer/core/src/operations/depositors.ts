import { canonizeId, createLoggingContext, chainWrapper } from '@chimera-monorepo/utils';
import { ReaderCheckpoints } from '@chimera-monorepo/adapters-subgraph';
import { AppContext } from '../context';
import { loadReaderCheckpoints, saveReaderCheckpoints } from './checkpoints';

export const updateDepositors = async (context: AppContext) => {
  const {
    config: {
      chains,
      hub: { domain: hubDomain },
    },
    adapters: { subgraph, database },
    logger,
  } = context;
  const { requestContext, methodContext } = createLoggingContext(updateDepositors.name);
  const spokes = Object.keys(chains);
  const readerTypes = subgraph.getReaderTypes();

  logger.debug('Method start', requestContext, methodContext, {
    hubDomain,
    spokes,
  });

  const depositorResults = await Promise.all(
    spokes.map(async (spoke) => {
      // Retrieve per-reader checkpoints
      const checkpoints = await loadReaderCheckpoints(database, 'depositors', spoke, readerTypes);
      logger.debug('Retrieving depositor data', requestContext, methodContext, {
        spoke,
        checkpoints,
      });
      const [events, newCheckpoints] = await subgraph.getDepositorEventsWithCheckpoints(spoke, checkpoints);
      return { spoke, events: events.map((e) => ({ ...e, domain: spoke })), newCheckpoints };
    }),
  );
  const depositors = depositorResults.map((r) => r.events);
  const updatedCheckpoints: ReaderCheckpoints[] = depositorResults.map((r) => r.newCheckpoints);

  // Save the depositors
  const flat = depositors.flat();
  const ids = Array.from(new Set(flat.map((f) => canonizeId(f.depositor))));
  logger.debug('Saving depositors', requestContext, methodContext, { ids });
  await database.saveDepositors(ids.map((id) => ({ id })));

  // Get the asset hash for each of the entries
  const withAssetHash = flat.map((f) => ({
    ...f,
    assetHash: chainWrapper.keccak256(
      chainWrapper.encodeAbiParameters(
        [{ type: 'address' }, { type: 'uint32' }],
        [f.asset as `0x${string}`, f.domain],
      ),
    ) as string,
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
      asset: canonizeId(f.asset),
      account: canonizeId(f.depositor),
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
      return saveReaderCheckpoints(database, 'depositors', spoke, updatedCheckpoints[idx]);
    }),
  );

  logger.debug('Saved depositors', requestContext, methodContext, { spokes, depositors, updatedCheckpoints });
};

export const updateAssets = async (context: AppContext) => {
  const {
    config: {
      hub: { domain: hubDomain },
    },
    adapters: { subgraph, database },
    logger,
  } = context;
  const { requestContext, methodContext } = createLoggingContext(updateAssets.name);

  logger.debug('Retrieving tokens and asset data', requestContext, methodContext, {
    hubDomain,
  });

  const [tokens, assets] = await subgraph.getTokens(hubDomain);

  await database.saveTokens(tokens);
  await database.saveAssets(assets);

  logger.debug('Saved tokens and assets', requestContext, methodContext, { hubDomain });
};
