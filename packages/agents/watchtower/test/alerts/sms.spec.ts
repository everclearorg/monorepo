import { SinonStub, stub, SinonStubbedInstance } from 'sinon';
import { createRequestContext, expect, Logger } from '@chimera-monorepo/utils';

import * as Mockable from '../../src/mockable';
import { alertSMS } from '../../src/alerts';
import { TEST_REPORT } from '../mock';
import { TwillioConfig } from '../../src/lib/entities';
import { mockAppContext } from '../globalTestHook';

describe('alertSMS', () => {
  const requestContext = createRequestContext('sms test');
  let twilioConfig: TwillioConfig;

  let twilioStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;

  beforeEach(() => {
    twilioStub = stub(Mockable, 'sendMessageViaTwilio');
    logger = mockAppContext.logger as SinonStubbedInstance<Logger>;

    twilioConfig = {
      number: '234234234',
      accountSid: 'test-account-sid',
      authToken: 'test-auth-token',
      toPhoneNumbers: ['123-456-789'],
    };
  });

  afterEach(() => {
    twilioStub.restore();
  });

  it('Should not send a message if twilioNumber is undefined', async () => {
    twilioConfig.number = undefined;
    const messages = await alertSMS(TEST_REPORT, twilioConfig, requestContext);

    expect(messages.length).to.eq(0);
  });

  it('Should not send a message  if twilioAccountSid is undefined', async () => {
    twilioConfig.accountSid = undefined;
    const messages = await alertSMS(TEST_REPORT, twilioConfig, requestContext);

    expect(messages.length).to.eq(0);
  });

  it('Should not send a message if twilioAuthToken is undefined', async () => {
    twilioConfig.authToken = undefined;
    const messages = await alertSMS(TEST_REPORT, twilioConfig, requestContext);

    expect(messages.length).to.eq(0);
  });

  it('Should fail if alerting fails', async () => {
    twilioStub.rejects();

    const messages = await alertSMS(TEST_REPORT, twilioConfig, requestContext);

    // No messages should be sent if alerting fails
    expect(messages.length).to.be.eq(0);

    expect(twilioStub.callCount).to.be.eq(twilioConfig.toPhoneNumbers.length);
  });

  it('Should be successful with valid config', async () => {
    twilioStub.resolves();
    await expect(alertSMS(TEST_REPORT, twilioConfig, requestContext)).to.not.rejected;

    expect(twilioStub.callCount).to.be.eq(twilioConfig.toPhoneNumbers.length);
  });

  it('Should send the correct data', async () => {
    const textContent = {
      body: `Watcher Alert!. Reason: ${TEST_REPORT.reason}, type: ${TEST_REPORT.type}, env: ${TEST_REPORT.env}, domains: ${TEST_REPORT.domains.join(',')}`,
      to: twilioConfig.toPhoneNumbers[0],
      from: twilioConfig.number ?? '',
    };

    twilioStub.resolves();
    await expect(alertSMS(TEST_REPORT, twilioConfig, requestContext)).to.not.rejected;
    expect(twilioStub.callCount).to.be.eq(1);

    expect(twilioStub.calledWith(twilioConfig.accountSid, twilioConfig.authToken, textContent)).to.be.true;
  });

  it('Should send a message with the logger', async () => {
    await alertSMS(TEST_REPORT, twilioConfig, requestContext);
    expect(logger.info.callCount).to.be.eq(1);
  });

  it('Should not fail and not send a message if twilioToPhoneNumbers is undefined', async () => {
    twilioConfig.toPhoneNumbers = [];
    await alertSMS(TEST_REPORT, twilioConfig, requestContext);
    expect(twilioStub.callCount).to.be.eq(0);
  });
});
