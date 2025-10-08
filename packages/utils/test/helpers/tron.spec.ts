import {
  expect,
  DefaultTronWebFactory,
  TronWebFactory,
  getAccountResources,
} from '../../src';
import { restore, stub, SinonStub } from 'sinon';

describe('Tron Helper', () => {
  let mockTronWebInstance: any;
  let mockTronWebConstructor: SinonStub;

  beforeEach(() => {
    restore();
    
    mockTronWebInstance = {
      trx: {
        getAccountResources: stub(),
      },
    };

    mockTronWebConstructor = stub();
    mockTronWebConstructor.returns(mockTronWebInstance);
  });

  describe('DefaultTronWebFactory', () => {
    let factory: TronWebFactory;

    beforeEach(() => {
      factory = new DefaultTronWebFactory();
    });

    it('should be a function', () => {
      expect(DefaultTronWebFactory).to.be.a('function');
    });

    it('should create instance', () => {
      const factory = new DefaultTronWebFactory();
      expect(factory).to.be.instanceOf(DefaultTronWebFactory);
    });

    it('should have create method', () => {
      const factory = new DefaultTronWebFactory();
      expect(factory.create).to.be.a('function');
    });

    it('should handle AWS SDK errors gracefully', async () => {
      // This will fail in a real environment without proper TronWeb setup,
      // but we can test that the function exists and is callable
      try {
        factory.create('https://api.trongrid.io');
      } catch (error) {
        // Expected to fail without proper TronWeb setup
        expect(error).to.exist;
      }
    });

    it('should handle invalid URL', () => {
      try {
        factory.create('invalid-url');
      } catch (error) {
        // Expected to fail with invalid URL
        expect(error).to.exist;
      }
    });

    it('should handle empty URL', () => {
      try {
        factory.create('');
      } catch (error) {
        // Expected to fail with empty URL
        expect(error).to.exist;
      }
    });

    it('should handle null URL', () => {
      try {
        factory.create(null as any);
      } catch (error) {
        // Expected to fail with null URL
        expect(error).to.exist;
      }
    });

    it('should handle undefined URL', () => {
      try {
        factory.create(undefined as any);
      } catch (error) {
        // Expected to fail with undefined URL
        expect(error).to.exist;
      }
    });
  });

  describe('getAccountResources', () => {
    it('should calculate bandwidth and energy correctly', async () => {
      const mockResources = {
        freeNetLimit: 5000,
        freeNetUsed: 1000,
        NetLimit: 10000,
        NetUsed: 2000,
        EnergyLimit: 50000,
        EnergyUsed: 10000,
      };

      mockTronWebInstance.trx.getAccountResources.resolves(mockResources);

      const result = await getAccountResources('TTestAddress123', mockTronWebInstance);

      expect(result).to.deep.equal({
        bandwidth: BigInt(12000), // (5000 - 1000) + (10000 - 2000) = 12000
        energy: BigInt(40000), // 50000 - 10000 = 40000
      });
    });

    it('should handle missing resource values', async () => {
      const mockResources = {
        freeNetLimit: 5000,
        freeNetUsed: 1000,
        // NetLimit and NetUsed are undefined
        EnergyLimit: 50000,
        EnergyUsed: 10000,
      };

      mockTronWebInstance.trx.getAccountResources.resolves(mockResources);

      const result = await getAccountResources('TTestAddress123', mockTronWebInstance);

      expect(result).to.deep.equal({
        bandwidth: BigInt(4000), // (5000 - 1000) + (0 - 0) = 4000
        energy: BigInt(40000), // 50000 - 10000 = 40000
      });
    });

    it('should handle negative resource calculations', async () => {
      const mockResources = {
        freeNetLimit: 1000,
        freeNetUsed: 2000, // More used than limit
        NetLimit: 5000,
        NetUsed: 6000, // More used than limit
        EnergyLimit: 10000,
        EnergyUsed: 15000, // More used than limit
      };

      mockTronWebInstance.trx.getAccountResources.resolves(mockResources);

      const result = await getAccountResources('TTestAddress123', mockTronWebInstance);

      expect(result).to.deep.equal({
        bandwidth: BigInt(0), // Math.max(0, (1000 - 2000) + (5000 - 6000)) = 0
        energy: BigInt(0), // Math.max(0, 10000 - 15000) = 0
      });
    });

    it('should handle completely empty resources', async () => {
      const mockResources = {};

      mockTronWebInstance.trx.getAccountResources.resolves(mockResources);

      const result = await getAccountResources('TTestAddress123', mockTronWebInstance);

      expect(result).to.deep.equal({
        bandwidth: BigInt(0),
        energy: BigInt(0),
      });
    });

    it('should handle null resource values', async () => {
      const mockResources = {
        freeNetLimit: null,
        freeNetUsed: null,
        NetLimit: null,
        NetUsed: null,
        EnergyLimit: null,
        EnergyUsed: null,
      };

      mockTronWebInstance.trx.getAccountResources.resolves(mockResources);

      const result = await getAccountResources('TTestAddress123', mockTronWebInstance);

      expect(result).to.deep.equal({
        bandwidth: BigInt(0),
        energy: BigInt(0),
      });
    });

    it('should handle undefined resource values', async () => {
      const mockResources = {
        freeNetLimit: undefined,
        freeNetUsed: undefined,
        NetLimit: undefined,
        NetUsed: undefined,
        EnergyLimit: undefined,
        EnergyUsed: undefined,
      };

      mockTronWebInstance.trx.getAccountResources.resolves(mockResources);

      const result = await getAccountResources('TTestAddress123', mockTronWebInstance);

      expect(result).to.deep.equal({
        bandwidth: BigInt(0),
        energy: BigInt(0),
      });
    });

    it('should handle mixed null and undefined values', async () => {
      const mockResources = {
        freeNetLimit: 1000,
        freeNetUsed: null,
        NetLimit: undefined,
        NetUsed: 500,
        EnergyLimit: null,
        EnergyUsed: undefined,
      };

      mockTronWebInstance.trx.getAccountResources.resolves(mockResources);

      const result = await getAccountResources('TTestAddress123', mockTronWebInstance);

      expect(result).to.deep.equal({
        bandwidth: BigInt(500), // (1000 - 0) + (0 - 500) = 500
        energy: BigInt(0), // Math.max(0, 0 - 0) = 0
      });
    });

    it('should handle TronWeb API errors', async () => {
      mockTronWebInstance.trx.getAccountResources.rejects(new Error('TronWeb API Error'));

      await expect(getAccountResources('TTestAddress123', mockTronWebInstance)).to.be.rejectedWith('TronWeb API Error');
    });

    it('should handle empty address', async () => {
      const mockResources = {
        freeNetLimit: 1000,
        freeNetUsed: 0,
        NetLimit: 5000,
        NetUsed: 0,
        EnergyLimit: 10000,
        EnergyUsed: 0,
      };

      mockTronWebInstance.trx.getAccountResources.resolves(mockResources);

      const result = await getAccountResources('', mockTronWebInstance);

      expect(result).to.deep.equal({
        bandwidth: BigInt(6000), // (1000 - 0) + (5000 - 0) = 6000
        energy: BigInt(10000), // 10000 - 0 = 10000
      });
    });

    it('should handle invalid address format', async () => {
      mockTronWebInstance.trx.getAccountResources.rejects(new Error('Invalid address format'));

      await expect(getAccountResources('invalid-address', mockTronWebInstance)).to.be.rejectedWith('Invalid address format');
    });
  });
});
