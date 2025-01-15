import { SinonStub, stub, SinonStubbedInstance, createStubInstance } from 'sinon';

import * as Mockable from '../../src/alerts/mockable';
import { alertDiscord } from '../../src/alerts';
import { TEST_REPORT } from '../helpers/mock';
import { createRequestContext, expect, Logger, Severity } from '../../src';

describe('alertDiscord', () => {
  const requestContext = createRequestContext('discord test');

  const discordWebhookUrl = 'http://discord.com/api/webhooks/test';

  let axiosPostStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;

  const expectedParams = {
    content: 'Severity: Informational - :information_source:',
    username: 'Alert',
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
            name: 'Identifiers',
            value: TEST_REPORT.ids.join('\n'),
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
    logger = createStubInstance(Logger);
    logger.child = stub(Logger.prototype, 'child').returns(logger);
    logger.debug = stub(Logger.prototype, 'debug').returns();
    logger.info = stub(Logger.prototype, 'info').returns();
    logger.warn = stub(Logger.prototype, 'warn').returns();
    logger.error = stub(Logger.prototype, 'error').returns();
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
    expect(logger.info.callCount).to.be.eq(2); // sending, sent
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
    testReport.ids = [];
    const tempExpectedParams = expectedParams;
    tempExpectedParams.embeds[0].fields[3].value = 'None';
    await alertDiscord(testReport, discordWebhookUrl, requestContext);
    expect(axiosPostStub.calledWith(discordWebhookUrl, tempExpectedParams)).to.be.true;
  });

  it('Should work with warning severity', async () => {
    const testReport = TEST_REPORT;
    testReport.severity = Severity.Warning;
    testReport.ids = [];
    const tempExpectedParams = expectedParams;
    tempExpectedParams.embeds[0].fields[3].value = 'None';
    await alertDiscord(testReport, discordWebhookUrl, requestContext);
    expect(axiosPostStub.calledWith(discordWebhookUrl, tempExpectedParams)).to.be.false;
  });

  it('Should work with critical severity', async () => {
    const testReport = TEST_REPORT;
    testReport.severity = Severity.Critical;
    testReport.ids = [];
    const tempExpectedParams = expectedParams;
    tempExpectedParams.embeds[0].fields[3].value = 'None';
    await alertDiscord(testReport, discordWebhookUrl, requestContext);
    expect(axiosPostStub.calledWith(discordWebhookUrl, tempExpectedParams)).to.be.false;
  });
});
