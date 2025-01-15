import { stub, SinonStub, SinonStubbedInstance } from 'sinon';
import * as MockDiscord from '../../src/alerts/discord';
import * as MockTwilio from '../../src/alerts/sms';
import * as MockTelegram from '../../src/alerts/telegram';
import * as MockBetterupTime from '../../src/alerts/betteruptime';

import { WatcherConfig } from '../../src/lib/entities';
import { Logger, createRequestContext, expect } from '@chimera-monorepo/utils';
import { TEST_REPORT } from '../mock';
import { sendAlerts } from '../../src/helpers';
import { mockAppContext } from '../globalTestHook';

describe('Alerts', () => {
  const requestContext = createRequestContext('Mocks');
  let config = {} as WatcherConfig;

  let discordStub: SinonStub;
  let telegramStub: SinonStub;
  let twilioStub: SinonStub;
  let betteruptimeStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;

  beforeEach(() => {
    discordStub = stub(MockDiscord, 'alertDiscord');
    telegramStub = stub(MockTelegram, 'alertTelegram');
    twilioStub = stub(MockTwilio, 'alertSMS');
    betteruptimeStub = stub(MockBetterupTime, 'alertViaBetterUptime');
    logger = mockAppContext.logger as SinonStubbedInstance<Logger>;
    config = mockAppContext.config;
  });

  afterEach(() => {
    discordStub.restore();
    telegramStub.restore();
    twilioStub.restore();
    betteruptimeStub.restore();
  });

  describe('sendAlerts', () => {
    it('Should push to send an alert based on if a value is in the config', async () => {
      discordStub.resolves();
      telegramStub.resolves();
      twilioStub.resolves();
      betteruptimeStub.resolves();

      await sendAlerts(TEST_REPORT, logger, config, requestContext);

      expect(discordStub.callCount).to.be.eq(1);
      expect(telegramStub.callCount).to.be.eq(1);
      expect(twilioStub.callCount).to.be.eq(1);
      expect(betteruptimeStub.callCount).to.be.eq(1);
    });

    it('No push to send to discord if hook url is not in the config', async () => {
      discordStub.resolves();
      telegramStub.resolves();
      twilioStub.resolves();
      betteruptimeStub.resolves();

      await sendAlerts(TEST_REPORT, logger, { ...config, discordHookUrl: undefined }, requestContext);

      expect(discordStub.callCount).to.be.eq(0);
      expect(telegramStub.callCount).to.be.eq(1);
      expect(twilioStub.callCount).to.be.eq(1);
      expect(betteruptimeStub.callCount).to.be.eq(1);
    });

    it('No push to send to telegram if api key is not in the config', async () => {
      discordStub.resolves();
      telegramStub.resolves();
      twilioStub.resolves();
      betteruptimeStub.resolves();

      await sendAlerts(TEST_REPORT, logger, { ...config, telegram: { apiKey: undefined } }, requestContext);

      expect(discordStub.callCount).to.be.eq(1);
      expect(telegramStub.callCount).to.be.eq(0);
      expect(twilioStub.callCount).to.be.eq(1);
      expect(betteruptimeStub.callCount).to.be.eq(1);
    });

    it('No push to send to betteruptime if api key is not in the config', async () => {
      discordStub.resolves();
      telegramStub.resolves();
      twilioStub.resolves();
      betteruptimeStub.resolves();

      await sendAlerts(TEST_REPORT, logger, { ...config, betterUptime: { apiKey: undefined } }, requestContext);

      expect(discordStub.callCount).to.be.eq(1);
      expect(telegramStub.callCount).to.be.eq(1);
      expect(twilioStub.callCount).to.be.eq(1);
      expect(betteruptimeStub.callCount).to.be.eq(0);
    });

    it('Should call the logger when alerts are sent', async () => {
      const message = 'Alerts sent!!!';

      const { logger: l, ...logged } = TEST_REPORT;
      await sendAlerts(TEST_REPORT, logger, config, requestContext);
      expect(logger.warn.callCount).to.be.eq(1);
      expect(logger.warn.calledWith(message)).to.be.true;
      expect(logger.warn.getCalls()[0].lastArg).to.be.deep.eq({ report: logged });
    });
  });
});
