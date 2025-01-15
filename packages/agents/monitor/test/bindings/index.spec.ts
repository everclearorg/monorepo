import { stub, SinonStub } from 'sinon';

import * as Mockable from '../../src/mockable';
import { bindServer } from '../../src/bindings';

describe('Monitor:Server', () => {
  describe('#bindServer', () => {
    let server: SinonStub;
    let get: SinonStub;
    let post: SinonStub;
    let listen: SinonStub;

    beforeEach(() => {
      get = stub();
      post = stub();
      listen = stub();
      server = stub(Mockable, 'getContract');
      server.returns({
        get,
        listen,
        post,
      });
    });

    it('should work', async () => {
      //TODO - Fix this test
      await bindServer();
      // expect(get.calledWith('/ping')).to.be.true;
      // expect(get.calledWith('/message-status/:originDomain/:destinationDomain/:intentId')).to.be.true;

      // expect(listen.calledOnce).to.be.true;
    });
  });
});
