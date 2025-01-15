import { Logger, expect } from '@chimera-monorepo/utils';
import { BigNumber, Wallet } from 'ethers';
import { ChainService } from '../../src/chainservice';
import { TEST_REQUEST_CONTEXT } from '../utils';

describe('ChainService.sendTx', () => {
  const wallet = Wallet.createRandom();
  const logger = new Logger({ level: 'debug', name: 'ChainServiceIntegrationTest' });

  it('should work', async () => {
    const chainService = new ChainService(
      logger.child({ module: 'ChainService' }),
      {
        '11155111': {
          providers: ['https://ethereum-sepolia-rpc.publicnode.com'],
        },
      },
      process.env.PRIVATE_KEY ?? wallet._signingKey().privateKey,
    );
    expect(chainService).to.be.ok;

    // get provider
    const transaction = { domain: 11155111, to: wallet.address, value: '0', data: '0x' };
    const gasPrice = await chainService.getGasPrice(11155111, TEST_REQUEST_CONTEXT);
    expect(BigNumber.from(gasPrice).gt(0)).to.be.true;
    const gasLimit = await chainService.getGasEstimate(11155111, transaction);
    expect(BigNumber.from(gasLimit).gt(0)).to.be.true;

    const balance = await chainService.getBalance(11155111, wallet.address);
    if (BigNumber.from(balance).isZero()) {
      return;
    }

    const receipt = await chainService.sendTx(
      {
        ...transaction,
        gasLimit: BigNumber.from(gasLimit).mul(120).div(100).toString(),
        gasPrice: BigNumber.from(gasPrice).mul(130).div(100).toString(),
      },
      TEST_REQUEST_CONTEXT,
    );
    expect(receipt.confirmations).to.be.gt(0);
  });
});
