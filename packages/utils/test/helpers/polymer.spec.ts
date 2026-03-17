import { expect } from 'chai';
import { stub, restore } from 'sinon';
import {
  getPolymerMsgDelivered,
  isPolymerRoute,
  POLYMER_DOMAIN_PAIRS,
  POLYMER_RELAYER_URL,
  HyperlaneStatus,
} from '../../src';

describe('Polymer Helper Functions', () => {
  afterEach(() => {
    restore();
  });

  describe('POLYMER_RELAYER_URL', () => {
    it('should have correct URL', () => {
      expect(POLYMER_RELAYER_URL).to.equal('https://relayer.polymer.zone/api/v1');
    });
  });

  describe('POLYMER_DOMAIN_PAIRS', () => {
    it('should contain expected domain pairs', () => {
      expect(POLYMER_DOMAIN_PAIRS).to.deep.include(['1', '25327']);
      expect(POLYMER_DOMAIN_PAIRS).to.deep.include(['8453', '25327']);
      expect(POLYMER_DOMAIN_PAIRS).to.deep.include(['728126428', '25327']);
    });
  });

  describe('isPolymerRoute', () => {
    it('should return true for Ethereum -> Hub', () => {
      expect(isPolymerRoute('1', '25327')).to.be.true;
    });

    it('should return true for Hub -> Ethereum', () => {
      expect(isPolymerRoute('25327', '1')).to.be.true;
    });

    it('should return true for Base -> Hub', () => {
      expect(isPolymerRoute('8453', '25327')).to.be.true;
    });

    it('should return true for Hub -> Base', () => {
      expect(isPolymerRoute('25327', '8453')).to.be.true;
    });

    it('should return true for Tron -> Hub', () => {
      expect(isPolymerRoute('728126428', '25327')).to.be.true;
    });

    it('should return true for Hub -> Tron', () => {
      expect(isPolymerRoute('25327', '728126428')).to.be.true;
    });

    it('should return false for non-Polymer routes', () => {
      expect(isPolymerRoute('1', '8453')).to.be.false;
    });

    it('should return false for unknown domains', () => {
      expect(isPolymerRoute('9999', '25327')).to.be.false;
    });
  });

  describe('getPolymerMsgDelivered', () => {
    it('should return HyperlaneStatus.delivered when API returns success', async () => {
      const messageId = '0x1234567890abcdef';
      const mockResponse = {
        data: {
          success: true,
          data: { status: 'success' },
        },
      };

      stub(require('../../src/helpers/axios'), 'axiosGet').resolves(mockResponse);

      const result = await getPolymerMsgDelivered(messageId);

      expect(result).to.equal(HyperlaneStatus.delivered);
    });

    it('should return HyperlaneStatus.pending when API returns non-success status', async () => {
      const messageId = '0x1234567890abcdef';
      const mockResponse = {
        data: {
          success: true,
          data: { status: 'pending' },
        },
      };

      stub(require('../../src/helpers/axios'), 'axiosGet').resolves(mockResponse);

      const result = await getPolymerMsgDelivered(messageId);

      expect(result).to.equal(HyperlaneStatus.pending);
    });

    it('should return HyperlaneStatus.pending when API returns success: false', async () => {
      const messageId = '0x1234567890abcdef';
      const mockResponse = {
        data: {
          success: false,
          data: { status: 'success' },
        },
      };

      stub(require('../../src/helpers/axios'), 'axiosGet').resolves(mockResponse);

      const result = await getPolymerMsgDelivered(messageId);

      expect(result).to.equal(HyperlaneStatus.pending);
    });

    it('should throw when API call fails', async () => {
      const messageId = '0x1234567890abcdef';

      stub(require('../../src/helpers/axios'), 'axiosGet').rejects(new Error('Network error'));

      try {
        await getPolymerMsgDelivered(messageId);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
        expect((error as Error).message).to.equal('Network error');
      }
    });

    it('should call axiosGet with correct URL and retry count', async () => {
      const messageId = '0xdeadbeef';
      const mockResponse = {
        data: {
          success: true,
          data: { status: 'success' },
        },
      };

      const axiosGetStub = stub(require('../../src/helpers/axios'), 'axiosGet').resolves(mockResponse);

      await getPolymerMsgDelivered(messageId);

      expect(axiosGetStub).to.have.been.calledOnce;
      expect(axiosGetStub.firstCall.args[0]).to.equal(`${POLYMER_RELAYER_URL}/messages/${messageId}`);
      expect(axiosGetStub.firstCall.args[1]).to.be.undefined;
      expect(axiosGetStub.firstCall.args[2]).to.equal(2);
    });
  });
});
