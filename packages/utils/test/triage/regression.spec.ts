import { createStubInstance, restore, stub } from 'sinon';
import { createRequestContext, expect, Logger, sendAlerts } from '../../src';
import * as TelegramModule from '../../src/alerts/telegram';
import * as DiscordModule from '../../src/alerts/discord';
import * as BetterUptimeModule from '../../src/alerts/betteruptime';
import * as InterceptorModule from '../../src/triage/interceptor';
import { TEST_REPORT } from '../helpers/mock';

describe('triage:regression', () => {
  afterEach(() => {
    restore();
  });

  it('preserves fan-out behavior when triage disabled', async () => {
    const logger = createStubInstance(Logger);
    stub(InterceptorModule, 'triageInterceptor').resolves({
      report: TEST_REPORT,
      shouldAutoResolve: false,
    });
    const telegramStub = stub(TelegramModule, 'alertTelegram').resolves();
    const discordStub = stub(DiscordModule, 'alertDiscord').resolves();
    const betterUptimeStub = stub(BetterUptimeModule, 'alertViaBetterUptimeIfNeeded').resolves();

    await sendAlerts(
      TEST_REPORT,
      logger,
      {
        network: 'mainnet',
        triage: { mode: 'disabled' },
        telegram: { apiKey: 'x', chatId: 'y' },
        discord: { url: 'https://discord.com' },
        betterUptime: { apiKey: 'k', requesterEmail: 'e@x.com' },
      },
      createRequestContext('test'),
    );

    expect(telegramStub.calledOnce).to.eq(true);
    expect(discordStub.calledOnce).to.eq(true);
    expect(betterUptimeStub.calledOnce).to.eq(true);
  });
});
