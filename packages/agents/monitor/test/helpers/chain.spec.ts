import { expect } from '@chimera-monorepo/utils';
import { restore, reset, stub } from 'sinon';
import { getSupportedDomains, getLatestBlockFromBlockMap } from '../../src/helpers/chain';
import { getContextStub, mock } from '../globalTestHook';

describe('chain helpers', () => {
  beforeEach(() => {
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#getSupportedDomains', () => {
    it('should return only evm and tvm domains', () => {
      const chains = {
        '1': { network: 'evm', providers: [], confirmations: 1, deployments: {}, subgraphUrls: [], assets: {} },
        '2': { network: 'tvm', providers: [], confirmations: 1, deployments: {}, subgraphUrls: [], assets: {} },
        '3': { network: 'svm', providers: [], confirmations: 1, deployments: {}, subgraphUrls: [], assets: {} },
        '4': { network: 'evm', providers: [], confirmations: 1, deployments: {}, subgraphUrls: [], assets: {} },
      };
      
      const result = getSupportedDomains(chains);
      expect(result).to.deep.equal(['1', '2', '4']);
    });

    it('should handle missing network property', () => {
      const chains = {
        '1': { providers: [], confirmations: 1, deployments: {}, subgraphUrls: [], assets: {} },
        '2': { network: 'evm', providers: [], confirmations: 1, deployments: {}, subgraphUrls: [], assets: {} },
      };
      
      const result = getSupportedDomains(chains);
      expect(result).to.deep.equal(['2']);
    });

    it('should return empty array when no supported networks', () => {
      const chains = {
        '1': { network: 'svm', providers: [], confirmations: 1, deployments: {}, subgraphUrls: [], assets: {} },
        '2': { network: 'other', providers: [], confirmations: 1, deployments: {}, subgraphUrls: [], assets: {} },
      };
      
      const result = getSupportedDomains(chains);
      expect(result).to.deep.equal([]);
    });
  });

  describe('#getLatestBlockFromBlockMap', () => {
    it('should return undefined when domain not in blockMap', () => {
      const blockMap = new Map();
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          blockMap,
        },
      });
      
      const result = getLatestBlockFromBlockMap('1337');
      expect(result).to.be.undefined;
    });

    it('should return latest block when domain exists', () => {
      const blockMap = new Map([
        ['1337', [
          { number: 100, timestamp: Math.floor(Date.now() / 1000), rpcOrigin: 'https://rpc1.com' },
          { number: 105, timestamp: Math.floor(Date.now() / 1000), rpcOrigin: 'https://rpc2.com' },
          { number: 102, timestamp: Math.floor(Date.now() / 1000), rpcOrigin: 'https://rpc3.com' },
        ]],
      ]);
      
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          blockMap,
        },
      });
      
      const result = getLatestBlockFromBlockMap('1337');
      expect(result?.number).to.equal(105);
    });

    it('should filter by rpcOrigin when provided', () => {
      const blockMap = new Map([
        ['1337', [
          { number: 100, timestamp: Math.floor(Date.now() / 1000), rpcOrigin: 'https://rpc1.com' },
          { number: 105, timestamp: Math.floor(Date.now() / 1000), rpcOrigin: 'https://rpc2.com' },
          { number: 102, timestamp: Math.floor(Date.now() / 1000), rpcOrigin: 'https://RPC1.com' }, // Different case
        ]],
      ]);
      
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          blockMap,
        },
      });
      
      const result = getLatestBlockFromBlockMap('1337', 'https://rpc1.com');
      expect(result?.number).to.equal(102); // Should match case-insensitive
    });

    it('should return undefined when block is too old', () => {
      const oldTimestamp = Math.floor(Date.now() / 1000) - 3000; // More than 2500 seconds old
      const blockMap = new Map([
        ['1337', [
          { number: 100, timestamp: oldTimestamp, rpcOrigin: 'https://rpc1.com' },
        ]],
      ]);
      
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          blockMap,
        },
      });
      
      const result = getLatestBlockFromBlockMap('1337');
      expect(result).to.be.undefined;
    });

    it('should return undefined when no matching rpcOrigin', () => {
      const blockMap = new Map([
        ['1337', [
          { number: 100, timestamp: Math.floor(Date.now() / 1000), rpcOrigin: 'https://rpc1.com' },
        ]],
      ]);
      
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          blockMap,
        },
      });
      
      const result = getLatestBlockFromBlockMap('1337', 'https://nonexistent.com');
      expect(result).to.be.undefined;
    });

    it('should handle empty entry array', () => {
      const blockMap = new Map([
        ['1337', []],
      ]);
      
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          blockMap,
        },
      });
      
      const result = getLatestBlockFromBlockMap('1337');
      expect(result).to.be.undefined;
    });
  });
});