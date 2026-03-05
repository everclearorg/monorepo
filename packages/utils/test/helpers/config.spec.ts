import { SinonStub, stub, restore } from 'sinon';
import Axios from 'axios';

import { expect, getEverclearConfig, mock, parseEverclearConfig } from '../../src';

describe('Helpers:Config', () => {
  describe('#parseEverclearConfig', () => {
    it('should throw if invalid', () => {
      try {
        parseEverclearConfig({ foo: 'bar' });
      } catch (e) {
        expect(e.message).to.contain(`Invalid everclear config`);
      }
    });

    it('should work if valid', () => {
      const config = mock.config();
      expect(parseEverclearConfig(config)).to.be.ok;
    });
  });

  describe('#getEverclearConfig', () => {
    let getMock: SinonStub;

    beforeEach(() => {
      getMock = stub(Axios, 'get');
      getMock.resolves({ data: mock.config() });
    });

    afterEach(() => {
      restore();
    });

    it('should return undefined if url fails', async () => {
      getMock.resolves({});
      const config = await getEverclearConfig('http://foo.com');
      expect(config).to.be.undefined;
      expect(getMock.calledOnceWith('http://foo.com')).to.be.true;
    });

    it('should work with url', async () => {
      const config = await getEverclearConfig('http://foo.com');
      expect(config).to.be.deep.eq(mock.config());
      expect(getMock.calledOnceWith('http://foo.com')).to.be.true;
    });
  });
});
