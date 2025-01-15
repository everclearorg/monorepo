import { Asset, TIntentStatus, expect, mkBytes32 } from '@chimera-monorepo/utils';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { SinonStub, stub, SinonStubbedInstance } from 'sinon';
import { Interface } from 'ethers/lib/utils';
import { BigNumber } from 'ethers';

import * as AssetHelpers from '../../src/helpers/asset';
import * as IntentHelpers from '../../src/helpers/intent';
import { checkIntentLiquidity, checkIntentStatus } from '../../src/checklist/intent';
import { mock } from '../globalTestHook';
import { MissingDeployments } from '../../src/types';

describe('Checklist:intent', () => {
  describe('#checkIntentStatus', () => {
    let chainreader: SinonStubbedInstance<ChainReader>;
    let subgraph: SinonStubbedInstance<SubgraphReader>;
    let decodeStub: SinonStub;
    let encodeStub: SinonStub;
    beforeEach(() => {
      chainreader = mock.context().adapters.chainreader as SinonStubbedInstance<ChainReader>;
      subgraph = mock.context().adapters.subgraph as SinonStubbedInstance<SubgraphReader>;
      encodeStub = stub(Interface.prototype, 'encodeFunctionData').returns('0x1234');
      decodeStub = stub(Interface.prototype, 'decodeFunctionResult').returns(['0x1234']);

      encodeStub.returns('0x1234');
      decodeStub.returns(['0x1234']);
      chainreader.readTx.resolves('0x1234');

      // origin intent status
      decodeStub.onFirstCall().returns([0]); // none
      // hub intent status
      decodeStub.onSecondCall().returns([{ status: 4 }]); // added and filled
      // destination intent statuses
      decodeStub.onThirdCall().returns([1]); // added
    });

    it('should throw if missing origin everclear', async () => {
      await expect(checkIntentStatus('1337582', ['1338'], mkBytes32('0x1234'))).to.be.rejectedWith(MissingDeployments);
    });

    it('should throw if missing destination everclear', async () => {
      await expect(checkIntentStatus('1337', ['1338582'], mkBytes32('0x1234'))).to.be.rejectedWith(MissingDeployments);
    });

    it('should fail if chainreader.readTx (getting intent status) fails', async () => {
      chainreader.readTx.rejects(new Error('error'));
      await expect(checkIntentStatus('1337', ['1338'], mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });

    it('should fail if subgraph.getOriginIntentById fails', async () => {
      subgraph.getOriginIntentById.rejects(new Error('error'));
      await expect(checkIntentStatus('1337', ['1338'], mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });

    it('should fail if subgraph.getHubIntentById fails', async () => {
      subgraph.getHubIntentById.rejects(new Error('error'));
      await expect(checkIntentStatus('1337', ['1338'], mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });

    it('should fail if subgraph.getDestinationIntentById fails', async () => {
      subgraph.getDestinationIntentById.rejects(new Error('error'));
      await expect(checkIntentStatus('1337', ['1338'], mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });

    it('should work if subgraphs return undefined', async () => {
      const res = await checkIntentStatus('1337', ['1338'], mkBytes32('0x1234'));
      expect(res).to.be.deep.eq({
        origin: TIntentStatus.None,
        hub: TIntentStatus.AddedAndFilled,
        destinations: {
          1338: TIntentStatus.Added,
        },
      });
    });

    it('should handle dispatched statuses', async () => {
      subgraph.getDestinationIntentById.resolves({
        destination: '1338',
        messageId: mkBytes32('0x123333'),
      } as any);
      const res = await checkIntentStatus('1337', ['1338'], mkBytes32('0x1234'));
      expect(res).to.be.deep.eq({
        origin: TIntentStatus.None,
        hub: TIntentStatus.AddedAndFilled,
        destinations: {
          1338: TIntentStatus.Dispatched,
        },
      });
    });
  });

  describe('#checkIntentLiquidity', () => {
    let chainreader: SinonStubbedInstance<ChainReader>;
    let subgraph: SinonStubbedInstance<SubgraphReader>;

    let getAssetFromContract: SinonStub;
    let getTokenFromContract: SinonStub;
    let getRegisteredAssetHashFromContract: SinonStub;
    let getCustodiedAssetsFromHubContract: SinonStub;
    let getIntentContextFromContract: SinonStub;
    let getCurrentEpoch: SinonStub;

    let blockNumber = 10000;
    let discountPerEpoch = 10_000;
    let maxDiscountBps = 50_000;
    let originIntent = mock.originIntent({ id: mkBytes32('0x1234') });
    let tickerHash = mkBytes32('0xticker');
    let custodied = '10000000000';
    beforeEach(() => {
      chainreader = mock.context().adapters.chainreader as SinonStubbedInstance<ChainReader>;
      subgraph = mock.context().adapters.subgraph as SinonStubbedInstance<SubgraphReader>;

      getAssetFromContract = stub(AssetHelpers, 'getAssetFromContract').resolves({
        id: tickerHash,
        approval: true,
      } as unknown as Asset);
      getTokenFromContract = stub(AssetHelpers, 'getTokenFromContract').resolves({
        discountPerEpoch,
        maxDiscountBps,
        id: tickerHash,
        prioritizedStrategy: 'DEFAULT',
        feeAmounts: [],
        feeRecipients: [],
      });
      getRegisteredAssetHashFromContract = stub(AssetHelpers, 'getRegisteredAssetHashFromContract').resolves(
        mkBytes32('0xa5534'),
      );
      getCustodiedAssetsFromHubContract = stub(AssetHelpers, 'getCustodiedAssetsFromHubContract').resolves(custodied);
      getIntentContextFromContract = stub(IntentHelpers, 'getIntentContextFromContract').resolves({
        intentStatus: TIntentStatus.Invoiced,
        amountAfterFees: custodied,
        pendingRewards: custodied,
      } as any);
      getCurrentEpoch = stub(IntentHelpers, 'getCurrentEpoch').resolves(3);

      chainreader.getBlockNumber.resolves(blockNumber);

      subgraph.getOriginIntentById.resolves(originIntent);
      subgraph.getHubInvoiceById.resolves({
        entryEpoch: 1,
      } as any);
    });

    it('should fail if subgraph.getOriginIntentById fails', async () => {
      subgraph.getOriginIntentById.rejects(new Error('error'));
      await expect(checkIntentLiquidity('1337', mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });

    it('should fail if getAssetFromContract fails', async () => {
      getAssetFromContract.rejects(new Error('error'));
      await expect(checkIntentLiquidity('1337', mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });

    it('should fail if getTokenFromContract fails', async () => {
      getTokenFromContract.rejects(new Error('error'));
      await expect(checkIntentLiquidity('1337', mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });

    it('should fail if getRegisteredAssetHashFromContract fails', async () => {
      getRegisteredAssetHashFromContract.rejects(new Error('error'));
      await expect(checkIntentLiquidity('1337', mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });
    it('should fail if getCustodiedAssetsFromHubContract fails', async () => {
      getCustodiedAssetsFromHubContract.rejects(new Error('error'));
      await expect(checkIntentLiquidity('1337', mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });
    it('should fail if getIntentContextFromContract fails', async () => {
      getIntentContextFromContract.rejects(new Error('error'));
      await expect(checkIntentLiquidity('1337', mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });
    it('should fail if subgraph.getHubInvoiceById fails', async () => {
      subgraph.getHubInvoiceById.rejects(new Error('error'));
      await expect(checkIntentLiquidity('1337', mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });

    it('should fail if getCurrentEpoch fails', async () => {
      getCurrentEpoch.rejects(new Error('error'));
      await expect(checkIntentLiquidity('1337', mkBytes32('0x1234'))).to.be.rejectedWith('error');
    });

    it('should work if origin intent is not found in subgraph', async () => {
      subgraph.getOriginIntentById.resolves(undefined);
      const res = await checkIntentLiquidity('1337', mkBytes32('0x1234'));
      expect(res).to.be.deep.eq({
        notice: 'Intent not found in origin subgraph.',
        tickerHash: '',
        elapsedEpochs: 0,
        settlementValue: '0',
        discount: 0,
        invoiceValue: '0',
        unclaimed: {},
      });
    });

    it('should work if input asset is not approved', async () => {
      getAssetFromContract.resolves({
        id: tickerHash,
        approval: false,
      });
      const res = await checkIntentLiquidity('1337', mkBytes32('0x1234'));
      expect(res).to.be.deep.eq({
        notice: 'Unsupported asset. Intent is unsupported.',
        tickerHash,
        elapsedEpochs: 0,
        discount: 0,
        settlementValue: originIntent.amount,
        invoiceValue: originIntent.amount,
        unclaimed: {},
      });
    });

    it('should work if hub intent does not exist', async () => {
      getIntentContextFromContract.resolves({ intentStatus: TIntentStatus.None } as any);
      const res = await checkIntentLiquidity('1337', mkBytes32('0x1234'));
      expect(res).to.be.deep.eq({
        notice: 'Intent not yet registered on the hub.',
        tickerHash,
        elapsedEpochs: 0,
        discount: 0,
        invoiceValue: originIntent.amount,
        settlementValue: originIntent.amount,
        unclaimed: { '1338': { custodied, required: '0' } },
      });
    });

    it('should work if hub intent is not in Invoiced status', async () => {
      getIntentContextFromContract.resolves({
        intentStatus: TIntentStatus.Added,
        amountAfterFees: '1',
        pendingRewards: '2',
      } as any);
      const res = await checkIntentLiquidity('1337', mkBytes32('0x1234'));
      expect(res).to.be.deep.eq({
        notice: 'Discounts not being applied. Status: ADDED',
        tickerHash,
        elapsedEpochs: 2,
        discount: Math.min(2 * discountPerEpoch, maxDiscountBps),
        invoiceValue: '3',
        settlementValue: '3',
        unclaimed: { '1338': { custodied, required: '0' } },
      });
    });

    it('should work if hub invoice is not found', async () => {
      subgraph.getHubInvoiceById.resolves(undefined);
      const res = await checkIntentLiquidity('1337', mkBytes32('0x1234'));
      expect(res).to.be.deep.eq({
        notice: 'Invoice not found in subgraph.',
        tickerHash,
        elapsedEpochs: 0,
        discount: 0,
        invoiceValue: BigNumber.from(custodied).mul(2).toString(),
        unclaimed: { '1338': { custodied, required: custodied } },
        settlementValue: BigNumber.from(custodied).mul(2).toString(),
      });
    });

    it('should work', async () => {
      const res = await checkIntentLiquidity('1337', mkBytes32('0x1234'));
      const invoiceValue = BigNumber.from(custodied).mul(2);
      const discount = Math.min(2 * discountPerEpoch, maxDiscountBps);
      const discounted = invoiceValue.sub(BigNumber.from(invoiceValue).mul(discount).div(100_000));
      expect(res).to.be.deep.eq({
        notice: 'Invoice waiting for settlement.',
        tickerHash,
        elapsedEpochs: 2,
        discount,
        invoiceValue: discounted.toString(),
        settlementValue: '0',
        unclaimed: {
          '1338': { custodied, required: discounted.lte(custodied) ? '0' : invoiceValue.sub(custodied).toString() },
        },
      });
    });
  });
});
