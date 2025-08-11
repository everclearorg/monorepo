/**
 * BETTERSTACK INTEGRATION TEST
 * 
 * This test file is NOT run as part of CI and requires manual execution.
 * It tests the actual Betterstack v3 API integration end-to-end.
 * 
 * PREREQUISITES:
 * 1. Update .env file with your actual Betterstack credentials
 * 2. Set BETTERSTACK_API_KEY in .env
 * 3. Set BETTERSTACK_REQUESTER_EMAIL in .env  
 * 4. Have a valid Betterstack account with API access
 * 
 * To run:
 * cd packages/utils
 * yarn test:integration
 * 
 * WARNING: This will create and resolve real incidents in your Betterstack account!
 */

import * as dotenv from 'dotenv';
import * as path from 'path';
import { expect } from 'chai';

// Load environment variables from .env file
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
import {
  alertViaBetterUptime,
  alertViaBetterUptimeIfNeeded,
  resolveAlertViaBetterUptime,
  BETTERUPTIME_INCIDENTS_URL,
} from '../../src/alerts/betteruptime';
import { createRequestContext, Logger, Severity } from '../../src';
import { BetterUptimeConfig, Report } from '../../src/helpers';
import { axiosGet } from '../../src/alerts/mockable';

describe('Betterstack v3 Integration Tests', function () {
  // Skip if no API credentials provided
  before(function () {
    if (!process.env.BETTERSTACK_API_KEY || !process.env.BETTERSTACK_REQUESTER_EMAIL) {
      console.log('⚠️  Skipping Betterstack integration tests - API credentials not provided');
      console.log('   Set BETTERSTACK_API_KEY and BETTERSTACK_REQUESTER_EMAIL environment variables to run');
      this.skip();
    }
  });

  const betterUptimeConfig: BetterUptimeConfig = {
    apiKey: process.env.BETTERSTACK_API_KEY!,
    requesterEmail: process.env.BETTERSTACK_REQUESTER_EMAIL!,
  };

  const requestContext = createRequestContext('betteruptime integration test');
  const logger = new Logger({ level: 'info' });

  // Create unique test identifiers to avoid conflicts
  const testId = `test-${Date.now()}`;
  const createdIncidentIds: string[] = [];

  // Test report templates
  const createTestReport = (overrides: Partial<Report> = {}): Report => ({
    timestamp: Date.now(),
    reason: `Integration test incident ${testId}`,
    ids: [testId],
    logger,
    type: 'integration-test',
    severity: Severity.Warning,
    env: 'integration',
    ...overrides,
  });

  // Cleanup helper
  const cleanupIncidents = async () => {
    console.log(`🧹 Cleaning up ${createdIncidentIds.length} test incidents...`);

    for (const incidentId of createdIncidentIds) {
      try {
        const response = await fetch(`${BETTERUPTIME_INCIDENTS_URL}/${incidentId}/resolve`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${betterUptimeConfig.apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            resolved_by: betterUptimeConfig.requesterEmail,
          }),
        });

        if (response.ok) {
          console.log(`✅ Resolved incident ${incidentId}`);
        } else if (response.status === 409) {
          console.log(`ℹ️  Incident ${incidentId} already resolved`);
        } else {
          console.log(`⚠️  Failed to resolve incident ${incidentId}: ${response.status}`);
        }
      } catch (error) {
        console.log(`❌ Error resolving incident ${incidentId}:`, error);
      }
    }
  };

  // Clean up after all tests
  after(async function () {
    await cleanupIncidents();
  });

  describe('Creating Incidents', function () {
    it('should create a new incident via alertViaBetterUptime', async function () {
      console.log(`🔔 Creating test incident with ID: ${testId}`);

      const testReport = createTestReport();
      const response = await alertViaBetterUptime(testReport, betterUptimeConfig, requestContext);
      console.log('response', response);

      expect(response).to.exist;
      expect(response.data).to.exist;
      console.log('attributes', response?.data.data.attributes)
      console.log('metadata', response?.data.data.attributes.metadata)

      // Extract incident ID from response for cleanup
      if (response.data?.data?.id) {
        createdIncidentIds.push(response.data.data.id);
        console.log(`✅ Created incident with ID: ${response.data.data.id}`);
      }

      // Verify the incident exists in Betterstack
      const incidents = await axiosGet(`${BETTERUPTIME_INCIDENTS_URL}?per_page=10`, {
        headers: { Authorization: `Bearer ${betterUptimeConfig.apiKey}` },
      });

      const createdIncident = incidents.data.data.find((inc: any) =>
        inc.attributes.name.includes('integration-test') &&
        inc.attributes.cause.includes(testId)
      );

      expect(createdIncident).to.exist;
      console.log(`✅ Verified incident exists in Betterstack`);
    });
  });

  describe('Alert If Needed', function () {
    it('should create incident when no matching incident exists, and skip creating if it does not', async function () {
      const uniqueId = `no-match-${testId}`;
      const testReport = createTestReport({
        ids: [uniqueId],
        reason: `No matching incident test ${uniqueId}`
      });
      const pageLimit = 10;

      console.log(`🔔 Testing alert creation for unique ID: ${uniqueId}`);

      let incidents = await axiosGet(`${BETTERUPTIME_INCIDENTS_URL}?per_page=${pageLimit}`, {
        headers: { Authorization: `Bearer ${betterUptimeConfig.apiKey}` },
      })
      const initial = incidents.data.data.length;

      // This should create a new incident since there's no matching one
      await alertViaBetterUptimeIfNeeded(testReport, betterUptimeConfig, requestContext);

      // Wait a moment for the incident to be created
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Verify the incident was created
      incidents = await axiosGet(`${BETTERUPTIME_INCIDENTS_URL}?per_page=${pageLimit}`, {
        headers: { Authorization: `Bearer ${betterUptimeConfig.apiKey}` },
      });
      const createdIncidents = incidents.data.data.filter((inc: any) =>
        inc.attributes.cause.includes(uniqueId)
      );
      expect(createdIncidents.length).to.be.eq(1);
      expect(incidents.data.data.length).to.be.eq(initial === 10 ? initial : initial + 1);

      createdIncidentIds.push(createdIncidents[0].id);
      console.log(`✅ Created incident for unique case: ${createdIncidents[0].id}`);


      // Attempt to alert again
      // This should NOT create a new incident since there's a matching one
      await alertViaBetterUptimeIfNeeded(testReport, betterUptimeConfig, requestContext);

      // Wait a moment for the incident to be registered
      await new Promise(resolve => setTimeout(resolve, 2000));

      incidents = await axiosGet(`${BETTERUPTIME_INCIDENTS_URL}?per_page=10`, {
        headers: { Authorization: `Bearer ${betterUptimeConfig.apiKey}` },
      });
      const matchedIncidents = incidents.data.data.filter((inc: any) =>
        inc.attributes.cause.includes(uniqueId)
      );
      expect(matchedIncidents.length).to.be.eq(1);
      expect(incidents.data.data.length).to.be.eq(initial === 10 ? initial : initial + 1);
    });
  });

  describe('Finding Matching Incidents', function () {
    it('should find and match existing incidents', async function () {
      // First create an incident
      const matchTestId = `match-${testId}`;
      const testReport = createTestReport({
        ids: [matchTestId],
        reason: `Matching incident test ${matchTestId}`
      });

      console.log(`🔔 Creating incident for matching test: ${matchTestId}`);
      const response = await alertViaBetterUptime(testReport, betterUptimeConfig, requestContext);

      if (response?.data?.data?.id) {
        createdIncidentIds.push(response.data.data.id);
      }

      // Wait for incident to be available
      await new Promise(resolve => setTimeout(resolve, 3000));

      // Now try to create the same incident - it should find the existing one
      console.log(`🔍 Testing incident matching for ID: ${matchTestId}`);

      // Mock the logger to capture calls
      let warningCalled = false;
      const originalWarn = testReport.logger.warn;
      testReport.logger.warn = (...args: any[]) => {
        if (args[0]?.includes('Matching incidents found')) {
          warningCalled = true;
        }
        originalWarn.apply(testReport.logger, args);
      };

      await alertViaBetterUptimeIfNeeded(testReport, betterUptimeConfig, requestContext);

      // Restore original warn method
      testReport.logger.warn = originalWarn;

      expect(warningCalled).to.be.true;
      console.log(`✅ Successfully found matching incident`);
    });
  });

  describe('Resolving Incidents', function () {
    it('should resolve matching incidents', async function () {
      const resolveTestId = `resolve-${testId}`;
      const testReport = createTestReport({
        ids: [resolveTestId],
        reason: `Resolve test ${resolveTestId}`
      });

      // Create incident to resolve
      console.log(`🔔 Creating incident for resolution test: ${resolveTestId}`);
      const response = await alertViaBetterUptime(testReport, betterUptimeConfig, requestContext);

      let incidentId: string | undefined;
      if (response?.data?.data?.id) {
        incidentId = response.data.data.id;
        createdIncidentIds.push(incidentId);
      }

      // Wait for incident to be available
      await new Promise(resolve => setTimeout(resolve, 3000));

      // Now resolve it
      console.log(`🔧 Resolving incident: ${resolveTestId}`);
      await resolveAlertViaBetterUptime(testReport, betterUptimeConfig, requestContext);

      // Wait for resolution to process
      await new Promise(resolve => setTimeout(resolve, 3000));

      // Verify the incident is resolved
      if (incidentId) {
        const incidentDetails = await axiosGet(`${BETTERUPTIME_INCIDENTS_URL}/${incidentId}`, {
          headers: { Authorization: `Bearer ${betterUptimeConfig.apiKey}` },
        });

        const status = incidentDetails.data.data.attributes.status;
        expect(['Resolved', 'Acknowledged']).to.include(status);
        console.log(`✅ Incident resolved with status: ${status}`);
      }
    });

    it('should handle resolving non-existent incident gracefully', async function () {
      const nonExistentId = `non-existent-${testId}`;
      const testReport = createTestReport({
        ids: [nonExistentId],
        reason: `Non-existent test ${nonExistentId}`
      });

      console.log(`🔍 Testing resolution of non-existent incident: ${nonExistentId}`);

      // This should not throw an error, just log that no incidents were found
      await expect(
        resolveAlertViaBetterUptime(testReport, betterUptimeConfig, requestContext)
      ).to.not.be.rejected;

      console.log(`✅ Gracefully handled non-existent incident resolution`);
    });
  });

  describe.skip('Critical Severity Handling', function () {
    it('should create incident with call=true for Critical severity', async function () {
      const criticalTestId = `critical-${testId}`;
      const criticalReport = createTestReport({
        ids: [criticalTestId],
        reason: `Critical severity test ${criticalTestId}`,
        severity: Severity.Critical
      });

      console.log(`🚨 Creating critical severity incident: ${criticalTestId}`);
      const response = await alertViaBetterUptime(criticalReport, betterUptimeConfig, requestContext);

      expect(response).to.exist;

      if (response?.data?.data?.id) {
        createdIncidentIds.push(response.data.data.id);

        // Verify the incident has the right attributes for critical alerts
        const incidentDetails = await axiosGet(`${BETTERUPTIME_INCIDENTS_URL}/${response.data.data.id}`, {
          headers: { Authorization: `Bearer ${betterUptimeConfig.apiKey}` },
        });

        // The incident should exist and be created successfully
        expect(incidentDetails.data.data.attributes.call).to.be.true;
        console.log(`✅ Critical incident created with call=true`);
      }
    });
  });
});