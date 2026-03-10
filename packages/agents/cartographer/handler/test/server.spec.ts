import { expect, Logger, mkBytes32 } from '@chimera-monorepo/utils';
import { createStubInstance, SinonStubbedInstance } from 'sinon';
import { FastifyInstance } from 'fastify';
import { Database } from '@chimera-monorepo/database';

import { createServer, ServerState, PAUSE_CHECKPOINT_KEY } from '../src/server';
import { createAppContext } from './mock';

const ADMIN_TOKEN = 'test-admin-token';

describe('server', () => {
  let server: FastifyInstance;
  let state: ServerState;

  beforeEach(async () => {
    state = {
      appContext: createAppContext(),
      isPaused: false,
      webhookSecret: 'test-secret',
      adminToken: ADMIN_TOKEN,
    };
    server = createServer(state, createStubInstance(Logger));
    await server.ready();
  });

  afterEach(async () => {
    await server.close();
  });

  describe('GET /health', () => {
    it('should report paused: false by default', async () => {
      const res = await server.inject({ method: 'GET', url: '/health' });
      expect(res.statusCode).to.equal(200);
      const body = JSON.parse(res.payload);
      expect(body.paused).to.equal(false);
    });

    it('should report paused: true when paused', async () => {
      state.isPaused = true;
      const res = await server.inject({ method: 'GET', url: '/health' });
      const body = JSON.parse(res.payload);
      expect(body.paused).to.equal(true);
    });
  });

  describe('POST /pause', () => {
    it('should return 401 without auth token', async () => {
      const res = await server.inject({ method: 'POST', url: '/pause' });
      expect(res.statusCode).to.equal(401);
    });

    it('should return 401 with invalid auth token', async () => {
      const res = await server.inject({
        method: 'POST',
        url: '/pause',
        headers: { authorization: 'Bearer wrong-token' },
      });
      expect(res.statusCode).to.equal(401);
    });

    it('should set isPaused to true and persist to database', async () => {
      const res = await server.inject({
        method: 'POST',
        url: '/pause',
        headers: { authorization: `Bearer ${ADMIN_TOKEN}` },
      });
      expect(res.statusCode).to.equal(200);
      const body = JSON.parse(res.payload);
      expect(body.paused).to.equal(true);
      expect(state.isPaused).to.equal(true);
      const db = state.appContext!.adapters.database as unknown as SinonStubbedInstance<Database>;
      expect(db.saveCheckPoint.calledOnceWith(PAUSE_CHECKPOINT_KEY, 1)).to.be.true;
    });
  });

  describe('POST /resume', () => {
    it('should return 401 without auth token', async () => {
      const res = await server.inject({ method: 'POST', url: '/resume' });
      expect(res.statusCode).to.equal(401);
    });

    it('should return 401 with invalid auth token', async () => {
      const res = await server.inject({
        method: 'POST',
        url: '/resume',
        headers: { authorization: 'Bearer wrong-token' },
      });
      expect(res.statusCode).to.equal(401);
    });

    it('should set isPaused to false and persist to database', async () => {
      state.isPaused = true;
      const res = await server.inject({
        method: 'POST',
        url: '/resume',
        headers: { authorization: `Bearer ${ADMIN_TOKEN}` },
      });
      expect(res.statusCode).to.equal(200);
      const body = JSON.parse(res.payload);
      expect(body.paused).to.equal(false);
      expect(state.isPaused).to.equal(false);
      const db = state.appContext!.adapters.database as unknown as SinonStubbedInstance<Database>;
      expect(db.saveCheckPoint.calledWith(PAUSE_CHECKPOINT_KEY, 0)).to.be.true;
    });
  });

  describe('POST /webhooks/:webhookName (paused)', () => {
    it('should skip processing and return 200 when paused', async () => {
      state.isPaused = true;
      const res = await server.inject({
        method: 'POST',
        url: '/webhooks/hub-meta',
        headers: { 'goldsky-webhook-secret': 'test-secret' },
        payload: { domain: '1339', epoch: 1 },
      });
      expect(res.statusCode).to.equal(200);
      const body = JSON.parse(res.payload);
      expect(body.processed).to.equal(false);
      expect(body.message).to.include('paused');
    });

    it('should process normally when not paused', async () => {
      const res = await server.inject({
        method: 'POST',
        url: '/webhooks/hub-meta',
        headers: { 'goldsky-webhook-secret': 'test-secret' },
        payload: { _gs_gid: 'gid-1', domain: '1339', epoch: 1 },
      });
      expect(res.statusCode).to.equal(200);
      const body = JSON.parse(res.payload);
      expect(body.processed).to.equal(true);
    });

    it('should resume processing after pause/resume cycle', async () => {
      const authHeaders = { authorization: `Bearer ${ADMIN_TOKEN}` };

      // Pause
      await server.inject({ method: 'POST', url: '/pause', headers: authHeaders });

      // Webhook should be skipped
      const skipped = await server.inject({
        method: 'POST',
        url: '/webhooks/hub-meta',
        headers: { 'goldsky-webhook-secret': 'test-secret' },
        payload: { domain: '1339', epoch: 1 },
      });
      expect(JSON.parse(skipped.payload).processed).to.equal(false);

      // Resume
      await server.inject({ method: 'POST', url: '/resume', headers: authHeaders });

      // Webhook should be processed
      const processed = await server.inject({
        method: 'POST',
        url: '/webhooks/hub-meta',
        headers: { 'goldsky-webhook-secret': 'test-secret' },
        payload: { _gs_gid: 'gid-2', domain: '1339', epoch: 1 },
      });
      expect(JSON.parse(processed.payload).processed).to.equal(true);
    });
  });
});
