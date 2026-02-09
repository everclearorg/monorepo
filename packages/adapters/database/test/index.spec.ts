import { expect, Logger } from '@chimera-monorepo/utils';
import { getDatabase, pool } from '../src';

describe('Database Adapter: getDatabase', () => {
  const defaultDbUri = process.env.DATABASE_URL || 'postgres://postgres:qwerty@localhost:5432/everclear';
  let logger: Logger;

  beforeEach(() => {
    logger = new Logger({
      level: 'info',
      name: 'test',
    });
  });

  after(async () => {
    // Clean up: close the pool once after all tests complete
    if (pool) {
      try {
        await pool.end();
      } catch (e: unknown) {
        // Ignore errors if pool is already closed
        const error = e as Error;
        if (!error.message || !error.message.includes('Called end on pool more than once')) {
          throw error;
        }
      }
    }
  });

  it('should create a new pool on first call when pool is undefined', async () => {
    // Sanity check - the pool should not exist before getDatabase() called
    expect(pool).to.be.undefined;

    // First call - creates the pool
    const database = await getDatabase(defaultDbUri, logger);

    // Verify the pool was created or reused
    expect(pool).to.not.be.undefined;
    expect(pool).to.have.property('query');

    // Verify database functions are available
    expect(database.saveOriginIntents).to.be.a('function');
    expect(database.getCheckPoint).to.be.a('function');
  });

  it('should reuse the same pool instance on subsequent calls (warm Lambda invocation)', async () => {
    const pool1 = pool;
    expect(pool1).to.not.be.undefined;

    // Second call - should reuse the same pool
    const database2 = await getDatabase(defaultDbUri, logger);
    const pool2 = pool;
    expect(pool2).to.not.be.undefined;

    // Verify it's the same instance (same object reference)
    expect(pool2).to.equal(pool1);

    // Verify database functions still work
    expect(database2.saveOriginIntents).to.be.a('function');
    expect(database2.getCheckPoint).to.be.a('function');
  });

  it('should not close the pool between calls', async () => {
    const pool1 = pool;
    expect(pool1).to.not.be.undefined;

    // Check pool is not ended
    expect((pool1 as any).ended).to.be.false;

    // Second call
    await getDatabase(defaultDbUri, logger);
    const pool2 = pool;

    // Verify pool is still not ended and is the same instance
    expect(pool2).to.equal(pool1);
    expect((pool2 as any).ended).to.be.false;
  });

  it('should handle multiple concurrent calls gracefully', async () => {
    const pool1 = pool;
    expect(pool1).to.not.be.undefined;

    // Make multiple concurrent calls (simulating concurrent Lambda invocations)
    const [database1, database2, database3] = await Promise.all([
      getDatabase(defaultDbUri, logger),
      getDatabase(defaultDbUri, logger),
      getDatabase(defaultDbUri, logger),
    ]);

    // All should succeed
    expect(database1).to.not.be.undefined;
    expect(database2).to.not.be.undefined;
    expect(database3).to.not.be.undefined;

    expect(pool).to.equal(pool1);
  });
});
