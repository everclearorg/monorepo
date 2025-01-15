import { utils } from 'ethers';
import { reset, restore, stub } from 'sinon';
import { mkBytes32, mkHash, expect } from '@chimera-monorepo/utils';
import { OnchainTransaction } from '../../../src/shared';
import { TEST_REQUEST_CONTEXT, TEST_TX, TEST_TX_RECEIPT, TEST_TX_RESPONSE } from '../../utils';

describe('OnChainTransaction', () => {
  const context = TEST_REQUEST_CONTEXT;

  let stubTx: OnchainTransaction;

  beforeEach(async () => {
    stubTx = new OnchainTransaction(
      context,
      {
        ...TEST_TX,
        data: mkBytes32('0x66262'),
      },
      TEST_TX_RESPONSE.nonce,
      {
        limit: '24007',
        price: utils.parseUnits('5', 'gwei').toString(),
        maxPriorityFeePerGas: utils.parseUnits('6', 'gwei').toString(),
        maxFeePerGas: utils.parseUnits('7', 'gwei').toString(),
      },
      {
        confirmationTimeout: 1,
        confirmationsRequired: 1,
      },
      '1',
    );
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#hash', () => {
    it('should return undefined before mined and there are no responses', async () => {
      expect(stubTx.hash).to.be.eq(undefined);
    });

    it("should return last response's hash if there are some responses", async () => {
      const testResponse = TEST_TX_RESPONSE;
      testResponse.hash = mkHash();
      stubTx.responses = [TEST_TX_RESPONSE, testResponse];

      expect(stubTx.hash).eq(testResponse.hash);
    });

    it('should return hash of receipt if mined', async () => {
      stub(stubTx, 'didMine').get(() => true);
      stubTx.receipt = TEST_TX_RECEIPT;

      expect(stubTx.hash).eq(TEST_TX_RECEIPT.transactionHash);
    });
  });

  describe('#gasFee', () => {
    it('should return maxFeePerGas, maxPriorityFeePerGas if type is EIP-1559', async () => {
      stubTx.type = 2;
      expect(stubTx.gasFee.gasPrice).to.be.eq(undefined);
      expect(stubTx.gasFee.maxFeePerGas).to.be.eq(stubTx.gas.maxFeePerGas);
      expect(stubTx.gasFee.maxPriorityFeePerGas).to.be.eq(stubTx.gas.maxPriorityFeePerGas);
    });

    it('should return gas Price if type is not EIP-1559', async () => {
      stubTx.type = 1;
      expect(stubTx.gasFee.gasPrice).to.be.eq(stubTx.gas.price);
      expect(stubTx.gasFee.maxPriorityFeePerGas).to.be.eq(undefined);
    });
  });

  describe('#params', () => {
    it('should happy', async () => {
      expect(stubTx.params.nonce).to.be.eq(stubTx.nonce);
      expect(stubTx.params.type).to.be.eq(stubTx.type);
      expect(stubTx.params.gasLimit).to.be.eq(stubTx.gas.limit);
      expect(stubTx.params.gasPrice).to.be.eq(stubTx.gasFee.gasPrice);
    });
  });
});
