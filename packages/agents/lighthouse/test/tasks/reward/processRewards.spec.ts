import { SinonStub, SinonStubbedInstance, stub, reset, restore, match } from 'sinon';
import { mock, getContextStub } from '../../globalTestHook';
import {
  expect,
  mkBytes32,
  Logger,
  mkAddress,
  getNtpTimeSeconds,
} from '@chimera-monorepo/utils';
import { Interface } from 'ethers/lib/utils';
import { BigNumber, ethers } from 'ethers';
import { ChainService } from '@chimera-monorepo/chainservice';
import {
  getEpochDuration,
  getGenesisEpoch,
  getRewardDistributorUpdateCount,
  processRewards
} from '../../../src/tasks/reward/processRewards';
import { Database } from '@chimera-monorepo/database';
import * as Mockable from '../../../src/tasks/helpers/mockable';
import { HistoricPrice } from "../../../src/tasks/reward/historicPrice";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import testVector from './data/process-rewards-test-vector.json'

function testVectorDateCast(data: object) {
  for (const key in data) {
    if (key === 'epochTimestamp') {
      data[key] = new Date(data[key]);
    } else if (typeof data[key] === 'object' && data[key] !== null) {
      testVectorDateCast(data[key]);
    }
  }
}

describe('#getGenesisEpoch', () => {
  let chainservice: SinonStubbedInstance<ChainService>;
  let encodeFunctionData: SinonStub;
  let decodeFunctionResult: SinonStub;
  const mockGenesis = 1734307200;

  beforeEach(() => {
    chainservice = mock.instances.chainservice() as SinonStubbedInstance<ChainService>;
    chainservice.readTx.resolves('0xencoded');

    encodeFunctionData = stub(Interface.prototype, 'encodeFunctionData');
    encodeFunctionData.returns('0xencoded');
    decodeFunctionResult = stub(Interface.prototype, 'decodeFunctionResult');
    decodeFunctionResult.returns([BigNumber.from(mockGenesis)]);

    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
  });

  afterEach(() => {
    restore();
    reset();
  });

  it('should run without error', async () => {
    await expect(getGenesisEpoch()).to.be.fulfilled;
  });

  it('should return expected result', async () => {
    const genesis = await getGenesisEpoch();
    expect(genesis).to.be.eq(mockGenesis);
  })
});

describe('#getEpochDuration', () => {
  let chainservice: SinonStubbedInstance<ChainService>;
  let encodeFunctionData: SinonStub;
  let decodeFunctionResult: SinonStub;
  const mockDuration = 7200;

  beforeEach(() => {
    chainservice = mock.instances.chainservice() as SinonStubbedInstance<ChainService>;
    chainservice.readTx.resolves('0xencoded');

    encodeFunctionData = stub(Interface.prototype, 'encodeFunctionData');
    encodeFunctionData.returns('0xencoded');
    decodeFunctionResult = stub(Interface.prototype, 'decodeFunctionResult');
    decodeFunctionResult.returns([BigNumber.from(mockDuration)]);
    
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
  });

  afterEach(() => {
    restore();
    reset();
  });

  it('should run without error', async () => {
    await expect(getEpochDuration()).to.be.fulfilled;
  });

  it('should return expected result', async () => {
    const duration = await getEpochDuration();
    expect(duration).to.be.eq(mockDuration);
  })
});

describe('#getRewardDistributorUpdateCount', () => {
  let chainservice: SinonStubbedInstance<ChainService>;
  let encodeFunctionData: SinonStub;
  let decodeFunctionResult: SinonStub;
  const mockUpdateCount = 25;

  beforeEach(() => {
    chainservice = mock.instances.chainservice() as SinonStubbedInstance<ChainService>;
    chainservice.readTx.resolves('0xencoded');

    encodeFunctionData = stub(Interface.prototype, 'encodeFunctionData');
    encodeFunctionData.returns('0xencoded');
    decodeFunctionResult = stub(Interface.prototype, 'decodeFunctionResult');
    decodeFunctionResult.returns({
      token: '0x',
      merkleRoot: '0x',
      proof: '0x',
      updateCount: mockUpdateCount
    });

    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
  });

  afterEach(() => {
    restore();
    reset();
  });

  it('should run without error', async () => {
    await expect(getRewardDistributorUpdateCount('0x000000000000000000000000000000000000000000001111')).to.be.fulfilled;
  });

  it('should return expected result', async () => {
    const duration = await getRewardDistributorUpdateCount('0x000000000000000000000000000000000000000000001111');
    expect(duration).to.be.eq(mockUpdateCount);
  })
});

