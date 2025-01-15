import { SinonStub, stub } from 'sinon';
import { AxiosQueryError, axiosGet, axiosPost, delay, expect, formatUrl, jsonifyError, parseHostname } from '../../src';
import Axios from 'axios';

describe('Helpers:Axios', () => {
  let postMock: SinonStub;
  let getMock: SinonStub;
  const url = 'http://foo.com';
  const data = { foo: 'bar' };

  beforeEach(() => {
    postMock = stub(Axios, 'post');
    postMock.resolves({ data });
    getMock = stub(Axios, 'get');
    getMock.resolves({ data });
  });

  describe('#delay', () => {
    it('should work', async () => {
      const start = Date.now();
      await delay(100);
      expect(Date.now() - start).to.be.gte(99);
    });
  });

  describe('#axiosPost', () => {
    it('should work', async () => {
      const res = await axiosPost(url, data);
      expect(res.data).to.be.deep.eq(data);
      expect(postMock.calledOnceWithExactly(url, data, undefined)).to.be.true;
    });

    it('should retry', async () => {
      postMock.rejects(new Error('foo'));
      await expect(axiosPost(url, data, undefined, 2)).to.be.rejectedWith(AxiosQueryError);
      expect(postMock.calledTwice).to.be.true;
    });

    it('should throw on error', async () => {
      postMock.rejects(new Error('foo'));
      await expect(axiosPost(url, data, undefined, 1)).to.be.rejectedWith(AxiosQueryError);
    });

    it('should handle axios errors', async () => {
      const error = new Error('foo');
      let callCount = 0;
      (error as any).toJSON = () => {
        callCount++;
        return { message: 'foo' };
      };
      postMock.rejects(error);
      stub(Axios, 'isAxiosError').returns(true);
      await expect(axiosPost(url, data, undefined, 1)).to.be.rejectedWith(AxiosQueryError);
      expect(callCount).to.be.eq(1);
    });
  });

  describe('#axiosGet', () => {
    it('should work', async () => {
      const res = await axiosGet(url, data);
      expect(res.data).to.be.deep.eq(data);
      expect(getMock.calledOnceWithExactly(url, data, undefined)).to.be.true;
    });

    it('should throw on error', async () => {
      getMock.rejects(new Error('foo'));
      await expect(axiosGet(url, data, 1)).to.be.rejectedWith(AxiosQueryError);
    });
  });

  describe('#parseHostname', () => {
    it('should work', () => {
      expect(parseHostname(url)).to.be.eq('foo.com');
    });

    it('should return empty if invalid url', () => {
      expect(parseHostname('test')).to.be.null;
    });
  });

  describe('#formatUrl', () => {
    it('should work', () => {
      expect(formatUrl(url, 'bar')).to.be.eq(`${url}/bar`);
    });

    it('should append the identifier', () => {
      expect(formatUrl(url, 'bar', 'baz')).to.be.eq(`${url}/barbaz`);
    });
  });
});
