import { SinonStub, stub, SinonStubbedInstance } from 'sinon';
import { createRequestContext, expect, Logger } from '@chimera-monorepo/utils';

import * as Mockable from '../../src/mockable';
import { alertDiscord } from '../../src/alerts';
import { TEST_REPORT } from '../mock';
import { mockAppContext } from '../globalTestHook';
import { Severity } from '../../src/lib/entities';

describe('alertDiscord', () => {
  const requestContext = createRequestContext('discord test');

  const discordWebhookUrl = 'http://discord.com/api/webhooks/test';

  let axiosPostStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;

  const expectedParams = {
    content: 'Severity: Informational - :information_source:',
    username: 'Watcher Alerter',
    avatar_url: '',
    allowed_mentions: { parse: ['everyone'] },
    embeds: [
      {
        color: 0xff3827,
        timestamp: new Date(TEST_REPORT.timestamp).toISOString(),
        title: 'Reason',
        description: '',
        fields: [
          {
            name: 'Type',
            value: TEST_REPORT.type,
          },
          {
            name: 'Environment',
            value: TEST_REPORT.env,
          },
          {
            name: 'Reason',
            value: TEST_REPORT.reason,
          },
          {
            name: 'Domains',
            value: TEST_REPORT.domains.join('\n'),
          },
          {
            name: 'Type',
            value: TEST_REPORT.type || 'Default',
          },
        ],
        url: '',
      },
    ],
  };

  beforeEach(() => {
    axiosPostStub = stub(Mockable, 'axiosPost');
    logger = mockAppContext.logger as SinonStubbedInstance<Logger>;
  });

  it('Should pass with a valid config', async () => {
    axiosPostStub.resolves({ code: 200, data: 'ok' });

    await expect(alertDiscord(TEST_REPORT, discordWebhookUrl, requestContext)).to.not.rejected;
    expect(axiosPostStub.callCount).to.be.eq(1);

    expect(axiosPostStub.calledWith(discordWebhookUrl, expectedParams)).to.be.true;
  });

  it('Should fail if the api call fails', async () => {
    axiosPostStub.rejects();

    const success = await alertDiscord(TEST_REPORT, discordWebhookUrl, requestContext);

    expect(success).to.be.undefined;
    expect(axiosPostStub.callCount).to.be.eq(1);
  });

  it('Should send a message with the logger', async () => {
    await alertDiscord(TEST_REPORT, discordWebhookUrl, requestContext);
    expect(logger.info.callCount).to.be.eq(1);
  });

  it('Should work with a undefined reason', async () => {
    const testReport = TEST_REPORT;
    testReport.reason = undefined as unknown as string;
    const tempExpectedParams = expectedParams;
    tempExpectedParams.embeds[0].fields[2].value = 'No Reason';
    await alertDiscord(testReport, discordWebhookUrl, requestContext);
    expect(axiosPostStub.calledWith(discordWebhookUrl, tempExpectedParams)).to.be.true;
  });

  it('Should work with empty domains', async () => {
    const testReport = TEST_REPORT;
    testReport.domains = [];
    const tempExpectedParams = expectedParams;
    tempExpectedParams.embeds[0].fields[3].value = 'None';
    await alertDiscord(testReport, discordWebhookUrl, requestContext);
    expect(axiosPostStub.calledWith(discordWebhookUrl, tempExpectedParams)).to.be.true;
  });

  it('Should work with warning severity', async () => {
    const testReport = TEST_REPORT;
    testReport.severity = Severity.Warning;
    testReport.domains = [];
    const tempExpectedParams = expectedParams;
    tempExpectedParams.embeds[0].fields[3].value = 'None';
    await alertDiscord(testReport, discordWebhookUrl, requestContext);
    expect(axiosPostStub.calledWith(discordWebhookUrl, tempExpectedParams)).to.be.false;
  });

  it('Should work with critical severity', async () => {
    const testReport = TEST_REPORT;
    testReport.severity = Severity.Critical;
    testReport.domains = [];
    const tempExpectedParams = expectedParams;
    tempExpectedParams.embeds[0].fields[3].value = 'None';
    await alertDiscord(testReport, discordWebhookUrl, requestContext);
    expect(axiosPostStub.calledWith(discordWebhookUrl, tempExpectedParams)).to.be.false;
  });
});
