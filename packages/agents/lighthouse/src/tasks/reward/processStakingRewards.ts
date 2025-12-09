import { createLoggingContext, LockPosition, TokenStakingReward } from '@chimera-monorepo/utils';
import { APY_MULTIPLIER, MONTH_SECONDS, USD_MULTIPLIER, YEAR_SECONDS } from './constants';
import { HistoricPrice } from './historicPrice';
import { RewardDistributions } from './processRewards';
import { getContext } from '../../context';
import { InvalidAsset, InvalidState } from '../../errors/tasks/rewards';

type StakeMetadata = {
  stakeApyBps: bigint;
  stakeRewards: bigint;
  totalClearStaked: bigint;
};

type StakeMetadatas = {
  [assetAddress: string]: {
    [userAddress: string]: StakeMetadata;
  };
};

export const calculateApy = (assetRewardsConfig: TokenStakingReward, position: LockPosition): number => {
  const lockPeriod = position.expiry - position.start;
  const lockMonths = lockPeriod / MONTH_SECONDS;
  let eligibleApyBps = 0;
  // assetRewardsConfig.apy contains apyBps sorted by term
  for (const apy of assetRewardsConfig.apy) {
    if (lockMonths >= apy.term) {
      eligibleApyBps = apy.apyBps;
    } else {
      break;
    }
  }
  return eligibleApyBps;
};

