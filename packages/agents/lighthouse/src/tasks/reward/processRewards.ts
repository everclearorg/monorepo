/* eslint-disable @typescript-eslint/no-explicit-any */
import { getContext } from '../../context';
import { createLoggingContext, MerkleTree, getNtpTimeSeconds } from '@chimera-monorepo/utils';
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { chainWrapper } from '@chimera-monorepo/utils';
import { InvalidAddressProof, InvalidState } from '../../errors/tasks/rewards';
import { processNewLockPositions } from '../helpers/mockable';
import { processVolumeRewards } from './processVolumeRewards';
import { REWARDS_EPOCH_CHECKPOINT } from './constants';
import { processStakingRewards } from './processStakingRewards';

// RewardDistribution contains the rewards (aggregated) for each address
type RewardDistribution = {
  [address: string]: bigint;
};

// RewardDistributions contains RewardDistribution for each reward asset.
export type RewardDistributions = {
  [assetAddress: string]: RewardDistribution;
};

export const getGenesisEpoch = async (): Promise<number> => {
  const {
    config: { abis, hub },
    adapters: { chainservice },
  } = getContext();
  const encodedData = chainWrapper.encodeFunctionData({
    abi: abis.hub.gauge,
    functionName: 'genesisEpoch',
    args: [],
  });
  const res = await chainservice.readTx(
    {
      to: hub.deployments.gauge,
      domain: +hub.domain,
      data: encodedData,
      funcSig: 'genesisEpoch()',
    },
    'latest',
  );

  const genesisResult = chainWrapper.decodeFunctionResult({
    abi: abis.hub.gauge,
    functionName: 'genesisEpoch',
    data: res as `0x${string}`,
  }) as unknown as bigint;

  return Number(genesisResult);
};

export const getEpochDuration = async (): Promise<number> => {
  const {
    config: { abis, hub },
    adapters: { chainservice },
  } = getContext();
  const encodedData = chainWrapper.encodeFunctionData({
    abi: abis.hub.gauge,
    functionName: 'EPOCH_DURATION',
    args: [],
  });
  const res = await chainservice.readTx(
    {
      to: hub.deployments.gauge,
      domain: +hub.domain,
      data: encodedData,
      funcSig: 'EPOCH_DURATION()',
    },
    'latest',
  );

  const durationResult = chainWrapper.decodeFunctionResult({
    abi: abis.hub.gauge,
    functionName: 'EPOCH_DURATION',
    data: res as `0x${string}`,
  }) as unknown as bigint;

  return Number(durationResult);
};

export const getRewardDistributorUpdateCount = async (assetAddress: string) => {
  const {
    config: { abis, hub },
    adapters: { chainservice },
  } = getContext();
  const encodedData = chainWrapper.encodeFunctionData({
    abi: abis.hub.rewardDistributor,
    functionName: 'rewards',
    args: [assetAddress],
  });
  const res = await chainservice.readTx(
    {
      to: hub.deployments.rewardDistributor,
      domain: +hub.domain,
      data: encodedData,
      funcSig: 'rewards(address)',
    },
    'latest',
  );

  const rewards = chainWrapper.decodeFunctionResult({
    abi: abis.hub.rewardDistributor,
    functionName: 'rewards',
    data: res as `0x${string}`,
  });
  // rewards returns [token, merkleRoot, proof, updateCount]
  // updateCount is at index 3
  return Number((rewards as any[])[3]);
};

