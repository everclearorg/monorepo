import Axios from 'axios';
import { SinonStub, SinonStubbedInstance, stub, createStubInstance } from 'sinon';
import { Logger, expect, sendHeartbeat } from '../../src';

describe('Health', () => {
  let postStub: SinonStub;
  let mockLogger: SinonStubbedInstance<Logger>;
  beforeEach(() => {
    postStub = stub(Axios, 'post');
    postStub.resolves({ data: 'ok' });

    mockLogger = createStubInstance(Logger);
  });

  describe('#sendHeartbeat', () => {
    it('should work', async () => {
      const res = await sendHeartbeat('http://foo.com', mockLogger);
      expect(res).to.eq('ok');
      expect(postStub.calledOnceWith('http://foo.com')).to.be.true;
    });

    it('should throw if axios throws', async () => {
      postStub.rejects(new Error('bad'));
      await expect(sendHeartbeat('http://foo.com', mockLogger, 1)).to.be.rejected;
    });

    it('should handle undefined returned values', async () => {
      postStub.resolves(undefined);
      const res = await sendHeartbeat('http://foo.com', mockLogger);
      expect(res).to.be.undefined;
    });
  });
});
