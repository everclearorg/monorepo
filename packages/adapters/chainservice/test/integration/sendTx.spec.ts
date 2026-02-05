import { Logger, expect, chainWrapper } from '@chimera-monorepo/utils';
import { ChainService, EthWallet } from '../../src';
import { TEST_REQUEST_CONTEXT } from '../utils';

describe('ChainService.sendTx', () => {
  const wallet = EthWallet.createRandom();
  const logger = new Logger({ level: 'debug', name: 'ChainServiceIntegrationTest' });

  it('should work', async () => {
    const chainService = new ChainService(
      logger.child({ module: 'ChainService' }),
      {
        '11155111': {
          providers: ['https://ethereum-sepolia-rpc.publicnode.com'],
        },
      },
      process.env.PRIVATE_KEY ?? chainWrapper.generatePrivateKey(),
      true,
    );
    expect(chainService).to.be.ok;

    // get provider
    const transaction = { domain: 11155111, to: wallet.address, value: '0', data: '0x', funcSig: '' };
    const gasPrice = await chainService.getGasPrice(11155111, TEST_REQUEST_CONTEXT);
    expect(BigInt(gasPrice) > BigInt(0)).to.be.true;
    const gasLimit = await chainService.getGasEstimate(11155111, transaction);
    expect(BigInt(gasLimit) > BigInt(0)).to.be.true;

    const balance = await chainService.getBalance(11155111, wallet.address);
    if (BigInt(balance) === BigInt(0)) {
      return;
    }

    const receipt = await chainService.sendTx(
      {
        ...transaction,
        gasLimit: (BigInt(gasLimit) * BigInt(120) / BigInt(100)).toString(),
        gasPrice: (BigInt(gasPrice) * BigInt(130) / BigInt(100)).toString(),
      },
      TEST_REQUEST_CONTEXT,
    );
    expect(receipt.confirmations).to.be.gt(0);
  });
});
