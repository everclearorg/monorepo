import { SinonStub, stub, SinonStubbedInstance } from 'sinon';

import { alertViaBetterUptime } from '../../src/alerts';
import { createRequestContext, expect, Logger } from '@chimera-monorepo/utils';
import * as Mockable from '../../src/mockable';
import { TEST_REPORT } from '../mock';
import { mockAppContext } from '../globalTestHook';
import { Severity } from '../../src/lib/entities';

describe('alertViaBetterUptime', () => {
  const betterUptimeConfig = {
    apiKey: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    requesterEmail: 'test@test.com',
  };
  const requestContext = createRequestContext('betteruptime test');

  let triggerStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;

  beforeEach(() => {
    triggerStub = stub(Mockable, 'axiosPost');
    logger = mockAppContext.logger as SinonStubbedInstance<Logger>;
  });

  it('Should succeed if config is valid', async () => {
    triggerStub.resolves();

    await expect(alertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext)).to.not.rejected;
    expect(triggerStub.callCount).to.be.eq(1);

    const timestamp = TEST_REPORT.timestamp;
    const reason = TEST_REPORT.reason;
    const domains = TEST_REPORT.domains;
    const severity = TEST_REPORT.severity;
    const type = TEST_REPORT.type;

    expect(
      triggerStub.calledWith(
        'https://betteruptime.com/api/v2/incidents',
        {
          name: `Everclear ${TEST_REPORT.env} Watcher - ${type}`,
          summary: `Everclear ${TEST_REPORT.env} Watcher Alert - ${reason}`,
          description: JSON.stringify({
            severity: severity.toString(),
            timestamp,
            reason,
            domains,
            env: TEST_REPORT.env,
          }),
          push: true,
          sms: false,
          call: severity === Severity.Critical,
          email: true,
          team_wait: 1,
          requester_email: betterUptimeConfig.requesterEmail,
        },
        {
          headers: { Authorization: `Bearer ${betterUptimeConfig.apiKey}` },
        },
      ),
    ).to.be.true;
  });

  it('Should fail with a bad api call', async () => {
    triggerStub.rejects();
    const success = await alertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
    expect(success).to.be.undefined;
    expect(triggerStub.callCount).to.be.eq(1);
    expect(logger.error.callCount).to.be.eq(1);
  });

  it('Should send a message with the logger', async () => {
    await alertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
    expect(logger.info.callCount).to.be.eq(1);
  });

  it('Should fail if config is undefined', async () => {
    await alertViaBetterUptime(TEST_REPORT, undefined, requestContext);
    expect(logger.info.callCount).to.be.eq(0);
  });

  it('Should fail if config is missing keys', async () => {
    await alertViaBetterUptime(TEST_REPORT, {}, requestContext);
    expect(logger.info.callCount).to.be.eq(0);
  });
});
