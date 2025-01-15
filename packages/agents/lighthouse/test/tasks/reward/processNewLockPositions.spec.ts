import { Database } from '@chimera-monorepo/database/src';
import { restore, reset, SinonStubbedInstance, match } from 'sinon';
import { mock } from '../../globalTestHook';
import { expect, mkBytes32, Logger } from '@chimera-monorepo/utils';
import { processNewLockPositions } from '../../../src/tasks/helpers/mockable';
import { NEW_LOCK_POSITIONS_CHECKPOINT } from '../../../src/tasks/reward';
import testVector from './data/process-new-lock-positions-test-vector.json'

describe('#processNewLockPositions', () => {
  let database: SinonStubbedInstance<Database>;
  let logger: SinonStubbedInstance<Logger>;

  beforeEach(() => {
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
    database = mock.instances.database() as SinonStubbedInstance<Database>;
    database.getCheckPoint.resolves(1);
  });

  afterEach(() => {
    restore();
    reset();
  });

  const defaultStart = 1_733_405_000;
  const defaultExpiry = 1_735_997_000;

  const processNewLockPositionsTest = async (data: object) => {
    const lockPositions = data.lockPositions.reduce((map, pos) => {
      if (!map.has(pos.user)) {
        map.set(pos.user, [pos]);
      } else {
        map.get(pos.user).push(pos);
      }
      return map;
    }, new Map());
    const users = data.newLockPositionEvents.reduce((usrs, event) => {
      usrs.add(event.user);
      return usrs;
    }, new Set());
    if (users.size) {
      users.forEach((user) => {
        database.getLockPositions.withArgs(user).resolves(lockPositions.has(user) ? lockPositions.get(user) : []);
      });
    } else {
      database.getLockPositions.resolves([]);
    }
    database.getNewLockPositionEvents.resolves(data.newLockPositionEvents);

    const newLockPositionCount = await processNewLockPositions();

    expect(newLockPositionCount).to.be.eq(data.newLockPositionCount);
    if (data.expectedLockPositions.length) {
      expect(database.saveLockPositions.calledWith(match(NEW_LOCK_POSITIONS_CHECKPOINT), match(data.checkPoint), match(data.expectedLockPositions))).to.be.true;
    } else {
      expect(database.saveLockPositions.called).to.be.false;
    }
  }

  describe('should fail', () => {
    it('first new lock position is zero', async () => {
      database.getNewLockPositionEvents.resolves([{
        vid: 2,
        user: mkBytes32('0x1'),
        newTotalAmountLocked: '0',
        blockTimestamp: defaultStart,
        expiry: defaultExpiry,
      }]);
      database.getLockPositions.resolves([]);

      await expect(processNewLockPositions()).to.be.rejectedWith('First new lock position is zero');
    });
  });

  describe('should work', () => {
    it('no new lock positions', async () => {
      await processNewLockPositionsTest(testVector.noNewLockPositions);
    });

    describe('single user', () => {
      it('first lock', async () => {
        await processNewLockPositionsTest(testVector.singleUser.firstLock);
      });

      it('extend lock period', async () => {
        await processNewLockPositionsTest(testVector.singleUser.extendLockPeriod);
      });

      it('add new lock', async () => {
        await processNewLockPositionsTest(testVector.singleUser.addNewLock);
      });

      it('partial exit early', async () => {
        await processNewLockPositionsTest(testVector.singleUser.partialExitEarly);
      });

      it('full exit early', async () => {
        await processNewLockPositionsTest(testVector.singleUser.fullExitEarly);
      });
    });

    describe('multiple users', () => {
      it('first lock', async () => {
        await processNewLockPositionsTest(testVector.multipleUsers.firstLock);
      });

      it('extend lock period', async () => {
        await processNewLockPositionsTest(testVector.multipleUsers.extendLockPeriod);
      });

      it('add new locks', async () => {
        await processNewLockPositionsTest(testVector.multipleUsers.addNewLocks);
      });

      it('exit early', async () => {
        await processNewLockPositionsTest(testVector.multipleUsers.exitEarly);
      });

      it('mixed add lock / extend lock period / exit early', async () => {
        await processNewLockPositionsTest(testVector.multipleUsers.mix);
      });
    });
  });
});
