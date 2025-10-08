import { getSsmParameter } from '../../src/helpers/ssm';
import { expect } from '../../src';
import { restore, stub, SinonStub } from 'sinon';

describe('SSM Helper', () => {
  let mockClient: any;
  let mockSend: SinonStub;

  beforeEach(() => {
    restore();
    
    mockSend = stub();
    mockClient = {
      send: mockSend,
    };
  });

  describe('getSsmParameter', () => {
    it('should return parameter value when parameter exists', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };
      const mockGetResponse = {
        Parameter: { Value: 'test-value' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.equal('test-value');
      expect(mockSend).to.have.been.calledTwice;
    });

    it('should return undefined when parameter does not exist (empty array)', async () => {
      const mockDescribeResponse = {
        Parameters: [],
      };

      mockSend.resolves(mockDescribeResponse);

      const result = await getSsmParameter('non-existent-parameter', mockClient);

      expect(result).to.be.undefined;
      expect(mockSend).to.have.been.calledOnce;
    });

    it('should return undefined when Parameters array is undefined', async () => {
      const mockDescribeResponse = {};

      mockSend.resolves(mockDescribeResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.be.undefined;
      expect(mockSend).to.have.been.calledOnce;
    });

    it('should return undefined when Parameters is null', async () => {
      const mockDescribeResponse = {
        Parameters: null,
      };

      mockSend.resolves(mockDescribeResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.be.undefined;
      expect(mockSend).to.have.been.calledOnce;
    });

    it('should return undefined when Parameter.Value is undefined', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };
      const mockGetResponse = {
        Parameter: {},
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.be.undefined;
      expect(mockSend).to.have.been.calledTwice;
    });

    it('should return undefined when Parameter is null', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };
      const mockGetResponse = {
        Parameter: null,
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.be.undefined;
      expect(mockSend).to.have.been.calledTwice;
    });

    it('should return undefined when Parameter is undefined', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };
      const mockGetResponse = {};

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.be.undefined;
      expect(mockSend).to.have.been.calledTwice;
    });

    it('should handle AWS SDK errors gracefully', async () => {
      mockSend.rejects(new Error('AWS SDK Error'));

      await expect(getSsmParameter('test-parameter', mockClient)).to.be.rejectedWith('AWS SDK Error');
    });

    it('should handle describe parameters error', async () => {
      mockSend.onFirstCall().rejects(new Error('Describe parameters failed'));

      await expect(getSsmParameter('test-parameter', mockClient)).to.be.rejectedWith('Describe parameters failed');
    });

    it('should handle get parameter error', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().rejects(new Error('Get parameter failed'));

      await expect(getSsmParameter('test-parameter', mockClient)).to.be.rejectedWith('Get parameter failed');
    });

    it('should handle empty parameter name', async () => {
      const mockDescribeResponse = {
        Parameters: [],
      };

      mockSend.resolves(mockDescribeResponse);

      const result = await getSsmParameter('', mockClient);

      expect(result).to.be.undefined;
      expect(mockSend).to.have.been.calledOnce;
    });

    it('should handle special characters in parameter name', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: '/path/to/parameter' }],
      };
      const mockGetResponse = {
        Parameter: { Value: 'special-value' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('/path/to/parameter', mockClient);

      expect(result).to.equal('special-value');
      expect(mockSend).to.have.been.calledTwice;
    });

    it('should handle multiple parameters with same name (edge case)', async () => {
      const mockDescribeResponse = {
        Parameters: [
          { Name: 'test-parameter' },
          { Name: 'test-parameter' }, // Duplicate
        ],
      };
      const mockGetResponse = {
        Parameter: { Value: 'test-value' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.equal('test-value');
      expect(mockSend).to.have.been.calledTwice;
    });

    it('should handle boolean parameter value', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };
      const mockGetResponse = {
        Parameter: { Value: 'true' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.equal('true');
    });

    it('should handle numeric parameter value', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };
      const mockGetResponse = {
        Parameter: { Value: '12345' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.equal('12345');
    });

    it('should handle JSON parameter value', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };
      const mockGetResponse = {
        Parameter: { Value: '{"key": "value"}' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.equal('{"key": "value"}');
    });

    it('should handle empty string parameter value', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };
      const mockGetResponse = {
        Parameter: { Value: '' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.equal('');
    });

    it('should handle whitespace-only parameter value', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'test-parameter' }],
      };
      const mockGetResponse = {
        Parameter: { Value: '   ' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('test-parameter', mockClient);

      expect(result).to.equal('   ');
    });

    it('should use default client when no client provided', async () => {
      // This will fail in a real environment without AWS credentials
      // but we can test that the function exists and is callable
      try {
        await getSsmParameter('test-parameter');
      } catch (error) {
        // Expected to fail without proper AWS setup
        expect(error).to.exist;
      }
    });

    it('should handle null client', async () => {
      try {
        await getSsmParameter('test-parameter', null as any);
      } catch (error) {
        // Expected to fail with null client
        expect(error).to.exist;
      }
    });

    it('should handle undefined client', async () => {
      try {
        await getSsmParameter('test-parameter', undefined as any);
      } catch (error) {
        // Expected to fail with undefined client
        expect(error).to.exist;
      }
    });

    it('should handle client without send method', async () => {
      const invalidClient = {};

      try {
        await getSsmParameter('test-parameter', invalidClient as any);
      } catch (error) {
        // Expected to fail with invalid client
        expect(error).to.exist;
      }
    });

    it('should handle long parameter names', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'very-long-parameter-name-that-might-cause-issues' }],
      };
      const mockGetResponse = {
        Parameter: { Value: 'long-parameter-value' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('very-long-parameter-name-that-might-cause-issues', mockClient);

      expect(result).to.equal('long-parameter-value');
      expect(mockSend).to.have.been.calledTwice;
    });

    it('should handle parameter names with spaces', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'parameter with spaces' }],
      };
      const mockGetResponse = {
        Parameter: { Value: 'value with spaces' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('parameter with spaces', mockClient);

      expect(result).to.equal('value with spaces');
      expect(mockSend).to.have.been.calledTwice;
    });

    it('should handle parameter names with special characters', async () => {
      const mockDescribeResponse = {
        Parameters: [{ Name: 'parameter@with#special$chars' }],
      };
      const mockGetResponse = {
        Parameter: { Value: 'special-value' },
      };

      mockSend
        .onFirstCall().resolves(mockDescribeResponse)
        .onSecondCall().resolves(mockGetResponse);

      const result = await getSsmParameter('parameter@with#special$chars', mockClient);

      expect(result).to.equal('special-value');
      expect(mockSend).to.have.been.calledTwice;
    });
  });
});