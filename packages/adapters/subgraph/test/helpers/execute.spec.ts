import { stub, SinonStub } from 'sinon';
import { delay, expect } from '@chimera-monorepo/utils';

import * as Mockable from '../../src/lib/helpers/mockable';
import { execute } from '../../src/lib/helpers/execute';
import { DocumentInvalid } from '../../src/lib/errors';
import { createMeta } from '../mock';

describe('Subgraph Adapter - execute', () => {
  const domain = '1337';
  const endpoints = [`http://localhost:${domain}/graphql`];

  let request: SinonStub;

  beforeEach(() => {
    request = stub(Mockable, 'gqlRequest');
    request.resolves({ data: 'data' });
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
});
