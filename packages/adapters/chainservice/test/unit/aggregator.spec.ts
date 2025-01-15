/* eslint-disable @typescript-eslint/no-explicit-any */
import { BigNumber, constants, providers, utils, Wallet } from 'ethers';
import { stub, restore, reset, createStubInstance, SinonStubbedInstance, SinonStub } from 'sinon';
import { mkAddress, mkBytes32, expect, Logger, EverclearError, mock } from '@chimera-monorepo/utils';

import { RpcProviderAggregator } from '../../src/aggregator';
import * as Mockable from '../../src/mockable';
import { ChainConfig, DEFAULT_CHAIN_CONFIG } from '../../src/config';
import {
  OnchainTransaction,
  GasEstimateInvalid,
  RpcError,
  OperationTimeout,
  TransactionReadError,
  TransactionReverted,
  QuorumNotMet,
  SyncProvider,
  MissingSigner,
} from '../../src/shared';
import {
  makeChaiReadable,
  TEST_FULL_TX,
  TEST_READ_TX,
  TEST_SENDER_CHAIN_ID,
  DEFAULT_GAS_LIMIT,
  TEST_TX,
  TEST_SENDER_DOMAIN,
  TEST_TX_RECEIPT,
  TEST_TX_RESPONSE,
  TEST_REQUEST_CONTEXT,
} from '../utils';

const logger = new Logger({
  level: process.env.LOG_LEVEL ?? 'silent',
  name: 'DispatchTest',
});

let signer: SinonStubbedInstance<Wallet>;
let chainProvider: RpcProviderAggregator;
let transaction: OnchainTransaction;