export const processStakingRewards = async (
  epoch: number,
  epochEnd: number,
  epochDuration: number,
  historicPrice: HistoricPrice,
  rewardDist: RewardDistributions,
) => {
  const {
    config: { chains, hub, rewards: rewardsConfig },
    logger,
    adapters: { database },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(processStakingRewards.name);
  logger.info('Method started', requestContext, methodContext, {
    epoch,
    epochEnd,
    epochDuration,
    rewardDist,
    chains,
    hub,
  });

  const stakingRewardDist: RewardDistributions = {};
  const metadata: StakeMetadatas = {};

  const tokens = rewardsConfig.staking?.tokens ?? [];
  for (const token of tokens) {
    if (!rewardDist[token.address]) {
      rewardDist[token.address] = {};
    }
    if (!stakingRewardDist[token.address]) {
      stakingRewardDist[token.address] = {};
    }
    if (!metadata[token.address]) {
      metadata[token.address] = {};
    }
  }

  const totalClearStaked: {
    [user: string]: bigint;
  } = {};
  // This is sum of lock position * apy;
  const weightedStake: {
    [assetAddress: string]: {
      [userAddress: string]: bigint;
    };
  } = {};

  for (const token of tokens) {
    weightedStake[token.address] = {};
  }

  const users = new Set<string>();
  const positions = await database.getLockPositions(undefined, epoch, epochEnd);
  const assetConfigs = new Map(Object.values(hub.assets ?? {}).map((asset) => [asset.address.toLowerCase(), asset]));
  for (const position of positions) {
    const user = position.user;
    users.add(user);
    if (!totalClearStaked[user]) {
      totalClearStaked[user] = BigInt(0);
    }
    totalClearStaked[user] = totalClearStaked[user] + BigInt(position.amountLocked);
    for (const assetRewardsConfig of tokens) {
      const apy = calculateApy(assetRewardsConfig, position);
      // APY is proportional to how much time the lock position lasts in the epoch.
      const effectiveLockDuration =
        position.expiry > epochEnd
          ? position.start <= epoch
            ? epochDuration
            : epochEnd - position.start
          : position.expiry - epoch;

      // NOTE: apybps is scaled up to account for 3 d.p. of bps
      const multipliedApy = Math.round((apy * effectiveLockDuration * APY_MULTIPLIER) / YEAR_SECONDS);
      // dividing 10000 accounting the multipliedApy is in bps (100% = 10000 bps)
      let positionReward =
        (BigInt(position.amountLocked) * BigInt(multipliedApy)) / (BigInt(APY_MULTIPLIER) * BigInt(10000));
      if (positionReward < BigInt(0)) {
        const error = new InvalidState({
          user,
          asset: assetRewardsConfig.address,
          positionReward,
          apy,
          effectiveLockDuration,
          position,
        });
        logger.error('User have negative position reward', requestContext, methodContext, error, {
          epoch,
        });
        throw error;
      }

      // USD APY conversion for non staking token (CLEAR)
      if (assetRewardsConfig.address != rewardsConfig.clearAssetAddress) {
        // need to do usd calculation for corresponding staking rewards
        const assetConfig = assetConfigs.get(assetRewardsConfig.address);
        if (!assetConfig) {
          const error = new InvalidAsset(assetRewardsConfig.address);
          logger.error('asset config not in hub', requestContext, methodContext, error, {
            epoch,
            assetRewardsConfig,
          });
          throw error;
        }
        const clearConfig = assetConfigs.get(rewardsConfig.clearAssetAddress ?? '');
        if (!clearConfig) {
          const error = new InvalidAsset(assetRewardsConfig.address);
          logger.error('CLEAR config not in hub', requestContext, methodContext, error, {
            epoch,
            rewardsConfig,
          });
          throw error;
        }
        const tokenPrice = await historicPrice.getHistoricTokenPrice(assetConfig, new Date(epochEnd * 1000));
        const clearPrice = await historicPrice.getHistoricTokenPrice(clearConfig, new Date(epochEnd * 1000));
        const scaledTokenPrice = BigInt(Math.round(tokenPrice * USD_MULTIPLIER));
        const scaledClearPrice = BigInt(Math.round(clearPrice * USD_MULTIPLIER));
        // usd reward = equivalent reward in clear * clear price
        // token reward = usd reward / token price; the usd multiplier is cancelled out in the process
        positionReward = (positionReward * scaledClearPrice) / scaledTokenPrice;
      }

      if (!stakingRewardDist[assetRewardsConfig.address][user]) {
        stakingRewardDist[assetRewardsConfig.address][user] = BigInt(0);
      }
      stakingRewardDist[assetRewardsConfig.address][user] =
        stakingRewardDist[assetRewardsConfig.address][user] + positionReward;

      // average APY related computations
      if (!weightedStake[assetRewardsConfig.address][user]) {
        weightedStake[assetRewardsConfig.address][user] = BigInt(0);
      }
      weightedStake[assetRewardsConfig.address][user] =
        weightedStake[assetRewardsConfig.address][user] + BigInt(position.amountLocked) * BigInt(apy);
    }
  }

  for (const token of tokens) {
    let totalStakeRewards = BigInt(0);
    let totalUserClearStaked = BigInt(0);
    for (const user of users) {
      metadata[token.address][user] = {
        stakeApyBps: weightedStake[token.address][user] / totalClearStaked[user],
        stakeRewards: stakingRewardDist[token.address][user],
        totalClearStaked: totalClearStaked[user],
      };
      totalStakeRewards = totalStakeRewards + stakingRewardDist[token.address][user];
      totalUserClearStaked = totalUserClearStaked + totalClearStaked[user];

      // adding stakingRewardDist to the total rewardDist
      if (!rewardDist[token.address][user]) {
        rewardDist[token.address][user] = BigInt(0);
      }
      rewardDist[token.address][user] = rewardDist[token.address][user] + stakingRewardDist[token.address][user];
    }
    const assetConfig = assetConfigs.get(token.address);
    const tokenPrice = await historicPrice.getHistoricTokenPrice(assetConfig!, new Date(epochEnd * 1000));
    const scaledTokenPrice = BigInt(Math.round(tokenPrice * USD_MULTIPLIER));
    logger.info('computed staking rewards for token', requestContext, methodContext, {
      epoch,
      token,
      totalStakeRewards,
      totalUserClearStaked,
      scaledTokenPrice,
    });
  }

  logger.info('computed staking rewards', requestContext, methodContext, { epoch });
  return metadata;
};
