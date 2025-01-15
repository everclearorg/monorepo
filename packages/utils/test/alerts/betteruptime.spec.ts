import { SinonStub, stub, SinonStubbedInstance, createStubInstance } from 'sinon';

import {
  alertViaBetterUptime,
  alertViaBetterUptimeIfNeeded,
  BETTERUPTIME_INCIDENTS_URL,
  resolveAlertViaBetterUptime,
} from '../../src/alerts/';
import { createRequestContext, expect, Logger } from '../../src';
import * as Mockable from '../../src/alerts/mockable';
import { TEST_REPORT } from '../helpers/mock';

describe('betteruptime', () => {
  const betterUptimeConfig = {
    apiKey: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    requesterEmail: 'test@test.com',
  };
  const requestContext = createRequestContext('betteruptime test');

  let getStub: SinonStub;
  let postStub: SinonStub;
  let logger: SinonStubbedInstance<Logger>;

  beforeEach(() => {
    postStub = stub(Mockable, 'axiosPost');
    getStub = stub(Mockable, 'axiosGet');
    logger = createStubInstance(Logger);
    logger.child = stub(Logger.prototype, 'child').returns(logger);
    logger.debug = stub(Logger.prototype, 'debug').returns();
    logger.info = stub(Logger.prototype, 'info').returns();
    logger.warn = stub(Logger.prototype, 'warn').returns();
    logger.error = stub(Logger.prototype, 'error').returns();
  });

  describe('alertViaBetteruptime', () => {
    it('Should succeed if config is valid', async () => {
      postStub.resolves();

      await expect(alertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext)).to.not.rejected;
      expect(postStub.callCount).to.be.eq(1);

      const timestamp = TEST_REPORT.timestamp;
      const reason = TEST_REPORT.reason;
      const ids = TEST_REPORT.ids;
      const severity = TEST_REPORT.severity;
      const type = TEST_REPORT.type;

      expect(
        postStub.calledWith(
          BETTERUPTIME_INCIDENTS_URL,
          {
            name: `Everclear ${TEST_REPORT.env} Monitor - ${type}`,
            summary: `Everclear ${TEST_REPORT.env} Alert - ${reason}`,
            description: JSON.stringify({
              severity: severity.toString(),
              timestamp,
              reason,
              ids,
              env: TEST_REPORT.env,
            }),
            push: true,
            sms: false,
            call: false,
            email: true,
            team_wait: 1,
            requester_email: betterUptimeConfig!.requesterEmail,
          },
          {
            headers: { Authorization: `Bearer ${betterUptimeConfig!.apiKey}` },
          },
        ),
      ).to.be.true;
    });

    it('Should fail with a bad api call', async () => {
      postStub.rejects();
      const success = await alertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
      expect(success).to.be.undefined;
      expect(postStub.callCount).to.be.eq(1);
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
      expect(await alertViaBetterUptime(TEST_REPORT, {}, requestContext)).to.not.throw;
    });
  });

  describe('alertViaBetteruptimeIfNeeded', () => {
    beforeEach(() => {
      getStub.resolves({
        data: {
          data: [
            {
              id: '644341015',
              type: 'incident',
              attributes: {
                name: 'Everclear staging Monitor - test',
                http_method: null,
                cause: 'content#<ids: test>',
                url: null,
                incident_group_id: 4451151,
                started_at: '2024-08-30T19:50:14.644Z',
                acknowledged_at: null,
                acknowledged_by: null,
                resolved_at: null,
                resolved_by: null,
                status: 'Started',
                team_name: 'Connext Network',
                response_content: null,
                response_options: null,
                regions: null,
                response_url: null,
                screenshot_url: null,
                origin_url: null,
                escalation_policy_id: null,
                call: false,
                sms: false,
                email: true,
                push: true,
                metadata: {},
              },
              relationships: {},
            },
          ],
          pagination: {},
        },
      });
    });

    it('should skip creating an incident if similar incident exists', async () => {
      await expect(alertViaBetterUptimeIfNeeded(TEST_REPORT, betterUptimeConfig, requestContext)).to.not.rejected;
      expect(postStub.callCount).to.be.eq(0);
    });
  });

  describe('resolveViaBetteruptime', () => {
    beforeEach(() => {
      getStub.resolves({
        data: {
          data: [
            {
              id: '644341015',
              type: 'incident',
              attributes: {
                name: 'Everclear staging Monitor - test',
                http_method: null,
                cause: 'content#<ids: test>',
                url: null,
                incident_group_id: 4451151,
                started_at: '2024-08-30T19:50:14.644Z',
                acknowledged_at: null,
                acknowledged_by: null,
                resolved_at: null,
                resolved_by: null,
                status: 'Started',
                team_name: 'Connext Network',
                response_content: null,
                response_options: null,
                regions: null,
                response_url: null,
                screenshot_url: null,
                origin_url: null,
                escalation_policy_id: null,
                call: false,
                sms: false,
                email: true,
                push: true,
                metadata: {},
              },
              relationships: {},
            },
          ],
          pagination: {},
        },
      });
    });

    it('should work', async () => {
      await expect(resolveAlertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext)).to.not.be.rejected;
      expect(postStub).to.be.calledOnceWith(`https://uptime.betterstack.com/api/v2/incidents/644341015/resolve`, {
        resolved_by: betterUptimeConfig.requesterEmail,
      });
    });
  });
});
