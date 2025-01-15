/* eslint-disable @typescript-eslint/no-explicit-any */
import { providers, utils, Wallet } from 'ethers';
import { stub, restore, reset, createStubInstance, SinonStubbedInstance } from 'sinon';
import { mkBytes32, mkAddress, expect, Logger } from '@chimera-monorepo/utils';

import { ChainReader } from '../../src/chainreader';
import { RpcProviderAggregator } from '../../src/aggregator';
import { ConfigurationError, ProviderNotConfigured, RpcError } from '../../src/shared';
import {
  TEST_TX,
  TEST_READ_TX,
  TEST_TX_RECEIPT,
  makeChaiReadable,
  TEST_SENDER_DOMAIN,
  TEST_REQUEST_CONTEXT,
} from '../utils';
import { parseUnits } from 'ethers/lib/utils';

const logger = new Logger({
  level: process.env.LOG_LEVEL ?? 'silent',
  name: 'ChainReaderTest',
});

let signer: SinonStubbedInstance<Wallet>;
let chainReader: ChainReader;
let provider: SinonStubbedInstance<RpcProviderAggregator>;

/// In these tests, we are testing the outer shell of chainreader - the interface, not the core functionality.
/// For core functionality tests, see dispatch.spec.ts and provider.spec.ts.
describe('ChainReader', () => {
  beforeEach(() => {
    provider = createStubInstance(RpcProviderAggregator);
    const privateKey = Wallet.createRandom().privateKey;
    signer = createStubInstance(Wallet);
    signer.connect.returns(signer);
    signer._signingKey = () => privateKey;

    const chains = {
      [TEST_SENDER_DOMAIN.toString()]: {
        providers: [{ url: 'https://-------------' }],
        confirmations: 1,
        gasStations: [],
      },
    };

    chainReader = new ChainReader(logger, { chains }, signer.privateKey);
    const fake: any = (domain: number) => {
      // NOTE: We check to make sure we are only getting the one domain we expect
      // to get in these unit tests.
      expect(domain).to.be.eq(TEST_SENDER_DOMAIN);
      return provider;
    };
    stub(chainReader as any, 'getProvider').callsFake(fake);
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#readTx', () => {
    it('happy: returns exactly what it reads', async () => {
      const fakeData = mkBytes32();
      provider.readContract.resolves(fakeData);

      const data = await chainReader.readTx(TEST_READ_TX, 'latest');

      expect(data).to.deep.eq(fakeData);
      expect(provider.readContract.callCount).to.equal(1);
      expect(provider.readContract.args[0][0]).to.deep.eq(TEST_READ_TX);
    });

    it('should throw if provider fails', async () => {
      provider.readContract.rejects(new RpcError('fail'));

      await expect(chainReader.readTx(TEST_READ_TX, 'latest')).to.be.rejectedWith('fail');
    });
  });

  describe('#getBalance', () => {
    it('happy', async () => {
      const testBalance = utils.parseUnits('42', 'ether').toString();
      const testAddress = mkAddress();
      provider.getBalance.resolves(testBalance);

      const balance = await chainReader.getBalance(TEST_SENDER_DOMAIN, testAddress);

      expect(balance).to.be.eq(testBalance);
      expect(provider.getBalance.callCount).to.equal(1);
      expect(provider.getBalance.getCall(0).args[0]).to.deep.eq(testAddress);
    });

    it('should throw if provider fails', async () => {
      provider.getBalance.rejects(new RpcError('fail'));

      await expect(chainReader.getBalance(TEST_SENDER_DOMAIN, mkAddress('0xaaa'))).to.be.rejectedWith('fail');
    });
  });

  describe('#getGasPrice', () => {
    it('happy', async () => {
      const testGasPrice = utils.parseUnits('5', 'gwei').toString();
      provider.getGasPrice.resolves(testGasPrice);

      const gasPrice = await chainReader.getGasPrice(TEST_SENDER_DOMAIN, TEST_REQUEST_CONTEXT);

      expect(gasPrice).to.be.eq(testGasPrice);
      expect(provider.getGasPrice.callCount).to.equal(1);
    });

    it('should throw if provider fails', async () => {
      provider.getGasPrice.rejects(new RpcError('fail'));

      await expect(chainReader.getGasPrice(TEST_SENDER_DOMAIN, TEST_REQUEST_CONTEXT)).to.be.rejectedWith('fail');
    });
  });

  describe('#getDecimalsForAsset', () => {
    it('happy', async () => {
      const decimals = 18;
      const assetId = mkAddress('0xaaa');
      provider.getDecimalsForAsset.resolves(decimals);

      const retrieved = await chainReader.getDecimalsForAsset(TEST_SENDER_DOMAIN, assetId);

      expect(retrieved).to.be.eq(decimals);
      expect(provider.getDecimalsForAsset.callCount).to.equal(1);
      expect(provider.getDecimalsForAsset.getCall(0).args[0]).to.deep.eq(assetId);
    });

    it('should throw if provider fails', async () => {
      provider.getDecimalsForAsset.rejects(new RpcError('fail'));

      await expect(chainReader.getDecimalsForAsset(TEST_SENDER_DOMAIN, mkAddress('0xaaa'))).to.be.rejectedWith('fail');
    });
  });

  describe('#getBlock', () => {
    it('happy', async () => {
      const mockBlock = { transactions: [mkBytes32()] } as providers.Block;
      provider.getBlock.resolves(mockBlock);

      const block = await chainReader.getBlock(TEST_SENDER_DOMAIN, 'block');

      expect(block).to.be.eq(mockBlock);
      expect(provider.getBlock.callCount).to.equal(1);
    });

    it('should throw if provider fails', async () => {
      provider.getBlock.rejects(new RpcError('fail'));

      await expect(chainReader.getBlock(TEST_SENDER_DOMAIN, 'block')).to.be.rejectedWith('fail');
    });
  });

  describe('#getBlockTime', () => {
    it('happy', async () => {
      const time = Math.floor(Date.now() / 1000);
      provider.getBlockTime.resolves(time);

      const blockTime = await chainReader.getBlockTime(TEST_SENDER_DOMAIN);

      expect(blockTime).to.be.eq(time);
      expect(provider.getBlockTime.callCount).to.equal(1);
    });

    it('should throw if provider fails', async () => {
      provider.getBlockTime.rejects(new RpcError('fail'));

      await expect(chainReader.getBlockTime(TEST_SENDER_DOMAIN)).to.be.rejectedWith('fail');
    });
  });

  describe('#getBlockNumber', () => {
    it('happy', async () => {
      const testBlockNumber = 42;
      provider.getBlockNumber.resolves(testBlockNumber);

      const blockNumber = await chainReader.getBlockNumber(TEST_SENDER_DOMAIN);

      expect(blockNumber).to.be.eq(testBlockNumber);
      expect(provider.getBlockNumber.callCount).to.equal(1);
    });

    it('should throw if provider fails', async () => {
      provider.getBlockNumber.rejects(new RpcError('fail'));

      await expect(chainReader.getBlockNumber(TEST_SENDER_DOMAIN)).to.be.rejectedWith('fail');
    });
  });

  describe('#getTransactionReceipt', () => {
    it('happy', async () => {
      provider.getTransactionReceipt.resolves(TEST_TX_RECEIPT);

      const receipt = await chainReader.getTransactionReceipt(TEST_SENDER_DOMAIN, TEST_TX_RECEIPT.transactionHash);

      expect(makeChaiReadable(receipt)).to.deep.eq(makeChaiReadable(TEST_TX_RECEIPT));
      expect(provider.getTransactionReceipt.callCount).to.be.eq(1);
    });

    it('should throw if provider fails', async () => {
      provider.getTransactionReceipt.rejects(new RpcError('fail'));

      await expect(
        chainReader.getTransactionReceipt(TEST_SENDER_DOMAIN, TEST_TX_RECEIPT.transactionHash),
      ).to.be.rejectedWith('fail');
    });
  });

  describe('#getCode', () => {
    it('happy', async () => {
      const code = '0x12345789';
      provider.getCode.resolves(code);

      const result = await chainReader.getCode(TEST_SENDER_DOMAIN, mkAddress('0xa1'));

      expect(result).to.be.eq(code);
      expect(provider.getCode.callCount).to.equal(1);
    });

    it('should throw if provider fails', async () => {
      provider.getCode.rejects(new RpcError('fail'));

      await expect(chainReader.getCode(TEST_SENDER_DOMAIN, mkAddress('0xa1'))).to.be.rejectedWith('fail');
    });
  });

  describe('#getGasEstimate', () => {
    it('happy', async () => {
      const mockGasEstimation = parseUnits('1', 9).toString();
      provider.getGasEstimate.resolves(mockGasEstimation);

      const gasEstimation = await chainReader.getGasEstimate(TEST_SENDER_DOMAIN, TEST_TX);

      expect(gasEstimation).to.be.eq(mockGasEstimation);
      expect(provider.getGasEstimate.callCount).to.equal(1);
    });

    it('should throw if provider fails', async () => {
      provider.getGasEstimate.rejects(new RpcError('fail'));

      await expect(chainReader.getGasEstimate(TEST_SENDER_DOMAIN, TEST_TX)).to.be.rejectedWith('fail');
    });
  });

  describe('#isSupportedChain', () => {
    it('should return false for unsupported chain', async () => {
      expect(chainReader.isSupportedChain(111111)).to.be.false;
    });
  });

  describe('#getProvider', () => {
    it('errors if cannot get provider', async () => {
      // Replacing this method with the original fn not working.
      (chainReader as any).getProvider.restore();
      await expect(chainReader.readTx({ ...TEST_TX, domain: 9999 }, 'latest')).to.be.rejectedWith(
        ProviderNotConfigured,
      );
    });
  });

  describe('#setupProviders', () => {
    it('throws if not a single provider config is provided for a chainId', async () => {
      (chainReader as any).config = {
        [TEST_SENDER_DOMAIN.toString()]: {
          // Providers list here should never be empty.
          providers: [],
          confirmations: 1,
          gasStations: [],
        },
      };
      expect(() => (chainReader as any).setupProviders(context, signer)).to.throw(ConfigurationError);
    });
  });
});