export const mergeRewardWithPreviousTree = async (epoch: number, rewardDist: RewardDistributions) => {
  const {
    logger,
    adapters: { database },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(mergeRewardWithPreviousTree.name);

  const previousTrees = await database.getMerkleTrees(epoch);
  for (const previousTree of previousTrees) {
    const asset = previousTree.asset;
    const merkleTree = StandardMerkleTree.load(JSON.parse(previousTree.merkleTree)) as StandardMerkleTree<string[]>;
    if (!rewardDist[asset]) {
      logger.warn(
        'Previous tree contains alternate asset, there is a reward config change in last epoch.',
        requestContext,
        methodContext,
        {
          removedAsset: asset,
          epoch,
        },
      );
      continue;
    }
    for (const [, [address, value]] of merkleTree.entries()) {
      if (!rewardDist[asset][address]) {
        rewardDist[asset][address] = BigInt(0);
      }
      if (BigInt(value) < BigInt(0)) {
        const error = new InvalidState({
          address,
          asset,
          value,
        });
        logger.error('User have negative rewards', requestContext, methodContext, error, {
          epoch,
        });
        throw error;
      }
      rewardDist[asset][address] = rewardDist[asset][address] + BigInt(value);
    }
  }
};

export const processRewards = async () => {
  // Get the config
  const {
    config: { chains, hub, rewards: rewardsConfig },
    logger,
    historicPrice,
    adapters: { database },
  } = getContext();
  // Create logging context
  const { requestContext, methodContext } = createLoggingContext(processRewards.name);
  logger.info('Method started', requestContext, methodContext, { chains, hub });

  let count = 0;
  while ((count = await processNewLockPositions()))
    logger.info('Processed new lock positions', requestContext, methodContext, { count });

  // TODO: data source sanity check
  const epochDuration = await getEpochDuration();
  let epoch = await database.getCheckPoint(REWARDS_EPOCH_CHECKPOINT);
  if (epoch == 0) {
    logger.warn('previous epoch do not exists, using genesis');
    epoch = await getGenesisEpoch();
  } else {
    epoch = epoch + epochDuration;
  }
  const epochEnd = epoch + epochDuration;
  const currentTime = getNtpTimeSeconds();

  // if current is before the middle point in next epoch, we do not consider everything
  // settled and wait until next time.
  if (currentTime < epochEnd + epochDuration / 2) {
    logger.info('current epoch have not come to end, exiting', requestContext, methodContext, {
      currentTime,
      epoch,
      epochEnd,
    });
    return;
  }

  const rewardDist: RewardDistributions = {};
  const volumeMetadata = await processVolumeRewards(epoch, epochEnd, historicPrice, rewardDist);
  logger.info('generated volume rewards', requestContext, methodContext, {
    rewardDist,
    epoch,
  });
  const stakeMetadata = await processStakingRewards(epoch, epochEnd, epochDuration, historicPrice, rewardDist);
  logger.info('generated volume and staking rewards', requestContext, methodContext, {
    rewardDist,
    epoch,
  });
  await mergeRewardWithPreviousTree(epoch, rewardDist);
  logger.info('combined with previous tree', requestContext, methodContext, {
    rewardDist,
    epoch,
  });

  const trees: {
    [address: string]: StandardMerkleTree<string[]>;
  } = {};
  const proofs: {
    [assetAddress: string]: {
      [address: string]: string[];
    };
  } = {};

  const rewardDistributions: MerkleTree[] = [];
  for (const [tokenAddress, tokenRewards] of Object.entries(rewardDist)) {
    const values = Object.entries(tokenRewards)
      .filter(([, accountReward]) => accountReward > BigInt(0))
      .map(([account, reward]) => [account, reward.toString()]);
    if (values.length == 0) {
      logger.warn('no voting / staking activity in epoch, skip the tree computations', requestContext, methodContext, {
        epoch,
        tokenAddress,
      });
      continue;
    }
    if (values.length == 1) {
      // NOTE: as StandardMerkleTree cannot generate proof when there is only one node, we add one empty node in this special case.
      logger.warn('only one leave encountered', requestContext, methodContext, {
        values,
        epoch,
      });
      values.push(['0x0000000000000000000000000000000000000000', '0']);
    }
    const tokenTree = StandardMerkleTree.of(values, ['address', 'uint256']);
    const metadata = {
      timestamp: epoch, // Distribution start timestamp
      updateCount: await getRewardDistributorUpdateCount(tokenAddress), // Update count from rewardDistributor
    };
    const combinedData = `${tokenAddress}${tokenTree.root}${JSON.stringify(metadata)}`;
    const proof = chainWrapper.keccak256(chainWrapper.stringToBytes(combinedData)) as string;

    trees[tokenAddress] = tokenTree;
    rewardDistributions.push({
      asset: tokenAddress,
      root: tokenTree.root,
      proof,
      epochEndTimestamp: new Date(epochEnd * 1000),
      merkleTree: JSON.stringify(tokenTree.dump()),
    });

    const tokenProofs: { [account: string]: string[] } = {};
    // for each account, generate their proof
    for (const [i, v] of tokenTree.entries()) {
      const address = v[0];
      const addressProof = tokenTree.getProof(i);
      if (addressProof.length == 0) {
        const error = new InvalidAddressProof(addressProof, { tokenTree, address });
        logger.error('invalid state', requestContext, methodContext, error, {
          epoch,
        });
        throw error;
      }
      tokenProofs[address] = addressProof;
    }
    proofs[tokenAddress] = tokenProofs;
  }

  logger.info('Generated distributions', requestContext, methodContext, {
    rewardDistributions,
    epoch,
  });
  // TODO: validation

  const epochResults = [];
  const rewards = [];
  for (const user in volumeMetadata.userVolume) {
    for (const domain in volumeMetadata.userVolume[user].epochResult) {
      const clearEmissions =
        rewardsConfig.clearAssetAddress &&
        volumeMetadata.userVolume[user]?.epochResult[domain]?.emissions[rewardsConfig.clearAssetAddress]
          ? volumeMetadata.userVolume[user].epochResult[domain].emissions[rewardsConfig.clearAssetAddress]
          : 0;
      epochResults.push({
        account: user,
        domain: domain,
        userVolume: volumeMetadata.userVolume[user].epochResult[domain].scaledUserVolume.toString(),
        totalVolume: volumeMetadata.totalVolume[domain].toString(),
        clearEmissions: clearEmissions.toString(),
        cumulativeRewards:
          rewardsConfig.clearAssetAddress && rewardDist[rewardsConfig.clearAssetAddress][user]
            ? rewardDist[rewardsConfig.clearAssetAddress][user].toString()
            : '0',
        epochTimestamp: new Date(epoch * 1000),
      });
    }
  }

  for (const [assetAddress, assetRewardDist] of Object.entries(rewardDist)) {
    for (const user in assetRewardDist) {
      const protocolRewards = volumeMetadata.userVolume[user]?.protocolRewards[assetAddress] ?? BigInt(0);
      const stakeRewards = BigInt(stakeMetadata[assetAddress][user]?.stakeRewards?.toString() ?? '0');
      const totalRewards = protocolRewards + stakeRewards;
      const proof = proofs[assetAddress][user];
      if (!proof) {
        const error = new InvalidState({
          user,
          asset: assetAddress,
          volumeMetadata: volumeMetadata.userVolume[user],
          stakeMetadata: stakeMetadata[assetAddress][user],
          protocolRewards,
          stakeRewards,
          totalRewards,
          cumulativeRewards: rewardDist[assetAddress][user],
        });
        logger.error('User must have proof if they have reward distribution', requestContext, methodContext, error, {
          epoch,
        });
        throw error;
      }
      rewards.push({
        account: user,
        asset: assetAddress,
        merkleRoot: trees[assetAddress].root,
        proof: proof,
        stakeApy: stakeMetadata[assetAddress][user]?.stakeApyBps.toString() ?? '0',
        stakeRewards: stakeRewards.toString(),
        totalClearStaked: stakeMetadata[assetAddress][user]?.totalClearStaked.toString() ?? '0',
        protocolRewards: protocolRewards.toString(),
        cumulativeRewards: rewardDist[assetAddress][user].toString(),
        epochTimestamp: new Date(epoch * 1000),
      });
    }
  }
  if (rewardDistributions.length > 0) {
    await database.saveMerkleTrees(rewardDistributions);
  }
  if (epochResults.length > 0) {
    await database.saveEpochResults(epochResults);
  }
  if (rewards.length > 0) {
    await database.saveRewards(rewards);
  }

  logger.info('Saved all data into database', requestContext, methodContext, epoch);

  await database.saveCheckPoint(REWARDS_EPOCH_CHECKPOINT, epoch);

  logger.info('rewards agent completed', requestContext, methodContext, epoch);
};
