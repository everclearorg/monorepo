import { Context, APIGatewayProxyResult, APIGatewayEvent } from 'aws-lambda';
import { Logger } from '@chimera-monorepo/utils';

import { makePoller } from './pollers';

const logger = new Logger({
  level: 'info',
  name: 'cartographer-lambda',
  formatters: {
    level: (label) => ({ level: label.toUpperCase() }),
  },
});

export const handler = async (event: APIGatewayEvent, context: Context): Promise<APIGatewayProxyResult> => {
  logger.info('Lambda invoked', undefined, undefined, { event, context });

  await makePoller();

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'hello world',
    }),
  };
};
