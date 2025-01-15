import { expect } from '../../src';
import { restore, reset, stub, SinonStub } from 'sinon';
import Axios from 'axios';

import { chainDataToMap, getChainData } from '../../src';

const mockChainData = [
  {
    name: 'Unit Test Chain 1',
    chainId: '1337',
    domainId: '1337',
    confirmations: 1,
    assetId: {},
  },
  {
    name: 'Unit Test Chain 2',
    chainId: '1338',
    confirmations: 1,
    assetId: {},
  },
];

describe('Peripherals:ChainData', () => {
  describe('#chainDataToMap', () => {
    it('happy: should parse data', async () => {
      const chainDataMap = await chainDataToMap(mockChainData);
      expect(chainDataMap.get('1337')).to.be.deep.eq({
        name: 'Unit Test Chain 1',
        chainId: '1337',
        domainId: '1337',
        confirmations: 1,
        assetId: {},
      });
      expect(chainDataMap.get('1338')).to.be.undefined;
    });
  });

  describe('#getChainData', () => {
    let fetchJsonStub: SinonStub;
    beforeEach(() => {
      fetchJsonStub = stub(Axios, 'get');
      fetchJsonStub.resolves({ data: mockChainData });
    });

    afterEach(() => {
      restore();
      reset();
    });

    it('happy: should fetch json and parse it successfully', async () => {
      const res = await getChainData();
      expect(res.get('1337')).to.be.deep.eq({
        name: 'Unit Test Chain 1',
        chainId: '1337',
        domainId: '1337',
        confirmations: 1,
        assetId: {},
      });
      expect(res.get('1338')).to.be.undefined;
    });

    it('should throw error if fetching fails', async () => {
      fetchJsonStub.throws(new Error('Invalid url!'));
      await expect(getChainData(1)).to.be.rejectedWith(
        'Could not get chain data, and no cached chain data was available.',
      );
    });
  });
});
