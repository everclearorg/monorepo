import { SinonStub, stub, SinonStubbedInstance, createStubInstance } from 'sinon';

import * as Mockable from '../../src/alerts/mockable';
import { alertTelegram, createTelegramMessage } from '../../src/alerts';
import { TEST_REPORT } from '../helpers/mock';
import { createRequestContext, expect, Logger, TelegramConfig } from '../../src';

describe('alertTelegram', () => {
  const requestContext = createRequestContext('telegram test');
  const telegram: TelegramConfig = { chatId: '@test', apiKey: 'test-api-key' };

  let axiosPostStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;

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

    await expect(alertTelegram(TEST_REPORT, telegram, requestContext)).to.not.rejected;
    expect(axiosPostStub.callCount).to.be.eq(1);

    const message = `
    <b>Monitor ${TEST_REPORT.env} ${TEST_REPORT.severity} - Alert!</b>
    <strong>Reason: </strong><code>${TEST_REPORT.reason}</code>
    <strong>Type: </strong><code>${TEST_REPORT.type}</code>
    <strong>Environment: </strong><code>${TEST_REPORT.env}</code>
    <strong>Timestamp: </strong><code>${new Date(TEST_REPORT.timestamp).toISOString()}</code>
    <strong>Identifiers: </strong> <code>${TEST_REPORT.ids.join(', ')}</code>
  `;
    expect(message).to.be.eq(createTelegramMessage(TEST_REPORT, false));

    const url = `https://api.telegram.org/bot${telegram.apiKey}/sendMessage`;

    expect(
      axiosPostStub.calledWith(url, {
        chat_id: telegram!.chatId,
        text: message,
        parse_mode: 'Html',
      }),
    ).to.be.true;
  });

  it('Should fail with bad api call', async () => {
    axiosPostStub.rejects();

    const success = await alertTelegram(TEST_REPORT, telegram, requestContext);

    expect(success).to.be.undefined;
    expect(axiosPostStub.callCount).to.be.eq(1);
  });

  it('Should send a message with the logger', async () => {
    await alertTelegram(TEST_REPORT, telegram, requestContext);
    expect(logger.info.callCount).to.be.eq(2); // send, sent
  });

  it('Should not send if undefined config', async () => {
    await alertTelegram(TEST_REPORT, undefined, requestContext);
    expect(logger.info.callCount).to.be.eq(0);
  });

  it('Should not send if missing config keys', async () => {
    await alertTelegram(TEST_REPORT, {}, requestContext);
    expect(logger.info.callCount).to.be.eq(0);
  });
});
