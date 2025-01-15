import { SinonStub, stub } from 'sinon';
import Axios from 'axios';

import { EVERCLEAR_CONFIG_URL, expect, getEverclearConfig, mock, parseEverclearConfig } from '../../src';

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

    it('should return undefined if it axios.get fails and fallback fails', async () => {
      getMock.resolves({});
      const config = await getEverclearConfig('http://foo.com');
      expect(config).to.be.undefined;
      expect(getMock.firstCall.firstArg).to.be.eq('http://foo.com');
      expect(getMock.secondCall.firstArg).to.be.eq(EVERCLEAR_CONFIG_URL);
    });

    it('should query fallback if url fails', async () => {
      getMock.onFirstCall().resolves({});
      const config = await getEverclearConfig('http://foo.com');
      expect(config).to.be.deep.eq(mock.config());
      expect(getMock.firstCall.firstArg).to.be.eq('http://foo.com');
      expect(getMock.secondCall.firstArg).to.be.eq(EVERCLEAR_CONFIG_URL);
    });

    it('should work with no url', async () => {
      const config = await getEverclearConfig();
      expect(config).to.be.deep.eq(mock.config());
      expect(getMock.calledOnceWith(EVERCLEAR_CONFIG_URL)).to.be.true;
    });

    it('should work with url', async () => {
      const config = await getEverclearConfig('http://foo.com');
      expect(config).to.be.deep.eq(mock.config());
      expect(getMock.calledOnceWith('http://foo.com')).to.be.true;
    });
  });
});
