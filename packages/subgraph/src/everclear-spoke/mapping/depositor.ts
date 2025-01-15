import { BigInt } from '@graphprotocol/graph-ts';
import { Deposited, Withdrawn } from '../../../generated/EverclearSpoke/EverclearSpoke';
import { Balance, DepositorEvent, Depositor } from '../../../generated/schema';
import { generateIdFromTx, generateTxNonce } from '../../common';

/**
 * Creates subgraph records when Deposited events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleDeposited(event: Deposited): void {
  // Create Depositor if not exist
  const account = event.params._depositant;
  let depositor = Depositor.load(account);
  if (depositor == null) {
    depositor = new Depositor(account);
    depositor.save();
  }

  const balanceId = account.concat(event.params._asset);
  let balance = Balance.load(balanceId);
  if (balance == null) {
    balance = new Balance(balanceId);
    balance.account = account;
    balance.asset = event.params._asset;
    balance.amount = new BigInt(0);
  }

  // Update balance amount and save
  balance.amount = balance.amount.plus(event.params._amount);
  balance.save();

  // Save deposit event
  const log = new DepositorEvent(generateIdFromTx(event));

  log.type = 'DEPOSIT';
  log.depositor = account;
  log.asset = event.params._asset;
  log.amount = event.params._amount;
  log.balance = balance.amount;

  log.txOrigin = event.transaction.from;
  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.txNonce = generateTxNonce(event);
  log.gasPrice = event.transaction.gasPrice;
  log.gasLimit = event.transaction.gasLimit;

  log.save();
}

/**
 * Creates subgraph records when Withdrawn events are emitted.
 *
 * @param event - The contract event used to create the subgraph record
 */
export function handleWithdrawn(event: Withdrawn): void {
  const account = event.params._withdrawer;

  let depositor = Depositor.load(account);
  if (depositor == null) {
    depositor = new Depositor(account);
    depositor.save();
  }

  const balanceId = account.concat(event.params._asset);
  let balance = Balance.load(balanceId);
  if (balance == null) {
    balance = new Balance(balanceId);
    balance.account = account;
    balance.asset = event.params._asset;
    balance.amount = new BigInt(0);
  }

  // Update balance amount and save
  balance.amount = balance.amount.minus(event.params._amount);
  balance.save();

  // Save deposit event
  const log = new DepositorEvent(generateIdFromTx(event));

  log.type = 'WITHDRAW';
  log.depositor = account;
  log.asset = event.params._asset;
  log.amount = event.params._amount;
  log.balance = balance.amount;

  log.txOrigin = event.transaction.from;
  log.blockNumber = event.block.number;
  log.timestamp = event.block.timestamp;
  log.transactionHash = event.transaction.hash;
  log.txNonce = generateTxNonce(event);
  log.gasLimit = event.transaction.gasLimit;
  log.gasPrice = event.transaction.gasPrice;

  log.save();
}