describe('RpcProviderAggregator', () => {
  let providerStub: SinonStubbedInstance<providers.StaticJsonRpcProvider>;

  beforeEach(async () => {
    // Configs
    const providerConfigs = [
      {
        url: 'https://-------------',
      },
    ];
    const domain = TEST_SENDER_DOMAIN;
    const config: ChainConfig = {
      ...DEFAULT_CHAIN_CONFIG,
      providers: providerConfigs,
      confirmations: 1,
      confirmationTimeout: 10_000,
    };

    // Ethers stubs
    providerStub = stub(providers.StaticJsonRpcProvider.prototype);
    const privateKey = Wallet.createRandom().privateKey;
    signer = stub(Wallet.prototype);
    signer.sendTransaction.resolves(TEST_TX_RESPONSE);
    signer.getTransactionCount.resolves(TEST_TX_RESPONSE.nonce);
    signer.connect.returns(signer);
    providerStub.getSigner.returns(signer as any);

    // Local package stubs
    transaction = new OnchainTransaction(
      TEST_REQUEST_CONTEXT,
      TEST_TX,
      TEST_TX_RESPONSE.nonce,
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
    stub(transaction, 'params').get(() => TEST_FULL_TX);

    // Testing instance
    chainProvider = new RpcProviderAggregator(logger, domain, config, privateKey);
    // // One block = 10ms for the purposes of testing.
    // (chainProvider as any).blockPeriod = 10;
    // stub(chainProvider as any, 'execute').callsFake(fakeExecuteMethod as any);
  });

  afterEach(async () => {
    restore();
    reset();
  });

  describe('#sendTransaction', () => {
    it('happy: should send the transaction', async () => {
      const result = await (chainProvider as any).sendTransaction(transaction);

      expect(signer.sendTransaction.callCount).to.equal(1);
      expect(makeChaiReadable(signer.sendTransaction.getCall(0).args[0])).to.containSubset(
        makeChaiReadable({
          to: TEST_TX.to,
          data: TEST_TX.data,
          value: TEST_TX.value,
          domain: TEST_TX.domain,
        }),
      );
      expect(makeChaiReadable(result)).to.be.deep.eq(makeChaiReadable(TEST_TX_RESPONSE));
    });

    it('should return error result if the signer sendTransaction call throws', async () => {
      const testError = new Error('test error');
      signer.sendTransaction.rejects(testError);

      await expect((chainProvider as any).sendTransaction(transaction)).to.be.rejectedWith(testError);
    });

    it('should fail if there is no signer', async () => {
      const error = new MissingSigner();
      (chainProvider as any).signer = undefined;
      await expect((chainProvider as any).sendTransaction(transaction)).to.be.rejectedWith(error.message);
    });
  });

  describe('#confirmTransaction', () => {
    let waitStub: SinonStub;
    const receipt = mock.ethers.receipt({ ...TEST_TX_RECEIPT, status: 1 });
    beforeEach(() => {
      providerStub.getTransactionReceipt.resolves(receipt);
      waitStub = stub(chainProvider as any, 'wait').resolves();
      transaction.responses = [TEST_TX_RESPONSE];
    });

    it('happy', async () => {
      const result = await chainProvider.confirmTransaction(transaction);

      expect(providerStub.getTransactionReceipt.callCount).to.equal(1);
      expect(makeChaiReadable(result)).to.be.deep.eq(makeChaiReadable(receipt));
    });

    it('should throw if no successful and error(s) were thrown', async () => {
      const testError = new Error('fail');
      providerStub.getTransactionReceipt.rejects(testError);

      await expect(chainProvider.confirmTransaction(transaction)).to.be.rejectedWith(testError);
    });

    it('should wait until receipt returns and confirmations are insufficient', async () => {
      const testDesiredConfirmations = 42;
      const insufficientConfirmations = 29;
      const currentBlockNumber = 1234567;
      const insufficientReceipt = {
        ...receipt,
        confirmations: insufficientConfirmations,
      };
      const sufficientReceipt = {
        ...receipt,
        confirmations: testDesiredConfirmations,
      };
      providerStub.getTransactionReceipt.onCall(0).resolves(null);
      providerStub.getTransactionReceipt.onCall(1).resolves(insufficientReceipt);
      providerStub.getTransactionReceipt.onCall(2).resolves(sufficientReceipt);

      // So we can check the block args in the wait call below.
      (chainProvider as any).cache.update(currentBlockNumber);
      // To ensure we don't bother with the initial wait mechanism.
      transaction.minedBlockNumber = -1;

      const result = await chainProvider.confirmTransaction(transaction, testDesiredConfirmations);

      expect(waitStub.callCount).to.equal(2);
      // Should wait # of blocks equal to # of desired confirmations.
      expect(waitStub.getCall(0).args[0]).to.be.deep.eq(testDesiredConfirmations);
      expect(waitStub.getCall(1).args[0]).to.be.deep.eq(testDesiredConfirmations - insufficientConfirmations);
      expect(makeChaiReadable(result)).to.be.deep.eq(makeChaiReadable(sufficientReceipt));
    });

    it('should throw timeout error if pushed over the timeout threshold', async () => {
      // This shouldn't be valid input normally, but since the method uses a variable (timedOut) to ensure
      // at least one iteration gets executed, this will work.
      const testTimeout = -1;
      providerStub.getTransactionReceipt.resolves(undefined);

      await expect(chainProvider.confirmTransaction(transaction, 10, testTimeout)).to.be.rejectedWith(OperationTimeout);
    });

    it('should throw reverting transactions if no receipts are successful', async () => {
      const testDesiredConfirmations = 13;
      const numTransactions = 10;
      const testHashes = new Array(numTransactions).fill('').map(() => mkBytes32());
      const revertedHash = testHashes[7];
      transaction.responses = new Array(numTransactions).fill(0).map((_, i) => ({
        ...TEST_TX_RESPONSE,
        hash: testHashes[i],
      }));
      providerStub.getTransactionReceipt.callsFake((hash) => {
        const index = testHashes.indexOf(hash as string);
        if (index === -1) {
          // It should definitely have been one of the hashes supplied above.
          throw new Error('invalid hash');
        }
        return hash === revertedHash
          ? Promise.resolve({
              ...TEST_TX_RECEIPT,
              confirmations: testDesiredConfirmations,
              status: 0,
            })
          : Promise.resolve(TEST_TX_RECEIPT);
      });

      await expect(chainProvider.confirmTransaction(transaction, testDesiredConfirmations)).to.be.rejectedWith(
        TransactionReverted,
      );
      expect(waitStub.callCount).to.equal(0);
    });

    it('should not throw reverted transactions if one receipt is successful', async () => {
      // NOTE: Theoretically, this should be possible - we shouldn't have reverted txs, but rather
      // a successful tx should 'replace' the others. However, if a provider is out of sync with others,
      // a misread could occur: we want to be absolutely certain that this scenario is guarded against.
      const testDesiredConfirmations = 13;
      const numTransactions = 10;
      const testHashes = new Array(numTransactions).fill('').map(() => mkBytes32(utils.hexlify(utils.randomBytes(32))));
      const revertedHash = testHashes[7];
      const successfulHash = testHashes[8];
      transaction.responses = new Array(numTransactions).fill(0).map((_, i) => ({
        ...TEST_TX_RESPONSE,
        hash: testHashes[i],
      }));
      const expectedReceipt = {
        ...receipt,
        confirmations: testDesiredConfirmations,
        status: 1,
      };
      providerStub.getTransactionReceipt.callsFake((hash) => {
        const index = testHashes.indexOf(hash);
        if (index === -1) {
          // It should definitely have been one of the hashes supplied above.
          throw new Error('invalid hash');
        }
        return hash === revertedHash
          ? {
              ...receipt,
              confirmations: testDesiredConfirmations,
              status: 0,
            }
          : hash === successfulHash
            ? expectedReceipt
            : undefined;
      });
      const result = await chainProvider.confirmTransaction(transaction, testDesiredConfirmations);
      expect(makeChaiReadable(result)).to.be.deep.eq(makeChaiReadable(expectedReceipt));
    });
  });

  describe('#readContract', () => {
    it('happy: should perform contract read method as given', async () => {
      const fakeData = mkBytes32();
      providerStub.call.resolves(fakeData);

      const result = await chainProvider.readContract(TEST_READ_TX, 'latest');

      expect(providerStub.call.callCount).to.equal(1);
      const { to, data } = TEST_READ_TX;
      expect(providerStub.call.getCall(0).args[0]).to.deep.equal({ to, data, chainId: TEST_SENDER_CHAIN_ID });
      expect(result).to.be.eq(fakeData);
    });

    it('should return error result if the provider readContract call throws', async () => {
      const testError = new Error('test error');
      providerStub.call.rejects(testError);

      // The error.context.error is the "test error" thrown by the signer.call.
      await expect(chainProvider.readContract(TEST_READ_TX, 'latest')).to.be.rejectedWith(TransactionReadError);
    });

    it('should execute with provider if no signer available', async () => {
      const fakeData = mkBytes32();
      (chainProvider as any).signer = undefined;
      providerStub.call.resolves(fakeData);

      const result = await chainProvider.readContract(TEST_READ_TX, 'latest');

      expect(signer.call.callCount).to.equal(0);
      expect(providerStub.call.callCount).to.equal(1);
      const { to, data } = TEST_READ_TX;
      expect(providerStub.call.getCall(0).args[0]).to.deep.equal({ to, data, chainId: TEST_SENDER_CHAIN_ID });
      expect(result).to.be.eq(fakeData);
    });
  });

  describe('#estimateGas', () => {
    const testGasLimit = DEFAULT_GAS_LIMIT.toString();
    const testTx = {
      domain: TEST_SENDER_DOMAIN,
      to: mkAddress(),
      from: mkAddress(),
      data: mkBytes32(),
      value: utils.parseUnits('1', 'ether').toString(),
    };

    beforeEach(() => {
      providerStub.estimateGas.resolves(BigNumber.from(testGasLimit));
    });

    it('happy: should return the gas estimate', async () => {
      const result = await chainProvider.estimateGas(testTx);

      // First, make sure we get the correct value back.
      expect(result).to.be.eq(testGasLimit);

      // Now we make sure that all of the calls were made as expected.
      expect(providerStub.estimateGas.callCount).to.equal(1);
      const { domain, ...expected } = testTx;
      expect(providerStub.estimateGas.calledOnceWithExactly({ chainId: TEST_SENDER_CHAIN_ID, ...expected })).to.be.true;
    });

    it('should handle invalid value for gas estimate', async () => {
      const badValue = 'thisisnotanumber';
      providerStub.estimateGas.resolves(badValue as any);
      await expect(chainProvider.estimateGas(testTx)).to.be.rejectedWith(GasEstimateInvalid.getMessage(badValue));
    });

    it('should throw errors that occur during send', async () => {
      const testError = new Error('test error');
      providerStub.estimateGas.rejects(testError);
      await expect(chainProvider.estimateGas(testTx)).to.be.rejectedWith(testError);
    });

    it('should inflate gas limit by configured inflation value', async () => {
      const testInflation = BigNumber.from(10_000);
      (chainProvider as any).config.gasLimitInflation = testInflation;
      const result = await chainProvider.estimateGas(testTx);
      expect(result).to.be.eq(BigNumber.from(testGasLimit).add(testInflation).toString());
    });
  });

  describe('#getGasPrice', () => {
    it('happy: should return the gas price', async () => {
      const testGasPrice = utils.parseUnits('100', 'gwei') as BigNumber;
      // Gas price gets bumped by X% in this method.
      const expectedGas = testGasPrice
        .add(testGasPrice.mul((chainProvider as any).config.gasPriceInitialBoostPercent).div(100))
        .toString();
      providerStub.getGasPrice.resolves(testGasPrice);

      const result = await (chainProvider as any).getGasPrice();

      expect(providerStub.getGasPrice.callCount).to.equal(1);
      expect(result.toString()).to.be.eq(expectedGas);
    });

    it('should accept hardcoded values from config', async () => {
      const expectedGas = '197';
      (chainProvider as any).config.hardcodedGasPrice = expectedGas;
      const result = await (chainProvider as any).getGasPrice();
      expect(providerStub.getGasPrice.callCount).to.equal(0);
      expect(result.toString()).to.be.eq(expectedGas);
    });

    // TODO: Should eventually cache per block.
    it('should use cached gas price if calls < 3 seconds apart', async () => {
      const testGasPrice = utils.parseUnits('80', 'gwei') as BigNumber;
      const expectedGas = testGasPrice
        .add(testGasPrice.mul((chainProvider as any).config.gasPriceInitialBoostPercent).div(100))
        .toString();
      providerStub.getGasPrice.resolves(testGasPrice);

      // First call should use provider.
      let result = await (chainProvider as any).getGasPrice();
      expect(result.toString()).to.be.eq(expectedGas);

      // Throwing in a bunk value to make sure this isn't called.
      providerStub.getGasPrice.resolves(utils.parseUnits('1300', 'gwei'));

      // Second call should use cached value.
      result = await (chainProvider as any).getGasPrice();

      // Values should be the same.
      expect(result.toString()).to.be.eq(expectedGas);
      // Provider should have only been called once.
      expect(providerStub.getGasPrice.callCount).to.equal(1);
    });

    it('should bump gas price up to minimum if it is below that', async () => {
      // For test reliability, start from the config value and work backwards.
      const expectedGasPrice = (chainProvider as any).config.gasPriceMinimum;
      const testGasPrice = BigNumber.from(expectedGasPrice)
        .sub(
          BigNumber.from(expectedGasPrice)
            .mul((chainProvider as any).config.gasPriceInitialBoostPercent)
            .div(100),
        )
        .sub(utils.parseUnits('1', 'gwei'));
      providerStub.getGasPrice.resolves(testGasPrice);

      const result = await (chainProvider as any).getGasPrice();

      expect(result.toString()).to.be.eq(expectedGasPrice);
    });

    it('should employ the gas price max increase scalar if configured and applicable', async () => {
      // For test reliability, start from the config value and work backwards.
      const testScalar = (chainProvider as any).config.gasPriceMaxIncreaseScalar;
      const testLastUsedGasPrice = utils.parseUnits('5', 'gwei');
      (chainProvider as any).lastUsedGasPrice = testLastUsedGasPrice;
      // We're going to set the gas price our provider returns to the max value + 1 gwei.
      // We expect the getGasPrice method to cap the price it returns at the max value.
      const expectedGasPrice = testLastUsedGasPrice.mul(testScalar).div(100);
      const testGasPrice = expectedGasPrice.add(utils.parseUnits('1', 'gwei'));
      providerStub.getGasPrice.resolves(testGasPrice);

      const result = await (chainProvider as any).getGasPrice();

      expect(result.toString()).to.be.eq(expectedGasPrice.toString());
    });

    it('should use gas station if available', async () => {
      const testGasPriceGwei = 42;
      const testGasPrice = utils.parseUnits(testGasPriceGwei.toString(), 'gwei') as BigNumber;
      (chainProvider as any).config.gasStations = ['...fakeaddy...'];
      const axiosStub = stub(Mockable, 'axiosGet').resolves({ data: { fast: testGasPriceGwei.toString() } });

      const result = await (chainProvider as any).getGasPrice();

      expect(result.toString()).to.be.eq(testGasPrice.toString());
      expect(axiosStub.callCount).to.equal(1);
      expect(providerStub.getGasPrice.callCount).to.equal(0);
    });

    it('should resort to provider gas price if gas station fails', async () => {
      const testGasPrice = utils.parseUnits('42', 'gwei') as BigNumber;
      (chainProvider as any).config.gasStations = ['...fakeaddy...'];
      providerStub.getGasPrice.resolves(testGasPrice);
      const axiosStub = stub(Mockable, 'axiosGet').rejects(new Error('test'));
      const expectedGas = testGasPrice
        .add(testGasPrice.mul((chainProvider as any).config.gasPriceInitialBoostPercent).div(100))
        .toString();

      const result = await (chainProvider as any).getGasPrice();

      expect(result.toString()).to.be.eq(expectedGas);
      expect(axiosStub.callCount).to.equal(1);
      expect(providerStub.getGasPrice.callCount).to.equal(1);
    });

    it('should handle unexpected params as a gas station failure', async () => {
      const testGasPrice = utils.parseUnits('42', 'gwei') as BigNumber;
      (chainProvider as any).config.gasStations = ['...fakeaddy...'];
      providerStub.getGasPrice.resolves(testGasPrice);
      const axiosStub = stub(Mockable, 'axiosGet').resolves({ data: 'bad data, so sad! :(' });

      const result = await (chainProvider as any).getGasPrice();
      expect(result).to.be.ok;

      expect(axiosStub.callCount).to.equal(1);
      expect(providerStub.getGasPrice.callCount).to.equal(1);
    });

    it('should cap gas price if it hits configured absolute maximum', async () => {
      const testGasPrice = utils.parseUnits('100', 'gwei') as BigNumber;
      (chainProvider as any).config.gasPriceMaximum = testGasPrice;
      providerStub.getGasPrice.resolves(testGasPrice.add(utils.parseUnits('1', 'gwei')));

      const result = await (chainProvider as any).getGasPrice();

      expect(result.toString()).to.be.eq(testGasPrice.toString());
    });
  });

  describe('#getBalance', () => {
    it('happy: should return the balance', async () => {
      const testBalance = utils.parseUnits('42', 'ether');
      const testAddress = mkAddress();
      providerStub.getBalance.resolves(testBalance);

      const result = await chainProvider.getBalance(testAddress, constants.AddressZero);

      expect(result).to.be.eq(testBalance.toString());
      expect(providerStub.getBalance.callCount).to.equal(1);
      expect(providerStub.getBalance.getCall(0).args[0]).to.deep.eq(testAddress);
    });
  });

  describe('#getDecimalsForAsset', () => {
    const testAssetId = mkAddress('0x1');
    const testDecimals = 42;

    beforeEach(() => {
      const data = utils.defaultAbiCoder.encode(['uint8'], [testDecimals]);
      providerStub.call.resolves(data);
    });

    it('happy', async () => {
      const result = await chainProvider.getDecimalsForAsset(testAssetId);
      expect(result).to.eq(testDecimals);
      // Check to make sure the result was cached.
      expect((chainProvider as any).cachedDecimals[testAssetId]).to.eq(testDecimals);
    });

    it('happy: should return 18 for the native asset', async () => {
      const result = await chainProvider.getDecimalsForAsset(constants.AddressZero);
      expect(result).to.be.eq(18);
    });

    it('should use cached decimals', async () => {
      (chainProvider as any).cachedDecimals[testAssetId] = testDecimals;
      const result = await chainProvider.getDecimalsForAsset(testAssetId);
      expect(result).to.eq(testDecimals);
      expect(providerStub.call.callCount).to.eq(0);
    });
  });

  describe('#getBlockTime', () => {
    it('happy: should return the block time', async () => {
      const blockTime = Math.floor(Date.now() / 1000);
      providerStub.getBlock.resolves({ timestamp: blockTime } as unknown as providers.Block);

      const result = await chainProvider.getBlockTime();

      expect(result).to.be.eq(blockTime);
      expect(providerStub.getBlock.callCount).to.be.at.least(1);
      expect(providerStub.getBlock.getCall(0).args[0]).to.deep.eq('latest');
    });
  });

  describe('#getBlockNumber', () => {
    it('happy: should return the block number', async () => {
      const blockNumber = 13;
      providerStub.getBlockNumber.resolves(blockNumber);

      const result = await chainProvider.getBlockNumber();

      expect(result).to.be.eq(blockNumber);
      expect(providerStub.getBlockNumber.callCount).to.be.at.least(1);
    });
  });

  describe('#getAddress', () => {
    it('happy: should return the address', async () => {
      const testAddress = mkAddress();
      signer.getAddress.resolves(testAddress);

      const result = await chainProvider.getAddress();

      expect(result).to.be.eq(testAddress);
      expect(signer.getAddress.callCount).to.equal(1);
    });

    it('should fail if there is no signer available', async () => {
      const testError = new Error('test: no signer available');
      stub(chainProvider as any, 'checkSigner').throws(testError);

      await expect(chainProvider.getAddress()).to.be.rejectedWith(testError);
    });
  });

  describe('#getTransactionReceipt', () => {
    it('happy: should return the transaction receipt', async () => {
      const testTransactionReceipt = {
        ...TEST_TX_RECEIPT,
      };
      providerStub.getTransactionReceipt.resolves(testTransactionReceipt);

      const result = await chainProvider.getTransactionReceipt(TEST_TX_RECEIPT.transactionHash);

      expect(result).to.be.eq(testTransactionReceipt);
      expect(providerStub.getTransactionReceipt.callCount).to.equal(1);
      expect(providerStub.getTransactionReceipt.getCall(0).args[0]).to.deep.eq(TEST_TX_RECEIPT.transactionHash);
    });
  });

  describe('#getTransactionCount', () => {
    it('happy: should return the transaction count', async () => {
      const testTransactionCount = Math.floor(Math.random() * 1000);
      providerStub.getTransactionCount.resolves(testTransactionCount);
      const testAddress = mkAddress();
      signer.getAddress.resolves(testAddress);

      const result = await chainProvider.getTransactionCount();

      expect(result).to.be.eq(testTransactionCount);
      expect(providerStub.getTransactionCount.callCount).to.equal(1);
      expect(providerStub.getTransactionCount.getCall(0).args).to.deep.eq([testAddress, 'latest']);
      // Make sure we didn't make any calls directly to signer for tx count.
      expect(signer.getTransactionCount.callCount).to.equal(0);
    });

    it('uses cached transaction count if available', async () => {
      const testTransactionCount = Math.floor(Math.random() * 1000);
      (chainProvider as any).cache.set({ transactionCount: testTransactionCount });

      const result = await chainProvider.getTransactionCount();

      expect(result).to.be.eq(testTransactionCount);
      expect(providerStub.getTransactionCount.callCount).to.equal(0);
    });
  });

  describe('#checkSigner', () => {
    it('throws if no signer available', async () => {
      (chainProvider as any).signer = undefined;
      expect(() => (chainProvider as any).checkSigner()).to.throw(EverclearError);
    });
  });

  describe('#execute', () => {
    const goodRpcProvider: any = {};
    const badRpcProvider: any = {};
    const testRpcError = new RpcError('test: bad rpc provider');
    let testSyncProviders: any[] = [];
    let shuffleSyncedProvidersStub: SinonStub;
    const mockMethodParam = (provider: any) => provider.method();

    beforeEach(() => {
      shuffleSyncedProvidersStub = stub(chainProvider as any, 'shuffleSyncedProviders').callsFake(
        () => testSyncProviders,
      );
      goodRpcProvider.method = stub().resolves(true);
      badRpcProvider.method = stub().rejects(testRpcError);
    });

    it('happy', async () => {
      // Testing with bad and good rpc providers.
      testSyncProviders = [badRpcProvider, goodRpcProvider];

      // First, make sure we get the correct value back.
      expect(await (chainProvider as any).execute(false, mockMethodParam)).to.be.true;
      expect(badRpcProvider.method.callCount).to.equal(1);
      expect(goodRpcProvider.method.callCount).to.equal(1);
      expect(shuffleSyncedProvidersStub.callCount).to.equal(1);
    });

    it('happy, with quorum > 1', async () => {
      testSyncProviders = [goodRpcProvider, badRpcProvider, goodRpcProvider];

      // Quorum required = 2. The 2 good RPC providers we supplied should suffice.
      (chainProvider as any).config.quorum = 2;
      (chainProvider as any).providers = testSyncProviders;

      expect(await (chainProvider as any).execute(false, mockMethodParam)).to.be.true;
      // 1 call for bad, 2 for good. 0 calls to shuffle, we should have consulted all providers!
      expect(badRpcProvider.method.callCount).to.equal(1);
      expect(goodRpcProvider.method.callCount).to.equal(2);
      expect(shuffleSyncedProvidersStub.callCount).to.equal(0);
    });

    it('works with quorum > 1 and different return types', async () => {
      (chainProvider as any).config.quorum = 2;

      for (const returnValue of ['hello test', false, 12345, BigNumber.from('12345'), { hello: 'test' }]) {
        goodRpcProvider.method = stub().resolves(returnValue);
        badRpcProvider.method = stub().rejects(testRpcError);

        testSyncProviders = [goodRpcProvider, badRpcProvider, goodRpcProvider];
        (chainProvider as any).providers = testSyncProviders;

        expect(await (chainProvider as any).execute(false, mockMethodParam)).to.be.deep.eq(returnValue);
      }
    });

    it('works with quorum > 1 and picks the top response', async () => {
      testSyncProviders = [goodRpcProvider, badRpcProvider, goodRpcProvider, badRpcProvider, goodRpcProvider];

      (chainProvider as any).config.quorum = 2;
      (chainProvider as any).providers = testSyncProviders;

      // Hi or Bye, which one is it? It should be "hi" since the goodRpcProviders outnumber the bad.
      goodRpcProvider.method = stub().resolves('hi');
      badRpcProvider.method = stub().resolves('bye');

      const result = await (chainProvider as any).execute(false, mockMethodParam);
      expect(result).to.be.eq('hi');

      expect(badRpcProvider.method.callCount).to.equal(2);
      expect(goodRpcProvider.method.callCount).to.equal(3);
    });

    it('works with quorum > 1 and multiple top responses', async () => {
      testSyncProviders = [goodRpcProvider, badRpcProvider, goodRpcProvider, badRpcProvider];

      (chainProvider as any).config.quorum = 2;
      (chainProvider as any).providers = testSyncProviders;

      // Hi or Bye, which one is it? Unfortunately will just have to pick one...
      goodRpcProvider.method = stub().resolves('hi');
      badRpcProvider.method = stub().resolves('bye');

      const result = await (chainProvider as any).execute(false, mockMethodParam);
      expect(result === 'hi' || result === 'bye').to.be.true;

      expect(badRpcProvider.method.callCount).to.equal(2);
      expect(goodRpcProvider.method.callCount).to.equal(2);
    });

    it('should fail if quorum not met', async () => {
      testSyncProviders = [badRpcProvider, badRpcProvider, goodRpcProvider];

      // Quorum required = 2. The 2 BAD RPC providers we supplied should NOT suffice!
      (chainProvider as any).config.quorum = 2;
      (chainProvider as any).providers = testSyncProviders;

      // First, make sure we get the correct value back.
      await expect((chainProvider as any).execute(false, mockMethodParam)).to.be.rejectedWith(QuorumNotMet);
      expect(badRpcProvider.method.callCount).to.equal(2);
      expect(goodRpcProvider.method.callCount).to.equal(1);
    });

    it('should fail if the call needs a signer and needsSigner throws', async () => {
      const testError = new Error('test: needs signer');
      stub(chainProvider as any, 'checkSigner').throws(testError);
      await expect((chainProvider as any).execute(true, () => {})).to.be.rejectedWith(testError);
    });

    it('should error with RpcError if all providers throw an RpcError', async () => {
      testSyncProviders = [badRpcProvider, badRpcProvider, badRpcProvider, badRpcProvider];
      const testError = new RpcError('test error');
      badRpcProvider.method.rejects(testError);

      expect(badRpcProvider.method.callCount).to.equal(0);
      await expect((chainProvider as any).execute(false, mockMethodParam)).to.be.rejectedWith(RpcError);
      expect(badRpcProvider.method.callCount).to.equal(testSyncProviders.length);
    });

    it('should short circuit and throw transaction reverted (i.e. non-RpcError) right away', async () => {
      // Should never reach the "good rpc providers" - we ALWAYS short circuit and throw TransactionReverted error immediately.
      testSyncProviders = [badRpcProvider, goodRpcProvider, goodRpcProvider, goodRpcProvider];
      const revertedError = new TransactionReverted('test error');
      badRpcProvider.method.rejects(revertedError);

      await expect((chainProvider as any).execute(false, mockMethodParam)).to.be.rejectedWith(revertedError);
      expect(goodRpcProvider.method.callCount).to.equal(0);
    });
  });

  describe('#syncProviders', () => {
    const testSyncedBlockNumber = 1234567;
    const testOutOfSyncBlockNumber = 1234000;
    let outOfSyncProvider: SinonStubbedInstance<SyncProvider>;
    let coreSyncProvider: SinonStubbedInstance<SyncProvider>;

    let syncUpdate;

    beforeEach(() => {
      coreSyncProvider = createStubInstance(SyncProvider);
      stub(coreSyncProvider, 'synced').get(() => true);
      stub(coreSyncProvider, 'synced').set(() => false);
      stub(coreSyncProvider, 'syncedBlockNumber').get(() => testSyncedBlockNumber);
      stub(coreSyncProvider, 'priority').set(() => {});
      stub(coreSyncProvider, 'lag').set(() => {});
      stub(coreSyncProvider, 'reliability').set(() => {});
      // stub(coreSyncProvider, 'reliability').get(() => 0.5);
      // stub(coreSyncProvider, 'cps').get(() => 1);
      // stub(coreSyncProvider, 'latency').get(() => 0.5);
      stub(coreSyncProvider, 'name').get(() => 'synced');

      outOfSyncProvider = createStubInstance(SyncProvider);
      stub(outOfSyncProvider, 'synced').get(() => false);
      stub(outOfSyncProvider, 'synced').set(() => false);
      stub(outOfSyncProvider, 'syncedBlockNumber').get(() => testOutOfSyncBlockNumber);
      stub(outOfSyncProvider, 'priority').set(() => {});
      stub(outOfSyncProvider, 'lag').set((updated) => {
        syncUpdate = updated;
      });
      stub(outOfSyncProvider, 'reliability').set(() => {});
      stub(outOfSyncProvider, 'name').get(() => 'synced');

      outOfSyncProvider.sync.callsFake(async () => {
        (outOfSyncProvider as any)._syncedBlockNumber = testOutOfSyncBlockNumber;
      });

      (outOfSyncProvider as any).url = 'https://------badProvider----';
      stub(outOfSyncProvider, 'syncedBlockNumber').get(() => (outOfSyncProvider as any)._syncedBlockNumber);

      // These metrics are used in the calculation algorithm for provider priority: no need to test them for now.
      for (const provider of [coreSyncProvider, outOfSyncProvider]) {
        stub(provider, 'lag').get(() => 0);
        stub(provider, 'priority').get(() => 0);
        stub(provider, 'reliability').get(() => 0.5);
        stub(provider, 'cps').get(() => 1);
        stub(provider, 'latency').get(() => 0.5);
      }
    });

    it('happy', async () => {
      (chainProvider as any).providers = [coreSyncProvider, outOfSyncProvider];
      await (chainProvider as any).syncProviders();

      expect(coreSyncProvider.lag).to.be.eq(0);
      const expectedOutOfSyncLag = testSyncedBlockNumber - testOutOfSyncBlockNumber;
      expect(syncUpdate).to.be.eq(expectedOutOfSyncLag);

      expect(providerStub.getBlockNumber.callCount).to.equal(1);
      expect(outOfSyncProvider.sync.callCount).to.equal(1);

      expect(outOfSyncProvider.synced).to.be.false;
      expect(coreSyncProvider.synced).to.be.true;
    });
  });

  describe('#shuffleSyncedProviders', () => {
    it('happy', async () => {
      const testProviders: SinonStubbedInstance<SyncProvider>[] = [];
      const testMaxLag = 10;
      const lagValues = [0, 0, 0, 1, 2, 2, 4, 5, 7, 10, 12, 17, 19, 42, 123, 456, 789, 999];
      const inSyncProvidersCount = lagValues.filter((lag) => lag <= testMaxLag).length;
      for (const lag of lagValues) {
        const provider = createStubInstance(SyncProvider, {
          sync: Promise.resolve(),
        });
        stub(provider, 'lag').get(() => lag);
        stub(provider, 'synced').get(() => lag <= testMaxLag);
        stub(provider, 'priority').get(() => -9999);
        stub(provider, 'priority').set(() => {});
        stub(provider, 'reliability').get(() => 0.5);
        stub(provider, 'cps').get(() => 1);
        stub(provider, 'latency').get(() => 0.5);
        stub(provider, 'name').get(() => 'non-lead');
        (provider as any).url = 'non-lead provider';
        testProviders.push(provider);
      }
      const leadProviderUrl = 'mr. lead provider';
      (testProviders[0] as any).url = leadProviderUrl;
      (chainProvider as any).providers = testProviders;
      (chainProvider as any).leadProvider = { url: leadProviderUrl };

      const shuffledProviders = await (chainProvider as any).shuffleSyncedProviders();

      expect(shuffledProviders).to.be.an('array');

      // Should return list in order: first <inSyncProvidersCount> are in-sync, remaining are out-of-sync.
      expect(shuffledProviders.slice(0, inSyncProvidersCount).every((p: SyncProvider) => p.synced)).to.be.true;
      expect(shuffledProviders.slice(inSyncProvidersCount).every((p: SyncProvider) => p.synced)).to.be.false;

      // First provider should be the lead provider.
      expect(shuffledProviders[0].url).to.be.eq(leadProviderUrl);

      // Priority should be in ascending order.
      expect(
        shuffledProviders.every((p: SyncProvider, i: number) =>
          i > 0 ? p.priority >= shuffledProviders[i - 1].priority : true,
        ),
      ).to.be.true;
    });
  });
});