describe('#processRewards', () => {
  let chainservice: SinonStubbedInstance<ChainService>;
  let logger: SinonStubbedInstance<Logger>;
  let database: SinonStubbedInstance<Database>;
  let historicPrice: SinonStubbedInstance<HistoricPrice>;
  let encodeFunctionData: SinonStub;
  let decodeFunctionResult: SinonStub;
  let processNewLockPositionsStub: SinonStub;

  const genesisEpoch = 1734307200;
  const epochDuration = 7200;
  const rewardDistributorUpdateCount = 25;

  const setup = (data: object) => {
    database.getCheckPoint.resolves(data.epoch);
    database.getVotes.resolves(data.votes);
    database.getLockPositions.resolves(data.lockPositions);
    database.getMerkleTrees.resolves(data.previousMerkleTrees);
    const settledIntents = new Map(data.settledIntents.map((domain) => [domain.domain, new Map(domain.intents.map((intent) => [mkBytes32(`0x${intent.id}`), {
      originIntent: mock.originIntent({ initiator: intent.initiator }),
      settlementIntent: mock.settlementIntent({ asset: intent.asset, amount: intent.amount, timestamp: intent.timestamp }),
    }]))]));
    for (const [domain, intents] of settledIntents) {
      database.getSettledIntentsInEpoch.withArgs(domain).resolves(intents);
    }
  }

  const processRewardsTest = async (data: object) => {
    setup(data);

    await processRewards();

    if (data.epochResults.length) {
      expect(database.saveEpochResults.calledWith(match(data.epochResults)), "epochResult do not match").to.be.true;
    } else {
      expect(database.saveEpochResults.notCalled, "no epochResult should be saved").to.be.true;
    }

    const merkleTreesMap = new Map();
    if (data.merkleTrees.length) {
      const merkleTrees = [];
      for (const item of data.merkleTrees) {
        const merkleTree = StandardMerkleTree.of(item.rewards, ['address', 'uint256']);
        merkleTreesMap.set(item.token, merkleTree);
        const combinedData = `${item.token}${merkleTree.root}${JSON.stringify({ timestamp: data.epoch + epochDuration, updateCount: rewardDistributorUpdateCount })}`;
        const proof = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(combinedData));
        merkleTrees.push({
          asset: item.token,
          root: merkleTree.root,
          proof,
          epochEndTimestamp: new Date((data.epoch + 2 * epochDuration) * 1000),
          merkleTree: JSON.stringify(merkleTree.dump()),
        });
      }
      if (!database.saveMerkleTrees.calledWith(match(merkleTrees))) {
        console.log('DEBUG', database.saveMerkleTrees.getCall(0).firstArg);
      }
      expect(database.saveMerkleTrees.calledWith(match(merkleTrees)), "merkle trees do not match").to.be.true;
    } else {
      expect(database.saveMerkleTrees.notCalled, "no merkle tree should be saved").to.be.true;
    }

    if (data.rewards.length) {
      for (const item of data.rewards) {
        const merkleTree = merkleTreesMap.get(item.asset);
        item.merkleRoot = merkleTree.root;
        for (const [i, v] of merkleTree.entries()) {
          if (v[0] === item.account) {
            item.proof = merkleTree.getProof(i);
            break;
          }
        }
      }
      if (!database.saveRewards.calledWith(match(data.rewards))) {
        console.log("invalid....", database.saveRewards.getCall(0).firstArg)
      }
      expect(database.saveRewards.calledWith(match(data.rewards)), "rewards do not match").to.be.true;
    } else {
      expect(database.saveRewards.notCalled, "no rewards should be saved").to.be.true;
    }
  }

  const processRewardsFailureTest = async (data: object, err: string) => {
    setup(data);

    await expect(processRewards()).to.be.rejectedWith(err);
  }

  before(() => {
    testVectorDateCast(testVector);
  });

  beforeEach(() => {
    chainservice = mock.instances.chainservice() as SinonStubbedInstance<ChainService>;
    chainservice.readTx.resolves('0xencoded');
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    processNewLockPositionsStub = stub(Mockable, 'processNewLockPositions').resolves(0);
    historicPrice = mock.instances.historicPrice() as SinonStubbedInstance<HistoricPrice>;
    historicPrice.getHistoricTokenPrice.resolves(2000);

    encodeFunctionData = stub(Interface.prototype, 'encodeFunctionData');
    encodeFunctionData.returns('0xencoded');
    decodeFunctionResult = stub(Interface.prototype, 'decodeFunctionResult');
    decodeFunctionResult.withArgs('genesisEpoch').returns([BigNumber.from(genesisEpoch)]);
    decodeFunctionResult.withArgs('EPOCH_DURATION').returns([BigNumber.from(epochDuration)]);
    decodeFunctionResult.withArgs('rewards').returns({
      token: '',
      merkleRoot: '',
      proof: '',
      updateCount: rewardDistributorUpdateCount
    });

    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('should work', () => {
    it('no volume and stake', async () => {
      await processRewardsTest(testVector.noVolumeAndStake);
    });

    it('volume and stake rewards', async () => {
      await processRewardsTest(testVector.volumeAndStakeRewards);
    });

    it('epoch is not yet ended', async () => {
      testVector.epochNotEnded.epoch = getNtpTimeSeconds();
      await processRewardsTest(testVector.epochNotEnded);
    });

    describe('volume rewards only', () => {
      it('no votes', async () => {
        await processRewardsTest(testVector.volumeRewardsOnly.noVotes);
      });

      it('with votes', async () => {
        await processRewardsTest(testVector.volumeRewardsOnly.withVotes);
      });
    });

    describe('stake rewards only', () => {
      it('full epoch stake', async () => {
        await processRewardsTest(testVector.stakeRewardsOnly.fullEpochStake);
      });

      it('partial epoch stake', async () => {
        await processRewardsTest(testVector.stakeRewardsOnly.partialEpochStake);
      });

      it('multiple lock positions', async () => {
        await processRewardsTest(testVector.stakeRewardsOnly.multipleLockPositions);
      });

    });
  });

  describe('should fail', () => {
    it('not supported asset', async () => {
      await processRewardsFailureTest(testVector.failures.invalidAssetInIntent, 'Invalid asset');
    });

    it('volume reward asset is not configured', async () => {
      const volumeTokenConfig = mock.config().rewards.volume.tokens[0];
      const volumeTokenAddress = volumeTokenConfig.address;
      volumeTokenConfig.address = mkAddress('0x111');

      await processRewardsFailureTest(testVector.failures.volumeAssetIsNotConfigured, 'Invalid asset');

      volumeTokenConfig.address = volumeTokenAddress;
    });

    it('base volume reward is greater than epoch volume reward', async () => {
      const volumeTokenConfig = mock.config().rewards.volume.tokens[0];
      const epochVolumeReward = volumeTokenConfig.epochVolumeReward;
      volumeTokenConfig.epochVolumeReward = '10';

      await processRewardsFailureTest(testVector.failures.baseRewardGreaterThanEpochReward, 'Invalid calculation state');

      volumeTokenConfig.epochVolumeReward = epochVolumeReward;
    });

    it('staking reward asset is not configured', async () => {
      let stakingTokenConfigs = mock.config().rewards.staking.tokens;
      const configCount = stakingTokenConfigs.length;
      stakingTokenConfigs.push(
        {
          address: mkAddress('0x222'),
          apy: [],
        },
      );

      await processRewardsFailureTest(testVector.failures.stakingAssetIsNotConfigured, 'Invalid asset');

      mock.config().rewards.staking.tokens = stakingTokenConfigs.slice(0, configCount);
    });

    it('CLEAR asset is not configured', async () => {
      let rewardsConfig = mock.config().rewards;
      const clearAssetAddress = rewardsConfig.clearAssetAddress;
      rewardsConfig.clearAssetAddress = mkAddress('0x333');

      await processRewardsFailureTest(testVector.failures.clearAssetIsNotConfigured, 'Invalid asset');

      rewardsConfig.clearAssetAddress = clearAssetAddress;
    });
  });
})
