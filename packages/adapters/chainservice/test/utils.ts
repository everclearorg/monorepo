import { BigNumber, utils } from 'ethers';
import { mock, mkAddress } from '@chimera-monorepo/utils';
import { stub } from 'sinon';
import { OnchainTransaction, ReadTransaction, WriteTransaction } from '../src/shared';

export const TEST_SENDER_CHAIN_ID = 1337;
export const TEST_SENDER_DOMAIN = 1337;
export const DEFAULT_GAS_LIMIT = BigNumber.from('21004');

export const TEST_REQUEST_CONTEXT = mock.log.requestContext();
export const TEST_ERROR = new Error('test');

export const TEST_READ_TX: ReadTransaction = {
  domain: TEST_SENDER_DOMAIN,
  to: mkAddress('0xaaa'),
  data: '0x',
};

export const TEST_TX: WriteTransaction = {
  ...TEST_READ_TX,
  value: '1',
};

export const {
  response: TEST_TX_RESPONSE,
  request: TEST_FULL_TX,
  receipt: TEST_TX_RECEIPT,
} = mock.ethers.transactions({
  ...TEST_TX,
  value: BigNumber.from(TEST_TX.value),
  chainId: TEST_SENDER_CHAIN_ID,
  gasLimit: DEFAULT_GAS_LIMIT,
});

// TODO: Should be a type nested in OnchainTransaction...
export type MockOnchainTransactionState = {
  didSubmit: boolean;
  didMine: boolean;
  didFinish: boolean;
};

export const getMockOnchainTransaction = (
  nonce: number = TEST_TX_RESPONSE.nonce,
): {
  transaction: OnchainTransaction;
  state: MockOnchainTransactionState;
} => {
  const transaction = new OnchainTransaction(
    TEST_REQUEST_CONTEXT,
    TEST_TX,
    nonce,
    {
      limit: '24007',
      price: utils.parseUnits('5', 'gwei').toString(),
    },
    {
      confirmationTimeout: 1,
      confirmationsRequired: 1,
    },
    'test_tx_uuid',
  );
  const state: MockOnchainTransactionState = {
    didSubmit: false,
    didMine: false,
    didFinish: false,
  };
  stub(transaction, 'didSubmit').get(() => state.didSubmit);
  stub(transaction, 'didMine').get(() => state.didMine);
  stub(transaction, 'didFinish').get(() => state.didFinish);
  (transaction as any).context = context;
  transaction.attempt = 0;
  (transaction as any).timestamp = undefined;
  transaction.responses = [];
  return {
    transaction,
    state,
  };
};

export const makeChaiReadable = (obj: any) => {
  const result = {};
  Object.keys(obj).forEach((key) => {
    if (BigNumber.isBigNumber(obj[key])) {
      result[key] = BigNumber.from(obj[key]).toString();
    } else {
      result[key] = obj[key];
    }
  });
  return result;
};
