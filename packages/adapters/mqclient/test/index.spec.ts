import { expect } from '@chimera-monorepo/utils';
import { stub, createStubInstance } from 'sinon';
import { Queue, Worker } from 'bullmq';
import { Logger } from '@chimera-monorepo/utils';

import { parseRedisUrl, pingRedis, createProducer, createWorker, LIGHTHOUSE_QUEUES } from '../src';

// Prevent tests from opening real Redis connections; no commands are issued, so lazyConnect is safe.
const noConnectOpts = { connection: { lazyConnect: true, maxRetriesPerRequest: null } };

describe('mqclient', () => {
  describe('LIGHTHOUSE_QUEUES', () => {
    it('should have all expected queue names', () => {
      expect(LIGHTHOUSE_QUEUES.INTENT).to.equal('lighthouse-intent');
      expect(LIGHTHOUSE_QUEUES.FILL).to.equal('lighthouse-fill');
      expect(LIGHTHOUSE_QUEUES.SETTLEMENT).to.equal('lighthouse-settlement');
      expect(LIGHTHOUSE_QUEUES.SOLANA).to.equal('lighthouse-solana');
      expect(LIGHTHOUSE_QUEUES.EXPIRED).to.equal('lighthouse-expired');
      expect(LIGHTHOUSE_QUEUES.INVOICE).to.equal('lighthouse-invoice');
    });
  });

  describe('parseRedisUrl', () => {
    it('should parse a simple redis URL', () => {
      const result = parseRedisUrl('redis://localhost:6379');
      expect(result.host).to.equal('localhost');
      expect(result.port).to.equal(6379);
      expect(result.connectTimeout).to.equal(17_000);
      expect(result.maxRetriesPerRequest).to.be.null;
      expect(result.keepAlive).to.equal(30_000);
    });

    it('should default to port 6379 when port is omitted', () => {
      const result = parseRedisUrl('redis://myhost');
      expect(result.host).to.equal('myhost');
      expect(result.port).to.equal(6379);
    });

    it('should parse username and password', () => {
      const result = parseRedisUrl('redis://admin:secret@redis.example.com:6380');
      expect(result.host).to.equal('redis.example.com');
      expect(result.port).to.equal(6380);
      expect(result.username).to.equal('admin');
      expect(result.password).to.equal('secret');
    });

    it('should parse password without username', () => {
      const result = parseRedisUrl('redis://:mypassword@redis.example.com:6379');
      expect(result.host).to.equal('redis.example.com');
      expect(result.password).to.equal('mypassword');
      expect(result).to.not.have.property('username');
    });

    it('should enable TLS for rediss:// protocol', () => {
      const result = parseRedisUrl('rediss://redis.example.com:6380');
      expect(result.tls).to.deep.equal({});
    });

    it('should not set TLS for redis:// protocol', () => {
      const result = parseRedisUrl('redis://redis.example.com:6380');
      expect(result).to.not.have.property('tls');
    });

    it('should set TLS servername from query parameter', () => {
      const result = parseRedisUrl('rediss://privatelink.endpoint:6380?tlsServername=real-redis.example.com');
      expect(result.host).to.equal('privatelink.endpoint');
      expect(result.tls).to.deep.equal({ servername: 'real-redis.example.com' });
    });

    it('should ignore tlsServername for non-TLS URLs', () => {
      const result = parseRedisUrl('redis://localhost:6379?tlsServername=ignored.example.com');
      expect(result).to.not.have.property('tls');
    });

    it('should have a retryStrategy that caps at 5000ms', () => {
      const result = parseRedisUrl('redis://localhost:6379');
      const retryStrategy = result.retryStrategy as (times: number) => number;
      expect(retryStrategy(1)).to.equal(50);
      expect(retryStrategy(10)).to.equal(500);
      expect(retryStrategy(200)).to.equal(5000);
    });
  });

  describe('pingRedis', () => {
    it('should return true when Redis responds with PONG', async () => {
      const mockClient = { status: 'ready', ping: stub().resolves('PONG') };
      const mockQueue = { client: Promise.resolve(mockClient) } as unknown as Queue;

      const result = await pingRedis(mockQueue);
      expect(result).to.be.true;
    });

    it('should return false when Redis does not respond with PONG', async () => {
      const mockClient = { status: 'ready', ping: stub().resolves('NOT_PONG') };
      const mockQueue = { client: Promise.resolve(mockClient) } as unknown as Queue;

      const result = await pingRedis(mockQueue);
      expect(result).to.be.false;
    });

    it('should return false when client status is not ready', async () => {
      const mockClient = { status: 'connecting', ping: stub().resolves('PONG') };
      const mockQueue = { client: Promise.resolve(mockClient) } as unknown as Queue;

      const result = await pingRedis(mockQueue);
      expect(result).to.be.false;
    });

    it('should return false when ping throws an error', async () => {
      const mockClient = { status: 'ready', ping: stub().rejects(new Error('connection refused')) };
      const mockQueue = { client: Promise.resolve(mockClient) } as unknown as Queue;

      const result = await pingRedis(mockQueue);
      expect(result).to.be.false;
    });

    it('should return false when ping times out', async () => {
      const mockClient = {
        status: 'ready',
        ping: stub().returns(new Promise(() => {})), // never resolves
      };
      const mockQueue = { client: Promise.resolve(mockClient) } as unknown as Queue;

      const result = await pingRedis(mockQueue, 50); // 50ms timeout
      expect(result).to.be.false;
    });

    it('should return false when client promise rejects', async () => {
      const mockQueue = { client: Promise.reject(new Error('no connection')) } as unknown as Queue;

      const result = await pingRedis(mockQueue);
      expect(result).to.be.false;
    });
  });

  describe('createProducer', () => {
    let mockLogger: Logger;
    let queue: Queue;

    beforeEach(() => {
      mockLogger = createStubInstance(Logger) as unknown as Logger;
    });

    afterEach(async () => {
      if (queue) {
        await queue.close().catch(() => {});
      }
    });

    it('should return a Queue instance', () => {
      queue = createProducer('redis://localhost:6379', 'test-queue', mockLogger, noConnectOpts);
      expect(queue).to.be.instanceOf(Queue);
    });

    it('should accept custom options', () => {
      queue = createProducer('redis://localhost:6379', 'test-queue', mockLogger, {
        ...noConnectOpts,
        defaultJobOptions: { attempts: 5 },
      });
      expect(queue).to.be.instanceOf(Queue);
    });

    it('should register an error handler that logs errors', () => {
      queue = createProducer('redis://localhost:6379', 'test-queue', mockLogger, noConnectOpts);

      // Simulate an error event
      const testError = new Error('redis connection lost');
      queue.emit('error', testError);

      expect((mockLogger.error as any).calledOnce).to.be.true;
      const call = (mockLogger.error as any).getCall(0);
      expect(call.args[0]).to.equal('Queue "test-queue" Redis connection error');
      expect(call.args[4]).to.deep.include({ queueName: 'test-queue', role: 'producer' });
    });
  });

  describe('createWorker', () => {
    let mockLogger: Logger;
    let worker: Worker;

    beforeEach(() => {
      mockLogger = createStubInstance(Logger) as unknown as Logger;
    });

    afterEach(async () => {
      if (worker) {
        await worker.close().catch(() => {});
      }
    });

    it('should return a Worker instance', () => {
      const processor = stub().resolves();
      worker = createWorker('redis://localhost:6379', 'test-queue', processor, mockLogger, noConnectOpts);
      expect(worker).to.be.instanceOf(Worker);
    });

    it('should accept custom options', () => {
      const processor = stub().resolves();
      worker = createWorker('redis://localhost:6379', 'test-queue', processor, mockLogger, {
        ...noConnectOpts,
        concurrency: 5,
      });
      expect(worker).to.be.instanceOf(Worker);
    });

    it('should register a ready handler that logs info', () => {
      const processor = stub().resolves();
      worker = createWorker('redis://localhost:6379', 'test-queue', processor, mockLogger, noConnectOpts);

      // Simulate a ready event
      worker.emit('ready');

      expect((mockLogger.info as any).calledOnce).to.be.true;
      const call = (mockLogger.info as any).getCall(0);
      expect(call.args[0]).to.equal('Worker "test-queue" Redis connected');
      expect(call.args[3]).to.deep.include({ queueName: 'test-queue', role: 'worker' });
    });

    it('should register an error handler that logs errors', () => {
      const processor = stub().resolves();
      worker = createWorker('redis://localhost:6379', 'test-queue', processor, mockLogger, noConnectOpts);

      // Simulate an error event
      const testError = new Error('redis connection lost');
      worker.emit('error', testError);

      expect((mockLogger.error as any).calledOnce).to.be.true;
      const call = (mockLogger.error as any).getCall(0);
      expect(call.args[0]).to.equal('Worker "test-queue" Redis connection error');
      expect(call.args[4]).to.deep.include({ queueName: 'test-queue', role: 'worker' });
    });
  });
});
