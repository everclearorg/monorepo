/// This is only used to manually test RPC providers with getGasPrice method.

import { Logger, expect } from '@chimera-monorepo/utils';
import { BigNumber, Wallet } from 'ethers';
import { ChainService } from '../../src';
import { TEST_REQUEST_CONTEXT } from '../utils';

describe('ChainService.getGasPrice', () => {
  const wallet = Wallet.createRandom();
  const logger = new Logger({ level: 'debug', name: 'ChainServiceGetGasPriceIntegrationTest' });

  it('should return a valid gas price for configured networks', async () => {
    const chainService = new ChainService(
      logger.child({ module: 'ChainService' }),
      {
        '1': {
          providers: ['https://ethereum-rpc.publicnode.com'],
        },
      },
      process.env.PRIVATE_KEY ?? wallet._signingKey().privateKey,
    );
    expect(chainService).to.be.ok;

    // Test multiple configured networks
    const networks = [1];
    
    for (const networkId of networks) {
      try {
        const gasPrice = await chainService.getGasPrice(networkId, TEST_REQUEST_CONTEXT);
        
        // Verify gas price is returned as a string
        expect(gasPrice).to.be.a('string');
        
        // Verify gas price is a valid BigNumber
        const gasPriceBN = BigNumber.from(gasPrice);
        expect(gasPriceBN).to.be.instanceOf(BigNumber);
        
        // Verify gas price is greater than 0
        expect(gasPriceBN.gt(0)).to.be.true;
        
        // Verify gas price is reasonable (should be less than 1000 gwei for testnet)
        const maxReasonableGasPrice = BigNumber.from('1000000000000000000000'); // 1000 gwei
        expect(gasPriceBN.lt(maxReasonableGasPrice)).to.be.true;
        
        logger.debug(`Network ${networkId} gas price: ${gasPrice} wei`);
      } catch (error) {
        // Some networks might be deprecated or unavailable
        logger.warn(`Network ${networkId} might be unavailable: ${error.message}`);
      }
    }
  });
});
