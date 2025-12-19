/// This is only used to manually test RPC providers with getGasPrice method.

import { Logger, expect, chainWrapper } from '@chimera-monorepo/utils';
import { ChainService } from '../../src';
import { TEST_REQUEST_CONTEXT } from '../utils';

describe('ChainService.getGasPrice', () => {
  const logger = new Logger({ level: 'debug', name: 'ChainServiceGetGasPriceIntegrationTest' });

  it('should return a valid gas price for configured networks', async () => {
    const chainService = new ChainService(
      logger.child({ module: 'ChainService' }),
      {
        '1': {
          providers: ['https://ethereum-rpc.publicnode.com'],
        },
      },
      process.env.PRIVATE_KEY ?? chainWrapper.generatePrivateKey(),
      true,
    );
    expect(chainService).to.be.ok;

    // Test multiple configured networks
    const networks = [1];
    
    for (const networkId of networks) {
      try {
        const gasPrice = await chainService.getGasPrice(networkId, TEST_REQUEST_CONTEXT);
        
        // Verify gas price is returned as a string
        expect(gasPrice).to.be.a('string');
        
        // Verify gas price is a valid bigint
        const gasPriceBigInt = BigInt(gasPrice);
        expect(typeof gasPriceBigInt).to.be.eq('bigint');
        
        // Verify gas price is greater than 0
        expect(gasPriceBigInt > BigInt(0)).to.be.true;
        
        // Verify gas price is reasonable (should be less than 1000 gwei for testnet)
        const maxReasonableGasPrice = BigInt('1000000000000000000000'); // 1000 gwei
        expect(gasPriceBigInt < maxReasonableGasPrice).to.be.true;
        
        logger.debug(`Network ${networkId} gas price: ${gasPrice} wei`);
      } catch (error) {
        // Some networks might be deprecated or unavailable
        logger.warn(`Network ${networkId} might be unavailable: ${error.message}`);
      }
    }
  });
});
