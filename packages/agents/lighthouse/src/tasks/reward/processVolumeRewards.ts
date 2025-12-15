import { getContext } from '../../context';
import { HistoricPrice } from './historicPrice';
import { RewardDistributions } from './processRewards';
import { createLoggingContext, OriginIntent, SettlementIntent } from '@chimera-monorepo/utils';
import { InvalidAsset, InvalidState } from '../../errors/tasks/rewards';
import { DBPS_MULTIPLIER, USD_MULTIPLIER } from './constants';

type EpochResult = {
  scaledUserVolume: bigint;
  emissions: {
    [assetAddress: string]: bigint;
  };
};

type VolumeMetadata = {
  epochResult: {
    [domain: string]: EpochResult;
  };
  protocolRewards: {
    [assetAddress: string]: bigint;
  };
};

type VolumeMetadatas = {
  userVolume: {
    [userAddress: string]: VolumeMetadata;
  };
  totalVolume: {
    [domain: string]: bigint;
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
  let totalVote = BigInt(0);
  for (const domainVote of domainVotes) {
    totalVote = totalVote + BigInt(domainVote.votes);
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
    [domain: string]: bigint;
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
      [address: string]: bigint;
    } = {};
    let totalDomainVolume = BigInt(0);
    const assetConfigs = new Map(
      Object.values(chains[domain].assets ?? {}).map((asset) => [asset.address.toLowerCase(), asset]),
    );

    // For each intent, we calculate the usd volume and sum this to each user and total.
    for (const intent of settledIntents[domain].values()) {
      const settlementAsset = intent.settlementIntent.asset.toLowerCase();
      const asset = assetConfigs.get(settlementAsset);
      if (!asset) {
        const error = new InvalidAsset(settlementAsset, { domain, epoch, assetConfigs });
        logger.warn('invalid asset', requestContext, methodContext, error);
        // We skip invalid assets in calculation as there could be intents fired with unsupported status
        continue;
      }

      // USD Volume = intentAmount / AssetDecimals * multipliedUSD / usdMultiplier
      // We collect divisor and only divide once at the end. This will prevent accuracy loss twice.
      const intentAmount = BigInt(intent.settlementIntent.amount);
      const assetDecimals = BigInt(asset.decimals);

      const intentTimestamp = new Date(intent.settlementIntent.timestamp * 1000);
      const assetUsdPrice = await historicPrice.getHistoricTokenPrice(asset, intentTimestamp);
      // scale up the assetPrice by 6 decimals and round for bignum operations.
      // This makes us have 6 d.p. accuracy for price under 9B (9B * 1000000 < 2**53 - 1).
      const multipliedUsdValue = Math.round(assetUsdPrice * USD_MULTIPLIER);

      const assetMultiplier = BigInt(10) ** BigInt(assetDecimals);
      const scaledUsdValue = (intentAmount * BigInt(multipliedUsdValue)) / assetMultiplier;

      totalDomainVolume = totalDomainVolume + scaledUsdValue;
      // NOTE: intent initiator is stored in 0x + 64 symbols hex form;
      // here we convert that back to 20 bytes as required by the address format
      const initiator = '0x' + intent.originIntent.initiator.slice(26);
      if (accountVolume[initiator]) {
        accountVolume[initiator] = accountVolume[initiator] + scaledUsdValue;
      } else {
        accountVolume[initiator] = scaledUsdValue;
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
  let totalScaledVolumeAcrossDomain = BigInt(0);
  for (const scaledDomainVolume of Object.values(metadatas.totalVolume)) {
    totalScaledVolumeAcrossDomain = totalScaledVolumeAcrossDomain + scaledDomainVolume;
  }

  logger.info('total scaled volume in epoch', requestContext, methodContext, {
    epoch,
    totalVolume,
    totalScaledVolumeAcrossDomain,
  });

  const assetConfigs = new Map(Object.values(hub.assets ?? {}).map((asset) => [asset.address.toLowerCase(), asset]));
  for (const token of tokens) {
    if (totalScaledVolumeAcrossDomain <= BigInt(0)) {
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
    const assetMultiplier = BigInt(10) ** BigInt(assetConfig.decimals);
    // we use the epochEnd asset price as basis for the base reward
    const assetPrice = await historicPrice.getHistoricTokenPrice(assetConfig, new Date(epochEnd * 1000));
    const scaledAssetPrice = BigInt(Math.round(assetPrice * USD_MULTIPLIER));
    logger.info('calculated epoch end scaled price for token', requestContext, methodContext, {
      epoch,
      scaledAssetPrice,
      token,
    });

    // Initialize rewards pool

    // we calculate the total variable rewards pool by maxBpsUsdVolumeCap and epochVolumeReward in usd
    const scaledEpochVolumeRewardUsd = (scaledAssetPrice * BigInt(token.epochVolumeReward)) / assetMultiplier;
    const scaledMaxVolumeCapUsd = BigInt(token.maxBpsUsdVolumeCap) * BigInt(USD_MULTIPLIER);
    // For now, we round this off using dbps. We might need more precision as this is calculated
    // maximumRewardsDbps = scaledEpochVolumeRewardPrice / scaledMaxVolumeCap * 100000
    const maxRewardsDbps = (scaledEpochVolumeRewardUsd * BigInt(DBPS_MULTIPLIER)) / scaledMaxVolumeCapUsd;

    let baseRewardDbps = BigInt(token.baseRewardDbps);
    let scaledBaseRewardPoolUsd = (totalScaledVolumeAcrossDomain * baseRewardDbps) / BigInt(DBPS_MULTIPLIER);

    // normally, this would be max rewards dbps * total volume
    let scaledTotalRewardsPoolUsd = (maxRewardsDbps * totalScaledVolumeAcrossDomain) / BigInt(DBPS_MULTIPLIER);

    // edge case: if base reward pool > epoch volume, we set total pool = base pool = epoch volume and bps accordingly
    if (scaledBaseRewardPoolUsd > scaledEpochVolumeRewardUsd) {
      scaledTotalRewardsPoolUsd = scaledEpochVolumeRewardUsd;
      scaledBaseRewardPoolUsd = scaledEpochVolumeRewardUsd;
      baseRewardDbps = (scaledBaseRewardPoolUsd * BigInt(DBPS_MULTIPLIER)) / totalScaledVolumeAcrossDomain;
    }

    let scaledVariableRewardsPoolUsd = BigInt(0);
    // variable rewards dbps = max - base
    let variableRewardsDbps = maxRewardsDbps - baseRewardDbps;
    scaledVariableRewardsPoolUsd = scaledTotalRewardsPoolUsd - scaledBaseRewardPoolUsd;

    // edge case: if variable rewards is negative, we force set variable rewards to be zero
    // all rewards will be given out as base rewards
    if (scaledVariableRewardsPoolUsd < BigInt(0)) {
      variableRewardsDbps = BigInt(0);
      scaledVariableRewardsPoolUsd = BigInt(0);
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
    let totalBaseReward = BigInt(0);

    for (const user in userVolume) {
      let baseReward = BigInt(0);
      for (const epochResult of Object.values(userVolume[user].epochResult)) {
        // For each domain:
        // usdReward  = scaledUserVolume / usdMultiplier * baseRewardsDbps / dbpsMultiplier
        // assetPrice = scaledAssetPrice / usdMultiplier
        // baseReward (in token) = usdReward / assetPrice * assetDecimal
        //                       = scaledUserVolume * baseRewardsDbps * assetDecimal / (dbpsMultiplier * scaledAssetPrice)
        // Note the usdMultiplier is cancelled out in the process
        const divisor = scaledAssetPrice * BigInt(DBPS_MULTIPLIER);
        const domainBaseReward = (epochResult.scaledUserVolume * baseRewardDbps * assetMultiplier) / divisor;

        if (domainBaseReward < BigInt(0)) {
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

        baseReward = baseReward + domainBaseReward;
        epochResult.emissions[token.address] = domainBaseReward;
      }

      userVolume[user].protocolRewards[token.address] = baseReward;

      totalBaseReward = totalBaseReward + baseReward;
    }

    // if total base reward > epochvolume, either we have so much volume happening in this
    // epoch (which is too good to be true), or there is something wrong for the token price
    // that either it is an error or it drop to bottom.
    if (totalBaseReward > BigInt(token.epochVolumeReward)) {
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
    let totalVariableReward = BigInt(0);

    // base case: if we do not have votes, there is no variable rewards
    if (totalVote <= BigInt(0)) {
      logger.warn('there is no votes in this epoch, skipping variable rewards', requestContext, methodContext, {
        epoch,
        totalVote,
        totalBaseReward,
        token,
        totalScaledVolumeAcrossDomain,
      });
    } else {
      for (const user in userVolume) {
        let variableReward = BigInt(0);
        for (const [domain, epochResult] of Object.entries(userVolume[user].epochResult)) {
          // For each domain:
          // chainRewardPercentage = domainVote / totalVote
          // userRewardPercentage = scaledUserVolume / scaledTotalDomainVolume
          // rewardPercentage = chainRewardPercentage * userRewardPercentage
          // variablePool = sacledvariablePoolUsd * asset decimal / scaled asset price
          // variableReward (in token) = variablePool * rewardPercentage
          const divisor = totalVote * totalVolume[domain] * scaledAssetPrice;
          const domainVariableReward =
            (scaledVariableRewardsPoolUsd *
              epochResult.scaledUserVolume *
              BigInt(domainVoteMap[domain] ?? '0') *
              assetMultiplier) /
            divisor;

          if (domainVariableReward < BigInt(0)) {
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

          variableReward = variableReward + domainVariableReward;

          if (!epochResult.emissions[token.address]) {
            epochResult.emissions[token.address] = BigInt(0);
          }
          epochResult.emissions[token.address] = epochResult.emissions[token.address] + domainVariableReward;
        }

        userVolume[user].protocolRewards[token.address] =
          userVolume[user].protocolRewards[token.address] + variableReward;

        totalVariableReward = totalVariableReward + variableReward;
      }
    }

    // sanity check
    if (totalBaseReward + totalVariableReward > BigInt(token.epochVolumeReward)) {
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
      const userProtocolRewards = userVolume[user].protocolRewards[token.address];
      // skip user with no protocol rewards. This way rewards map will always reward positive entries
      if (userProtocolRewards <= BigInt(0)) {
        continue;
      }
      if (!rewards[token.address][user]) {
        rewards[token.address][user] = BigInt(0);
      }
      rewards[token.address][user] = rewards[token.address][user] + userProtocolRewards;
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
      totalReward: totalBaseReward + totalVariableReward,
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
