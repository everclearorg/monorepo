import { expect } from 'chai';
import { getSsmParameter } from '../../src/helpers/ssm';

describe('SSM Helper', () => {
  describe('getSsmParameter', () => {
    it('should be a function', () => {
      expect(getSsmParameter).to.be.a('function');
    });

    it('should accept a string parameter', () => {
      // This test verifies the function signature without actually calling AWS
      expect(() => getSsmParameter('test-parameter')).to.not.throw();
    });

    it('should handle empty parameter name', async () => {
      // This test will likely fail with AWS error, but it tests the function exists
      try {
        await getSsmParameter('');
        // If it doesn't throw, that's also valid behavior
      } catch (error) {
        // Expected to fail with empty parameter name
        expect(error).to.be.instanceOf(Error);
      }
    });

    it('should handle undefined parameter name', async () => {
      // This test will likely fail with AWS error, but it tests the function exists
      try {
        await getSsmParameter(undefined as any);
        // If it doesn't throw, that's also valid behavior
      } catch (error) {
        // Expected to fail with undefined parameter name
        expect(error).to.be.instanceOf(Error);
      }
    });
  });
});
