import { stub, SinonStub } from 'sinon';
import { expect } from '@chimera-monorepo/utils';

import * as Mockable from '../../../src/mockable';
import { bindServer } from '../../../src/bindings';

describe('Relayer:Server', () => {
  describe('#bindServer', () => {
    let server: SinonStub;
    let get: SinonStub;
    let post: SinonStub;
    let listen: SinonStub;

    beforeEach(() => {
      get = stub();
      post = stub();
      listen = stub();
      server = stub(Mockable, 'getFastifyInstance');
      server.returns({
        get,
        listen,
        post,
      });
    });

    it('should work', async () => {
      bindServer();
      expect(get.calledWith('/ping')).to.be.true;
      expect(get.calledWith('/address')).to.be.true;
      expect(get.calledWith('/tasks/status/:taskId')).to.be.true;

      expect(post.calledWith('/clear-cache')).to.be.true;
      expect(post.calledWith('/relays/:chainId')).to.be.true;

      expect(listen.calledOnce).to.be.true;
    });
  });
});
