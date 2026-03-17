import { createStubInstance, restore, stub } from 'sinon';
import { expect, Logger } from '../../src';
import * as AxiosHelper from '../../src/helpers/axios';
import { clusterIncidents, fetchRecentIncidents } from '../../src/triage/history';
import { TEST_REPORT } from '../helpers/mock';

describe('triage:history', () => {
  afterEach(() => {
    restore();
  });

  it('fetches paginated incidents and stops on old records', async () => {
    const now = new Date().toISOString();
    const old = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    stub(AxiosHelper, 'axiosGet')
      .onFirstCall()
      .resolves({
        data: {
          data: [{ id: '1', attributes: { name: 'A', status: 'Started', started_at: now, metadata: {} } }],
          pagination: { next: '/next' },
        },
      } as never)
      .onSecondCall()
      .resolves({
        data: {
          data: [{ id: '2', attributes: { name: 'B', status: 'Started', started_at: old, metadata: {} } }],
          pagination: { next: null },
        },
      } as never);

    const incidents = await fetchRecentIncidents(
      { ...TEST_REPORT, logger: createStubInstance(Logger) },
      { apiKey: 'x', requesterEmail: 'y' },
      6,
    );
    expect(incidents.length).to.eq(1);
    expect(incidents[0].id).to.eq('1');
  });

  it('clusters incidents by key', () => {
    const clusters = clusterIncidents([
      { id: '1', name: 'AlertA', status: 'Started', startedAt: new Date().toISOString(), metadata: {} },
      { id: '2', name: 'AlertA', status: 'Started', startedAt: new Date().toISOString(), metadata: {} },
    ]);
    expect(clusters.length).to.eq(1);
    expect(clusters[0].count).to.eq(2);
  });
});
