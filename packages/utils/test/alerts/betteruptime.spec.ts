import { SinonStub, stub, SinonStubbedInstance, createStubInstance } from 'sinon';

import {
  alertViaBetterUptime,
  alertViaBetterUptimeIfNeeded,
  BETTERUPTIME_INCIDENTS_URL,
  resolveAlertViaBetterUptime,
} from '../../src/alerts/';
import { createRequestContext, expect, Logger, Severity } from '../../src';
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
            call: false,
            sms: false,
            email: true,
            critical_alert: false,
            requester_email: betterUptimeConfig!.requesterEmail,
            metadata: {
              everclear_env: [TEST_REPORT.env],
              report_type: [type],
              severity_level: [severity.toString()],
              affected_ids: ids,
              timestamp: [timestamp.toString()],
              unique_identifier: [`<ids: ${ids.join(',')}>`]
            }
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

    it('Should handle 422 validation error', async () => {
      const error = {
        response: {
          status: 422,
          data: { error: 'validation failed' }
        }
      };
      postStub.rejects(error);
      
      await alertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
      expect(logger.error.callCount).to.be.eq(1);
      expect(logger.error.getCall(0).args[0]).to.include('v3 validation error');
    });

    it('Should handle 429 rate limit error', async () => {
      const error = {
        response: {
          status: 429,
          headers: { 'retry-after': '60' }
        }
      };
      postStub.rejects(error);
      
      await alertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
      expect(logger.error.callCount).to.be.eq(1);
      expect(logger.error.getCall(0).args[0]).to.include('rate limit exceeded');
    });

    it('Should handle other errors', async () => {
      const error = {
        response: {
          status: 500
        }
      };
      postStub.rejects(error);
      
      await alertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
      expect(logger.error.callCount).to.be.eq(1);
      expect(logger.error.getCall(0).args[0]).to.include('Error sending betterUptime alert');
    });

    it('Should set call and critical_alert to true for Critical severity', async () => {
      postStub.resolves();
      const criticalReport = { ...TEST_REPORT, severity: Severity.Critical };

      await alertViaBetterUptime(criticalReport, betterUptimeConfig, requestContext);
      
      const callArgs = postStub.getCall(0).args[1];
      expect(callArgs.call).to.be.true;
      expect(callArgs.critical_alert).to.be.true;
    });

    it('Should set call and critical_alert to false for non-Critical severity', async () => {
      postStub.resolves();
      const warningReport = { ...TEST_REPORT, severity: Severity.Warning };

      await alertViaBetterUptime(warningReport, betterUptimeConfig, requestContext);
      
      const callArgs = postStub.getCall(0).args[1];
      expect(callArgs.call).to.be.false;
      expect(callArgs.critical_alert).to.be.false;
    });

    it('Should include "none" in affected_ids when ids array is empty', async () => {
      postStub.resolves();
      const reportWithoutIds = { ...TEST_REPORT, ids: [] };

      await alertViaBetterUptime(reportWithoutIds, betterUptimeConfig, requestContext);
      
      const callArgs = postStub.getCall(0).args[1];
      expect(callArgs.metadata.affected_ids).to.deep.equal(['none']);
    });

    it('Should include actual ids in affected_ids when ids array has values', async () => {
      postStub.resolves();
      const reportWithIds = { ...TEST_REPORT, ids: ['id1', 'id2'] };

      await alertViaBetterUptime(reportWithIds, betterUptimeConfig, requestContext);
      
      const callArgs = postStub.getCall(0).args[1];
      expect(callArgs.metadata.affected_ids).to.deep.equal(['id1', 'id2']);
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
                metadata: {
                  everclear_env: ['staging'],
                  report_type: ['test'],
                  severity_level: ['info'],
                  affected_ids: ['test'],
                  timestamp: ['1234567890000'],
                  unique_identifier: ['<ids: test>']
                },
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

    it('should call alertViaBetterUptime directly when report has no IDs', async () => {
      const reportWithoutIds = { ...TEST_REPORT, ids: [] };
      postStub.resolves();
      
      await alertViaBetterUptimeIfNeeded(reportWithoutIds, betterUptimeConfig, requestContext);
      
      // Should call alertViaBetterUptime directly, not check for existing incidents
      expect(getStub.callCount).to.be.eq(0);
      expect(postStub.callCount).to.be.eq(1);
    });

    it('should create new incident if no matching incidents found', async () => {
      // Mock empty response (no matching incidents)
      getStub.resolves({
        data: {
          data: [],
          pagination: {},
        },
      });
      postStub.resolves();
      
      await alertViaBetterUptimeIfNeeded(TEST_REPORT, betterUptimeConfig, requestContext);
      
      expect(getStub.callCount).to.be.eq(1);
      expect(postStub.callCount).to.be.eq(1);
    });

    it('should use byName parameter when searching for incidents', async () => {
      await alertViaBetterUptimeIfNeeded(TEST_REPORT, betterUptimeConfig, requestContext, true);
      
      expect(getStub.callCount).to.be.eq(1);
      expect(postStub.callCount).to.be.eq(0); // Should find matching incident by name
    });

    it('should filter incidents with different status', async () => {
      // Mock response with incident that has 'Resolved' status (should be filtered out)
      getStub.resolves({
        data: {
          data: [
            {
              id: '644341015',
              type: 'incident',
              attributes: {
                name: 'Everclear staging Monitor - test',
                cause: 'content#<ids: test>',
                status: 'Resolved', // This should be filtered out
                metadata: {
                  unique_identifier: ['<ids: test>']
                },
              },
            },
          ],
        },
      });
      postStub.resolves();
      
      await alertViaBetterUptimeIfNeeded(TEST_REPORT, betterUptimeConfig, requestContext);
      
      // Should create new incident because existing one is resolved
      expect(postStub.callCount).to.be.eq(1);
    });

    it('should match incidents by metadata fallback', async () => {
      // Mock response with incident that doesn't have uniqueIds in cause but has it in metadata
      getStub.resolves({
        data: {
          data: [
            {
              id: '644341015',
              type: 'incident',
              attributes: {
                name: 'Everclear staging Monitor - test',
                cause: 'different cause', // No uniqueIds here
                status: 'Started',
                metadata: {
                  unique_identifier: ['<ids: test>'] // But has it in metadata
                },
              },
            },
          ],
        },
      });
      
      await alertViaBetterUptimeIfNeeded(TEST_REPORT, betterUptimeConfig, requestContext);
      
      // Should not create new incident because it found match via metadata
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
                metadata: {
                  everclear_env: ['staging'],
                  report_type: ['test'],
                  severity_level: ['info'],
                  affected_ids: ['test'],
                  timestamp: ['1234567890000'],
                  unique_identifier: ['<ids: test>']
                },
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
      expect(postStub).to.be.calledOnceWith(`https://uptime.betterstack.com/api/v3/incidents/644341015/resolve`, {
        resolved_by: betterUptimeConfig.requesterEmail,
      });
    });

    it('should handle 409 already resolved error', async () => {
      const error = {
        response: { status: 409 }
      };
      postStub.rejects(error);
      
      await resolveAlertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
      expect(logger.info.callCount).to.be.greaterThan(0);
    });

    it('should handle 404 not found error', async () => {
      const error = {
        response: { status: 404 }
      };
      postStub.rejects(error);
      
      await resolveAlertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
      expect(logger.warn.callCount).to.be.greaterThan(0);
    });

    it('should handle other resolve errors', async () => {
      const error = {
        response: { status: 500 }
      };
      postStub.rejects(error);
      
      await resolveAlertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
      expect(logger.error.callCount).to.be.greaterThan(0);
    });

    it('should return early if no IDs and byName is false', async () => {
      const reportWithoutIds = { ...TEST_REPORT, ids: [] };
      
      await resolveAlertViaBetterUptime(reportWithoutIds, betterUptimeConfig, requestContext);
      
      expect(getStub.callCount).to.be.eq(0);
      expect(postStub.callCount).to.be.eq(0);
      expect(logger.warn.callCount).to.be.eq(1);
    });

    it('should proceed if no IDs but byName is true', async () => {
      const reportWithoutIds = { ...TEST_REPORT, ids: [] };
      
      await resolveAlertViaBetterUptime(reportWithoutIds, betterUptimeConfig, requestContext, true);
      
      expect(getStub.callCount).to.be.eq(1);
    });

    it('should return early if no matching incidents found', async () => {
      // Mock empty response
      getStub.resolves({
        data: {
          data: [],
          pagination: {},
        },
      });
      
      await resolveAlertViaBetterUptime(TEST_REPORT, betterUptimeConfig, requestContext);
      
      expect(getStub.callCount).to.be.eq(1);
      expect(postStub.callCount).to.be.eq(0);
      expect(logger.info.callCount).to.be.greaterThan(0);
    });
  });
});
