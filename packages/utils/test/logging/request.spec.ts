import { createRequestContext } from '../../dist';
import { createLoggingContext, expect } from '../../src';

describe('Logging:Request', () => {
  describe('#getUuid', () => {});
  describe('#createRequestContext', () => {
    it('should work with transferId provided', () => {
      const transferId = 'transferId';
      const requestContext = createRequestContext('methodName', transferId);
      expect(requestContext).to.containSubset({ transferId, origin: 'methodName' });
      expect(requestContext.id).to.be.ok;
    });

    it('should work without transferId provided', () => {
      const requestContext = createRequestContext('methodName');
      expect(requestContext).to.containSubset({ origin: 'methodName' });
      expect(requestContext.id).to.be.ok;
    });
  });

  describe('#createMethodContext', () => {});

  describe('#createLoggingContext', () => {
    it('should work', () => {
      const { methodContext, requestContext } = createLoggingContext('methodName');
      expect(methodContext).to.be.ok;
      expect(requestContext).to.be.ok;
    });

    it('should work with inherited', () => {
      const parent = {
        id: 'id',
        origin: 'origin',
      };
      const { methodContext, requestContext } = createLoggingContext('methodName', parent);
      expect(methodContext).to.be.ok;
      expect(requestContext).to.be.deep.eq(parent);
    });

    it('should append transfer id to inherited', () => {
      const transferId = 'transferId';
      const parent = {
        id: 'id',
        origin: 'origin',
        transferId,
      };
      const { methodContext, requestContext } = createLoggingContext<string>('methodName', parent, transferId);
      expect(methodContext).to.be.ok;
      expect(requestContext).to.be.deep.eq(parent);
    });
  });
});
