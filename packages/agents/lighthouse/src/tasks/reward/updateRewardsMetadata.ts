import { createLoggingContext, sendAlerts, Severity } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { Interface } from 'ethers/lib/utils';
import { UpdateRewardsMetadataTxFailure } from '../../errors/tasks/rewards';

const REWARDS_METADATA_UPDATE_CHECKPOINT = 'rewards_metadata_update_epoch';

export const updateRewardsMetadata = async () => {
  // Get the config
  const {
    config,
    logger,
    adapters: { wallet, safeservice, database },
  } = getContext();

  // Create logging context
  const { requestContext, methodContext } = createLoggingContext(updateRewardsMetadata.name);
  logger.info('Method started', requestContext, methodContext, {
    hub: config.hub,
    rewardDistributor: config.abis.hub.rewardDistributor,
  });

  // Get the latest rewards merkle trees
  const lastEpochEnd = await database.getCheckPoint(REWARDS_METADATA_UPDATE_CHECKPOINT);
  const volumeTokenConfigs = config.rewards.volume?.tokens ?? [];
  const stakingTokenConfigs = config.rewards.staking?.tokens ?? [];
  const tokens = new Set<string>();
  volumeTokenConfigs
    .map((config) => config.address)
    .concat(stakingTokenConfigs.map((config) => config.address))
    .forEach((token) => tokens.add(token));
  const rewardDistributions = (
    await Promise.all(
      [...tokens].map(async (token) => {
        return await database.getLatestMerkleTree(token, lastEpochEnd);
      }),
    )
  ).flat();

  if (!rewardDistributions.length) {
    logger.info('no new metadata found', requestContext, methodContext);
    return;
  }

  // Dispatch updateRewardsMetadata tx
  const iface = new Interface(config.abis.hub.rewardDistributor);
  const encodedData = iface.encodeFunctionData('updateRewardsMetadata', [
    rewardDistributions.map((dist) => {
      return {
        token: dist.asset,
        merkleRoot: dist.root,
        proof: dist.proof,
      };
    }),
  ]);
  const tx = {
    from: await wallet.getAddress(),
    to: config.hub.deployments.rewardDistributor,
    data: encodedData,
    domain: +config.hub.domain,
    value: '0',
  };
  try {
    const txHash = await safeservice.proposeTransaction(tx, requestContext);
    const epochEnd = Math.max(...rewardDistributions.map((dist) => dist.epochEndTimestamp.getTime()));
    await database.saveCheckPoint(REWARDS_METADATA_UPDATE_CHECKPOINT, epochEnd);
    logger.info('proposed rewards metadata update tx', requestContext, methodContext, { epochEnd, txHash });

    const report = {
      severity: Severity.Informational,
      type: 'RewardsMetadataUpdateTxProposed',
      ids: [txHash],
      reason: `Proposed rewards metadata update tx`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };
    await sendAlerts(report, logger, config, requestContext);
  } catch (err) {
    const error = new UpdateRewardsMetadataTxFailure((err as Error).message);
    logger.error('Update rewards metadata tx failed', requestContext, methodContext, error);
    throw error;
  }
};
