import { getContext } from '../../context';
import { createLoggingContext, LockPosition } from '@chimera-monorepo/utils';
import { BigNumber } from 'ethers';
import { NewLockPositionZero } from '../../errors/tasks/rewards';

export const NEW_LOCK_POSITIONS_CHECKPOINT = 'lighthouse_rewards_last_processed_new_lock_position_vid';

// Each new lock position represents the latest state of the tokens locked by user:
// - the sum of all locked tokens.
// - the latest expiry timestamp.
// - if the new locked amount is greater than the previous one then the new lock position
//   represents the increase of the lock position.
// - if the new locked amount is the same as the previous one then the new lock position
//   represents extending of the lock period.
// - if the new locked amount is less than the previous one then the new lock position
//   represents early exit (user withdrew locked tokens).
//
// The purpose of this function is to separate lock positions created at different times.
// Each new lock position is processed this way:
// - on lock position increase the function adds lock position with the locked amount equal to
//   the difference between the new total locked amount and the previous one, the expiry of all
//   previous lock positions (if amy) are set to the new expiry.
// - on extending of the lock period the function updates the expiry of all existing lock positions.
// - on early exit removes the earliest lock positions until the total locked amount is equal to
//   the new total locked amount.
export const processNewLockPositions = async (limit: number = 100): Promise<number> => {
  const {
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(processNewLockPositions.name);
  logger.info('Method started', requestContext, methodContext);

  const vid = await database.getCheckPoint(NEW_LOCK_POSITIONS_CHECKPOINT);
  const newLockPositions = await database.getNewLockPositionEvents(vid, limit);
  const newLockPositionCount = newLockPositions.length;
  if (!newLockPositionCount) {
    return 0;
  }

  const lockPositions = new Map<string, LockPosition[]>();
  const totalStakes = new Map<string, BigNumber>();
  for (const newLockPosition of newLockPositions) {
    const user: string = newLockPosition.user;
    const newTotalAmountLocked = BigNumber.from(newLockPosition.newTotalAmountLocked);
    if (!lockPositions.has(user)) {
      const userLockPositions = await database.getLockPositions(user);
      if (!userLockPositions.length) {
        // This is the first lock position ever or the user withdrew all tokens previously.
        if (newTotalAmountLocked.isZero()) {
          const error = new NewLockPositionZero({ user });
          logger.error('invalid new lock position', requestContext, methodContext, error);
          throw error;
        }

        lockPositions.set(user, [
          {
            user,
            amountLocked: newLockPosition.newTotalAmountLocked,
            start: newLockPosition.blockTimestamp,
            expiry: newLockPosition.expiry,
          },
        ]);
        totalStakes.set(user, newTotalAmountLocked);

        continue;
      }

      lockPositions.set(user, userLockPositions);
      const sum = userLockPositions.reduce((sum, pos) => {
        return sum.add(BigNumber.from(pos.amountLocked));
      }, BigNumber.from(0));
      totalStakes.set(user, sum);
    }

    let userTotalStake = totalStakes.get(user)!;
    const userLockPositions = lockPositions.get(user)!;
    if (newTotalAmountLocked.gt(userTotalStake)) {
      // Lock position increased.

      // Find lock positions that starts at the same time.
      const lockIndex = userLockPositions.findIndex((lockPosition: LockPosition) => {
        return lockPosition.user === user && lockPosition.start === newLockPosition.blockTimestamp;
      });
      if (lockIndex >= 0) {
        // Lock position with the same start time found, add newly locked amount to it.
        userLockPositions[lockIndex].amountLocked = BigNumber.from(userLockPositions[lockIndex].amountLocked)
          .add(newTotalAmountLocked.sub(userTotalStake))
          .toString();
      } else {
        // No lock position with the same start time, create new lock position.
        userLockPositions.push({
          user,
          amountLocked: newTotalAmountLocked.sub(userTotalStake).toString(),
          start: newLockPosition.blockTimestamp,
          expiry: newLockPosition.expiry,
        });
      }
    } else if (newTotalAmountLocked.lt(userTotalStake)) {
      // Early exit, remove the earliest lock positions until the total locked amount is equal to
      // the new total locked amount.
      let amountUnlocked = userTotalStake.sub(newTotalAmountLocked);
      let index = 0;
      while (amountUnlocked.gt(0)) {
        const amountLocked = BigNumber.from(userLockPositions[index].amountLocked);
        if (amountUnlocked.gte(amountLocked)) {
          userLockPositions[index++].amountLocked = '0';
          amountUnlocked = amountUnlocked.sub(amountLocked);
        } else {
          userLockPositions[index++].amountLocked = amountLocked.sub(amountUnlocked).toString();
          amountUnlocked = BigNumber.from(0);
        }
      }
    }

    // Update the expiry of all existing and new lock positions.
    // The tokenomics contract implementation guarantees that the expiry can't decrease.
    for (let i = 0; i < userLockPositions.length; ++i) {
      userLockPositions[i].expiry = newLockPosition.expiry;
    }
    lockPositions.set(user, userLockPositions);

    userTotalStake = newTotalAmountLocked;
    totalStakes.set(user, userTotalStake);
  }

  await database.saveLockPositions(
    NEW_LOCK_POSITIONS_CHECKPOINT,
    newLockPositions[newLockPositionCount - 1].vid,
    [...lockPositions.values()].flat(),
  );

  return newLockPositionCount;
};
