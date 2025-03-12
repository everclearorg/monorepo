import { BigNumber, ethers } from 'ethers';
import { getContext } from '../../context';
import { HistoricPrice } from './historicPrice';
import { RewardDistributions } from './processRewards';
import { createLoggingContext, OriginIntent, SettlementIntent } from '@chimera-monorepo/utils';
import { InvalidAsset, InvalidState } from '../../errors/tasks/rewards';
import { DBPS_MULTIPLIER, USD_MULTIPLIER } from './constants';

type EpochResult = {
  scaledUserVolume: BigNumber;
  emissions: {
    [assetAddress: string]: BigNumber;
  };
};

type VolumeMetadata = {
  epochResult: {
    [domain: string]: EpochResult;
  };
  protocolRewards: {
    [assetAddress: string]: BigNumber;
  };
};

type VolumeMetadatas = {
  userVolume: {
    [userAddress: string]: VolumeMetadata;
  };
  totalVolume: {
    [domain: string]: BigNumber;
  };
};

export const processVolumeRewards = async (
  epoch: number,
  epochEnd: number,
  historicPrice: HistoricPrice,
  rewards: RewardDistributions,
) => {
  const {
    config: { chains, hub, rewards: rewardsConfig },
    logger,
    adapters: { database },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(processVolumeRewards.name);
  logger.info('Method started', requestContext, methodContext, { epoch, epochEnd, rewards, chains, hub });

  const metadatas: VolumeMetadatas = {
    userVolume: {},
    totalVolume: {},
  };

  const domainVotes = await database.getVotes(epoch);
  const domainVoteMap: { [domain: string]: string } = {};
  let totalVote = BigNumber.from(0);
  for (const domainVote of domainVotes) {
    totalVote = totalVote.add(domainVote.votes);
    // use string domain to unify usage
    domainVoteMap[`${domainVote.domain}`] = domainVote.votes;
  }
  logger.info('retrieved votes for epoch', requestContext, methodContext, {
    epoch,
    domainVoteMap,
    totalVote,
  });

  const tokens = rewardsConfig.volume?.tokens ?? [];

  const settledIntents: {
    [domain: string]: Map<string, { originIntent: OriginIntent; settlementIntent: SettlementIntent }>;
  } = {};

  const userVolume: {
    [userAddress: string]: VolumeMetadata;
  } = {};

  const totalVolume: {
    [domain: string]: ethers.BigNumber;
  } = {};

  // for each domain, we aggregate volume for each account for each token
  for (const domain in chains) {
    settledIntents[domain] = await database.getSettledIntentsInEpoch(domain, epoch, epochEnd);
    if (settledIntents[domain].size == 0) {
      logger.warn('domain have no settled intent in epoch', requestContext, methodContext, {
        epoch,
        domain,
      });
      continue;
    }
    const accountVolume: {
      [address: string]: BigNumber;
    } = {};
    let totalDomainVolume = BigNumber.from(0);
    const assetConfigs = new Map(
      Object.values(chains[domain].assets ?? {}).map((asset) => [asset.address.toLowerCase(), asset]),
    );

    // For each intent, we calculate the usd volume and sum this to each user and total.
    for (const intent of settledIntents[domain].values()) {
      const settlementAsset = intent.settlementIntent.asset.toLowerCase();
      const asset = assetConfigs.get(settlementAsset);
      if (!asset) {
        const error = new InvalidAsset(settlementAsset, { domain });
        logger.error('invalid asset', requestContext, methodContext, error, { epoch, domain, assetConfigs });
        throw error;
      }

      // USD Volume = intentAmount / AssetDecimals * multipliedUSD / usdMultiplier
      // We collect divisor and only divide once at the end. This will prevent accuracy loss twice.
      const intentAmount = BigNumber.from(intent.settlementIntent.amount);
      const assetDecimals = BigNumber.from(asset.decimals);

      const intentTimestamp = new Date(intent.settlementIntent.timestamp * 1000);
      const assetUsdPrice = await historicPrice.getHistoricTokenPrice(asset, intentTimestamp);
      // scale up the assetPrice by 6 decimals and round for bignum operations.
      // This makes us have 6 d.p. accuracy for price under 9B (9B * 1000000 < 2**53 - 1).
      const multipliedUsdValue = Math.round(assetUsdPrice * USD_MULTIPLIER);

      const assetMultiplier = BigNumber.from(10).pow(assetDecimals);
      const scaledUsdValue = intentAmount.mul(multipliedUsdValue).div(assetMultiplier);

      totalDomainVolume = totalDomainVolume.add(scaledUsdValue);
      // NOTE: intent initiator is stored in 0x + 64 symbols hex form;
      // here we convert that back to 20 bytes as required by the address format
      const initiator = '0x' + intent.originIntent.initiator.slice(26);
      if (accountVolume[initiator]) {
        accountVolume[initiator] = accountVolume[initiator].add(scaledUsdValue);
      } else {
        accountVolume[initiator] = BigNumber.from(scaledUsdValue);
      }
    }
    totalVolume[domain] = totalDomainVolume;

    for (const account in accountVolume) {
      if (!userVolume[account]) {
        userVolume[account] = {
          epochResult: {},
          protocolRewards: {},
        };
      }
      userVolume[account].epochResult[domain] = {
        scaledUserVolume: accountVolume[account],
        emissions: {},
      };
    }
  }
  metadatas.userVolume = userVolume;
  metadatas.totalVolume = totalVolume;
  let totalScaledVolumeAcrossDomain = BigNumber.from(0);
  for (const scaledDomainVolume of Object.values(metadatas.totalVolume)) {
    totalScaledVolumeAcrossDomain = totalScaledVolumeAcrossDomain.add(scaledDomainVolume);
  }

  logger.info('total scaled volume in epoch', requestContext, methodContext, {
    epoch,
    totalVolume,
    totalScaledVolumeAcrossDomain,
  });

  const assetConfigs = new Map(Object.values(hub.assets ?? {}).map((asset) => [asset.address.toLowerCase(), asset]));
  for (const token of tokens) {
    if (totalScaledVolumeAcrossDomain.lte(0)) {
      logger.warn(
        'there is no volume in this epoch, skipping volume rewards calculation',
        requestContext,
        methodContext,
        {
          epoch,
          totalVote,
          token,
          totalVolume,
          totalScaledVolumeAcrossDomain,
        },
      );
      continue;
    }

    // ======== Base rewards ========

    // getting asset price based on epoch end time
    const assetConfig = assetConfigs.get(token.address);
    if (!assetConfig) {
      const error = new InvalidAsset(token.address);
      logger.error('asset config do not exist on hub', requestContext, methodContext, error, {
        epoch,
      });
      throw error;
    }
    const assetMultiplier = BigNumber.from(10).pow(assetConfig.decimals);
    // we use the epochEnd asset price as basis for the base reward
    const assetPrice = await historicPrice.getHistoricTokenPrice(assetConfig, new Date(epochEnd * 1000));
    const scaledAssetPrice = BigNumber.from(Math.round(assetPrice * USD_MULTIPLIER));
    logger.info('calculated epoch end scaled price for token', requestContext, methodContext, {
      epoch,
      scaledAssetPrice,
      token,
    });

    // Initialize rewards pool

    // we calculate the total variable rewards pool by maxBpsUsdVolumeCap and epochVolumeReward in usd
    const scaledEpochVolumeRewardUsd = scaledAssetPrice.mul(token.epochVolumeReward).div(assetMultiplier);
    const scaledMaxVolumeCapUsd = BigNumber.from(token.maxBpsUsdVolumeCap).mul(USD_MULTIPLIER);
    // For now, we round this off using dbps. We might need more precision as this is calculated
    // maximumRewardsDbps = scaledEpochVolumeRewardPrice / scaledMaxVolumeCap * 100000
    const maxRewardsDbps = scaledEpochVolumeRewardUsd.mul(DBPS_MULTIPLIER).div(scaledMaxVolumeCapUsd);

    let baseRewardDbps = BigNumber.from(token.baseRewardDbps);
    let scaledBaseRewardPoolUsd = totalScaledVolumeAcrossDomain.mul(baseRewardDbps).div(DBPS_MULTIPLIER);

    // normally, this would be max rewards dbps * total volume
    let scaledTotalRewardsPoolUsd = maxRewardsDbps.mul(totalScaledVolumeAcrossDomain).div(DBPS_MULTIPLIER);

    // edge case: if base reward pool > epoch volume, we set total pool = base pool = epoch volume and bps accordingly
    if (scaledBaseRewardPoolUsd.gt(scaledEpochVolumeRewardUsd)) {
      scaledTotalRewardsPoolUsd = scaledEpochVolumeRewardUsd;
      scaledBaseRewardPoolUsd = scaledEpochVolumeRewardUsd;
      baseRewardDbps = scaledBaseRewardPoolUsd.mul(DBPS_MULTIPLIER).div(totalScaledVolumeAcrossDomain);
    }

    let scaledVariableRewardsPoolUsd = BigNumber.from(0);
    // variable rewards dbps = max - base
    let variableRewardsDbps = maxRewardsDbps.sub(baseRewardDbps);
    scaledVariableRewardsPoolUsd = scaledTotalRewardsPoolUsd.sub(scaledBaseRewardPoolUsd);

    // edge case: if variable rewards is negative, we force set variable rewards to be zero
    // all rewards will be given out as base rewards
    if (scaledVariableRewardsPoolUsd.lt(0)) {
      variableRewardsDbps = BigNumber.from(0);
      scaledVariableRewardsPoolUsd = BigNumber.from(0);
      scaledTotalRewardsPoolUsd = scaledBaseRewardPoolUsd;
    }

    logger.info('rewards dbps given in this epoch', requestContext, methodContext, {
      epoch,
      token,
      baseRewardDbps,
      variableRewardsDbps,
      maximumRewardsDbps: maxRewardsDbps,
      scaledTotalRewardsPool: scaledTotalRewardsPoolUsd,
      scaledBaseRewardPool: scaledBaseRewardPoolUsd,
      scaledVariableRewardsPool: scaledVariableRewardsPoolUsd,
      scaledAssetPrice,
      totalScaledVolumeAcrossDomain,
    });

    // we calculate the base rewards for each volume generating user by baseRewardDbps
    let totalBaseReward = BigNumber.from(0);

    for (const user in userVolume) {
      let baseReward = BigNumber.from(0);
      for (const epochResult of Object.values(userVolume[user].epochResult)) {
        // For each domain:
        // usdReward  = scaledUserVolume / usdMultiplier * baseRewardsDbps / dbpsMultiplier
        // assetPrice = scaledAssetPrice / usdMultiplier
        // baseReward (in token) = usdReward / assetPrice * assetDecimal
        //                       = scaledUserVolume * baseRewardsDbps * assetDecimal / (dbpsMultiplier * scaledAssetPrice)
        // Note the usdMultiplier is cancelled out in the process
        const divisor = scaledAssetPrice.mul(DBPS_MULTIPLIER);
        const domainBaseReward = epochResult.scaledUserVolume.mul(baseRewardDbps).mul(assetMultiplier).div(divisor);

        if (domainBaseReward.lt(0)) {
          const error = new InvalidState({
            user,
            epochResults: userVolume[user].epochResult,
            epochResult,
            token,
          });
          logger.error('User have negative domain base volume rewards', requestContext, methodContext, error, {
            epoch,
          });
          throw error;
        }

        baseReward = baseReward.add(domainBaseReward);
        epochResult.emissions[token.address] = domainBaseReward;
      }

      userVolume[user].protocolRewards[token.address] = baseReward;

      totalBaseReward = totalBaseReward.add(baseReward);
    }

    // if total base reward > epochvolume, either we have so much volume happening in this
    // epoch (which is too good to be true), or there is something wrong for the token price
    // that either it is an error or it drop to bottom.
    if (totalBaseReward.gt(token.epochVolumeReward)) {
      const error = new InvalidState({
        epoch,
        totalScaledVolumeAcrossDomain,
        scaledMaxVolumeCapUsd,
        scaledEpochVolumeRewardUsd,
        scaledBaseRewardPoolUsd,
        maxRewardsDbps,
        baseRewardDbps,
        totalBaseReward,
        token,
        epochVolumeReward: token.epochVolumeReward,
        userVolume,
      });
      logger.error('unexpected state: base reward greater than epoch reward', requestContext, methodContext, error, {
        epoch,
        totalBaseReward,
        token,
        epochVolumeReward: token.epochVolumeReward,
        userVolume,
      });
      throw error;
    }

    logger.info('calculated base volume rewards for token', requestContext, methodContext, {
      epoch,
      scaledAssetPrice,
      token,
      totalBaseReward,
    });

    // ======== variable rewards ========
    let totalVariableReward = BigNumber.from(0);

    // base case: if we do not have votes, there is no variable rewards
    if (totalVote.lte(0)) {
      logger.warn('there is no votes in this epoch, skipping variable rewards', requestContext, methodContext, {
        epoch,
        totalVote,
        totalBaseReward,
        token,
        totalScaledVolumeAcrossDomain,
      });
    } else {
      for (const user in userVolume) {
        let variableReward = BigNumber.from(0);
        for (const [domain, epochResult] of Object.entries(userVolume[user].epochResult)) {
          // For each domain:
          // chainRewardPercentage = domainVote / totalVote
          // userRewardPercentage = scaledUserVolume / scaledTotalDomainVolume
          // rewardPercentage = chainRewardPercentage * userRewardPercentage
          // variablePool = sacledvariablePoolUsd * asset decimal / scaled asset price
          // variableReward (in token) = variablePool * rewardPercentage
          const divisor = totalVote.mul(totalVolume[domain]).mul(scaledAssetPrice);
          const domainVariableReward = scaledVariableRewardsPoolUsd
            .mul(epochResult.scaledUserVolume)
            .mul(domainVoteMap[domain] ?? 0)
            .mul(assetMultiplier)
            .div(divisor);

          if (domainVariableReward.lt(0)) {
            const error = new InvalidState({
              user,
              domain,
              epochResult: epochResult,
              domainVoteMap,
              totalVote,
              totalVolume: totalVolume[domain],
            });
            logger.error('User have negative domain variable volume rewards', requestContext, methodContext, error, {
              epoch,
            });
            throw error;
          }

          variableReward = variableReward.add(domainVariableReward);

          if (!epochResult.emissions[token.address]) {
            epochResult.emissions[token.address] = BigNumber.from(0);
          }
          epochResult.emissions[token.address] = epochResult.emissions[token.address].add(domainVariableReward);
        }

        userVolume[user].protocolRewards[token.address] =
          userVolume[user].protocolRewards[token.address].add(variableReward);

        totalVariableReward = totalVariableReward.add(variableReward);
      }
    }

    // sanity check
    if (totalBaseReward.add(totalVariableReward).gt(token.epochVolumeReward)) {
      const error = new InvalidState({
        epoch,
        totalScaledVolumeAcrossDomain,
        scaledMaxVolumeCapUsd,
        scaledEpochVolumeRewardUsd,
        scaledBaseRewardPoolUsd,
        maxRewardsDbps,
        baseRewardDbps,
        variableRewardsDbps,
        totalBaseReward,
        token,
        epochVolumeReward: token.epochVolumeReward,
      });
      logger.error('unexpected state: total reward greater than epoch reward', requestContext, methodContext, error, {
        epoch,
        totalBaseReward,
        token,
        epochVolumeReward: token.epochVolumeReward,
      });
      throw error;
    }

    // ======== saving reward results ========
    if (!rewards[token.address]) {
      rewards[token.address] = {};
    }

    for (const user in userVolume) {
      if (!rewards[token.address][user]) {
        rewards[token.address][user] = BigNumber.from(0);
      }
      rewards[token.address][user] = rewards[token.address][user].add(userVolume[user].protocolRewards[token.address]);
    }

    // NOTE: totalVariableReward will have rounding errors as variable rewards per user is calculated
    // as a fraction of the variablesRewardsPool, but totalVariableReward should be very close to variableRewardsPool
    logger.info('computed volume rewards for token', requestContext, methodContext, {
      epoch,
      token,
      scaledAssetPrice,
      totalBaseReward,
      totalVariableReward,
      variableRewardsPool: scaledVariableRewardsPoolUsd,
      totalReward: totalBaseReward.add(totalVariableReward),
      baseRewardDbps: token.baseRewardDbps,
      variableRewardsDbps,
      maximumRewardsDbps: maxRewardsDbps,
      totalScaledVolumeAcrossDomain,
    });
  }

  logger.info('computed volume rewards', requestContext, methodContext, {
    epoch,
  });
  return metadatas;
};
