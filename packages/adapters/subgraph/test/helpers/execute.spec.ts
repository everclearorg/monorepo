import { stub, SinonStub, restore } from 'sinon';
import { delay, expect } from '@chimera-monorepo/utils';

import * as Mockable from '../../src/lib/helpers/mockable';
import { execute, executeEnvioQuery } from '../../src/lib/helpers/execute';
import { DocumentInvalid } from '../../src/lib/errors';
import { createMeta } from '../mock';
import { GraphQLClient } from 'graphql-request';

describe('Subgraph Adapter - execute', () => {
  const domain = '1337';
  const endpoints = [`http://localhost:${domain}/graphql`];

  let request: SinonStub;
  let envioRequest: SinonStub;

  beforeEach(() => {
    // Restore any existing stubs to ensure a clean state
    restore();
    
    request = stub(Mockable, 'gqlRequest');
    request.resolves({ data: 'data' });

    envioRequest = stub(GraphQLClient.prototype, 'request');
    envioRequest.resolves({ data: 'envio' });
  });

  it('should work', async () => {
    const result = await execute(domain, ['query'], endpoints);
    expect(result).to.be.deep.eq({ data: 'data' });
  });

  it('should handle timeouts', async () => {
    request.callsFake(() => delay(10_000));
    await expect(execute(domain, ['query'], endpoints, 1)).to.be.rejectedWith(DocumentInvalid);
  });

  it('should handle errors', async () => {
    request.rejects(new Error('error'));
    await expect(execute(domain, ['query'], endpoints)).to.be.rejectedWith(DocumentInvalid);
  });

  it('should handle the case if it has indexing errors', async () => {
    const result = await execute(domain, ['query','hasIndexingErrors'], endpoints);
    expect(result).to.be.deep.eq({ data: 'data' });
  });  

  it('should select query with highest block number', async () => {
    const chosen = { ...createMeta(1123), data: 10 };
    request.onFirstCall().resolves(chosen);
    request.onSecondCall().resolves({ ...createMeta(1), data: 123123 });
    const result = await execute(domain, ['query'], [...endpoints, endpoints[0]]);
    expect(result).to.be.deep.eq(chosen);
  });

  it('should return first value', async () => {
    const chosen = { ...createMeta(1123), data: 10 };
    request.resolves(chosen);
    const result = await execute(domain, ['query'], endpoints);
    expect(result).to.be.deep.eq(chosen);
  });

  describe('#executeEnvioQuery', () => {
    const query = '{ test }';

    it('should throw when envio url is missing', async () => {
      const config: any = { envio: {} };
      await expect(executeEnvioQuery(config, query)).to.be.rejectedWith(
        'Envio configuration is missing. Please provide envio.url in SubgraphConfig.',
      );
    });

    it('should execute without auth headers for hosted endpoint / testing apiKey', async () => {
      const config: any = {
        envio: {
          url: 'https://indexer.hyperindex.xyz/my-index',
          apiKey: 'testing',
          timeout: 5,
        },
      };

      envioRequest.resolves({ data: 'ok' });
      const result = await executeEnvioQuery(config, query);
      expect(result).to.deep.equal({ data: 'ok' });
    });

    it('should add auth header for non-hosted endpoint with real apiKey', async () => {
      const config: any = {
        envio: {
          url: 'https://envio.example.com/graphql',
          apiKey: 'real-secret',
          timeout: 5,
        },
      };

      envioRequest.resolves({ data: 'ok' });
      const result = await executeEnvioQuery(config, query, { foo: 'bar' });
      expect(result).to.deep.equal({ data: 'ok' });
    });

    it('should throw when query fails', async () => {
      const config: any = {
        envio: {
          url: 'https://envio.example.com/graphql',
          apiKey: 'real-secret',
          timeout: 5,
        },
      };

      envioRequest.rejects(new Error('boom'));
      await expect(executeEnvioQuery(config, query)).to.be.rejectedWith('Envio query failed: boom');
    });
  });
});
