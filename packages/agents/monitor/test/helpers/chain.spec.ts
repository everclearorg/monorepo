import { expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance } from 'sinon';
import { getLatestBlockFromBlockMap } from '../../src/helpers/chain';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';

describe('getLatestBlockFromBlockMap', () => {
  let blockMap: Map<string, any[]>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });

    blockMap = new Map();
    getContextStub.returns({
      ...mock.context(),
      adapters: {
        ...mock.context().adapters,
        blockMap,
      },
    });
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#getLatestBlockFromBlockMap', () => {
    it('should return undefined if domain not in blockMap', () => {
      const result = getLatestBlockFromBlockMap('nonexistent');
      expect(result).to.be.undefined;
    });

    it('should return undefined if no entries for domain', () => {
      blockMap.set('1337', []);
      const result = getLatestBlockFromBlockMap('1337');
      expect(result).to.be.undefined;
    });

    it('should return latest block when no rpcOrigin specified', () => {
      const now = Math.floor(Date.now() / 1000);
      blockMap.set('1337', [
        { number: 100, timestamp: now - 1, rpcOrigin: 'rpc1' },
        { number: 200, timestamp: now - 2, rpcOrigin: 'rpc2' },
      ]);
      const result = getLatestBlockFromBlockMap('1337');
      expect(result).to.deep.equal({ number: 200, timestamp: now - 2, rpcOrigin: 'rpc2' });
    });

    it('should return latest block for specific rpcOrigin', () => {
      const now = Math.floor(Date.now() / 1000);
      blockMap.set('1337', [
        { number: 100, timestamp: now - 1, rpcOrigin: 'rpc1' },
        { number: 200, timestamp: now - 2, rpcOrigin: 'rpc2' },
      ]);
      const result = getLatestBlockFromBlockMap('1337', 'rpc1');
      expect(result).to.deep.equal({ number: 100, timestamp: now - 1, rpcOrigin: 'rpc1' });
    });

    it('should return undefined if block is too old (TTL exceeded)', () => {
      const oldTimestamp = Math.floor(Date.now() / 1000) - 3000; // 3 seconds ago, exceeds TTL of 2.5s
      blockMap.set('1337', [
        { number: 100, timestamp: oldTimestamp, rpcOrigin: 'rpc1' },
      ]);
      const result = getLatestBlockFromBlockMap('1337');
      expect(result).to.be.undefined;
    });

    it('should return block if within TTL', () => {
      const recentTimestamp = Math.floor(Date.now() / 1000) - 1; // 1 second ago, within TTL
      blockMap.set('1337', [
        { number: 100, timestamp: recentTimestamp, rpcOrigin: 'rpc1' },
      ]);
      const result = getLatestBlockFromBlockMap('1337');
      expect(result).to.deep.equal({ number: 100, timestamp: recentTimestamp, rpcOrigin: 'rpc1' });
    });

    it('should handle case insensitive rpcOrigin matching', () => {
      const now = Math.floor(Date.now() / 1000);
      blockMap.set('1337', [
        { number: 100, timestamp: now - 1, rpcOrigin: 'RPC1' },
        { number: 200, timestamp: now - 2, rpcOrigin: 'rpc2' },
      ]);
      const result = getLatestBlockFromBlockMap('1337', 'rpc1');
      expect(result).to.deep.equal({ number: 100, timestamp: now - 1, rpcOrigin: 'RPC1' });
    });

    it('should return undefined if no matching rpcOrigin found', () => {
      const now = Math.floor(Date.now() / 1000);
      blockMap.set('1337', [
        { number: 100, timestamp: now - 1, rpcOrigin: 'rpc1' },
        { number: 200, timestamp: now - 2, rpcOrigin: 'rpc2' },
      ]);
      const result = getLatestBlockFromBlockMap('1337', 'nonexistent');
      expect(result).to.be.undefined;
    });
  });
});

