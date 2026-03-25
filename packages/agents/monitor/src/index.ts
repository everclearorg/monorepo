import { Context, APIGatewayProxyResult, APIGatewayEvent } from 'aws-lambda';
import { Logger } from '@chimera-monorepo/utils';

import { MonitorService, makeMonitor } from './monitor';

const logger = new Logger({
  level: 'info',
  name: 'monitor-lambda',
  formatters: {
    level: (label) => ({ level: label.toUpperCase() }),
  },
});

export const handler = async (event: APIGatewayEvent, context: Context): Promise<APIGatewayProxyResult> => {
  logger.info('Lambda invoked', undefined, undefined, { event, context });

  await makeMonitor(MonitorService.POLLER);

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'hello world',
    }),
  };
};
