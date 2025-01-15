/* eslint-disable @typescript-eslint/no-explicit-any */
import { Wallet } from 'ethers';
import { restore, reset, createStubInstance, SinonStubbedInstance, stub } from 'sinon';
import { expect, Logger, EverclearError } from '@chimera-monorepo/utils';

import { ChainService } from '../../src/chainservice';
import { TransactionDispatch } from '../../src/dispatch';
import { ConfigurationError, ProviderNotConfigured, TransactionReverted } from '../../src/shared';
import { ChainConfig, DEFAULT_CHAIN_CONFIG } from '../../src/config';
import {
  makeChaiReadable,
  TEST_TX,
  TEST_TX_RECEIPT,
  TEST_SENDER_DOMAIN,
  TEST_REQUEST_CONTEXT,
  TEST_TX_RESPONSE,
} from '../utils';

const logger = new Logger({
  level: process.env.LOG_LEVEL ?? 'debug',
  name: 'ChainServiceTest',
});

let signer: SinonStubbedInstance<Wallet>;
let chainService: ChainService;
let dispatch: SinonStubbedInstance<TransactionDispatch>;
const chains = {
  [TEST_SENDER_DOMAIN.toString()]: {
    ...DEFAULT_CHAIN_CONFIG,
    providers: [{ url: 'https://-------------' }],
    confirmations: 1,
  } as ChainConfig,
};
const wallet = Wallet.createRandom();

/// In these tests, we are testing the outer shell of chainservice - the interface, not the core functionality.
/// For core functionality tests, see dispatch.spec.ts and provider.spec.ts.

describe('ChainService', () => {
  beforeEach(() => {
    dispatch = createStubInstance(TransactionDispatch);
    const wallet = Wallet.createRandom();
    signer = stub(Wallet.prototype);
    signer.sendTransaction.resolves(TEST_TX_RESPONSE);
    signer.getTransactionCount.resolves(TEST_TX_RESPONSE.nonce);
    signer.connect.returns(signer);
    (signer as any)._signingKey = () => wallet.privateKey;
    (signer as any).address = wallet.address;
    signer.getAddress.resolves(wallet.address);
    (ChainService as any).instance = undefined;
    chainService = new ChainService(logger, chains, wallet.privateKey);
    const fake = (chainId: number) => {
      // NOTE: We check to make sure we are only getting the one chainId we expect
      // to get in these unit tests.
      expect(chainId).to.be.eq(TEST_SENDER_DOMAIN);
      return dispatch;
    };
    stub(chainService as any, 'getProvider').callsFake(fake as any);
  });
  afterEach(() => {
    restore();
    reset();
  });
  describe('#constructor', () => {
    it('will not instantiate twice', () => {
      expect(() => {
        new ChainService(logger, {}, wallet.privateKey);
      }).to.throw(EverclearError);
    });
  });
  describe('#sendTx', () => {
    it('happy', async () => {
      dispatch.send.resolves(TEST_TX_RECEIPT);
      const receipt = await chainService.sendTx(TEST_TX, TEST_REQUEST_CONTEXT);
      expect(dispatch.send.callCount).to.be.eq(1);
      expect(dispatch.send.getCall(0).args[0]).to.be.deep.eq(TEST_TX);
      expect(makeChaiReadable(receipt)).to.deep.eq(makeChaiReadable(TEST_TX_RECEIPT));
    });
    it('throws if send fails', async () => {
      const callException = new TransactionReverted(TransactionReverted.reasons.CallException);
      dispatch.send.rejects(callException);
      // We should get the exact error back.
      await expect(chainService.sendTx(TEST_TX, TEST_REQUEST_CONTEXT)).to.be.rejectedWith(callException);
    });
  });
  describe('#getProvider', () => {
    it('errors if cannot get provider', async () => {
      // Replacing this method with the original fn not working.
      (chainService as any).getProvider.restore();
      await expect(chainService.sendTx({ ...TEST_TX, domain: 9999 }, TEST_REQUEST_CONTEXT)).to.be.rejectedWith(
        ProviderNotConfigured,
      );
    });
  });
  describe('#setupProviders', () => {
    it('throws if not a single provider config is provided for a domain', async () => {
      (chainService as any).config = {
        [TEST_SENDER_DOMAIN.toString()]: {
          // Providers list here should never be empty.
          providers: [],
          confirmations: 1,
        },
      };
      expect(() => (chainService as any).setupProviders(context, signer)).to.throw(ConfigurationError);
    });
  });
});
