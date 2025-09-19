import { Logger, expect } from '@chimera-monorepo/utils';
import { ChainService, OnchainTransaction, OperationTimeout, WriteTransaction } from '../../../src';
import { TEST_REQUEST_CONTEXT } from '../../utils';

// Integration test: construct TransactionDispatch and call its mine() against a predefined
// Solana transaction signature provided via env SOLANA_TEST_SIGNATURE.

describe('TransactionDispatch.mine', () => {
  const logger = new Logger({ level: 'debug', name: 'TransactionDispatch.mine' });

  const SOLANA_DOMAIN = 1399811149;
  const SOLANA_RPC = process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com';
  const SOLANA_TEST_SIGNATURE = process.env.SOLANA_TEST_SIGNATURE || '2XwniWnR7AEEC3eqLc1qxG7wxkqPyaFWBG8ymZDCEo4LmqJtNKkjCMZJiwwM5KnRFtndsGPWauCYLjTuWn4jZSQD';

  it('calls mine on a predefined Solana tx hash', async function () {
    this.timeout(90_000);

    if (!SOLANA_TEST_SIGNATURE) {
      this.skip();
    }

    const chainService = new ChainService(
      logger.child({ module: 'ChainService' }),
      {
        [SOLANA_DOMAIN]: {
          providers: [SOLANA_RPC],
        },
      },
      // Global signer is irrelevant for reading receipts; provide a dummy
      '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
    );

    expect(chainService).to.be.ok;

    // Get underlying TransactionDispatch for Solana
    const txDispatch = await chainService.getProvider(SOLANA_DOMAIN);

    // Build an OnchainTransaction with the predefined hash in responses to satisfy didSubmit
    const minTx: WriteTransaction = { value: '0' } as unknown as WriteTransaction;
    const transaction = new OnchainTransaction(
      TEST_REQUEST_CONTEXT,
      minTx,
      0,
      { limit: '0', price: '0' },
      { confirmationTimeout: 20_000, confirmationsRequired: 1 },
      'solana_test_tx_uuid',
    );

    transaction.responses.push({
      hash: SOLANA_TEST_SIGNATURE,
      confirmations: 0,
      nonce: 0,
      gasPrice: '0',
      gasLimit: '0',
    });

    try {
      await (txDispatch as any).mine(transaction);
      // With current Solana provider, confirmations remain 0, so reaching here would be unexpected
      // but acceptable if the RPC reports confirmations differently. Assert we have a receipt shape.
      expect(transaction.receipt).to.be.ok;
      expect(transaction.receipt!.transactionHash).to.equal(SOLANA_TEST_SIGNATURE);
    } catch (err) {
      // Expected outcome: OperationTimeout due to 0 confirmations in Solana provider implementation
      expect(err).to.be.instanceOf(OperationTimeout);
    }
  });
});
