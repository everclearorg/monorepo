import { Context, APIGatewayProxyResult, APIGatewayEvent } from 'aws-lambda';

import { MonitorService, makeMonitor } from './monitor';

export const handler = async (event: APIGatewayEvent, context: Context): Promise<APIGatewayProxyResult> => {
  console.log(`Event: ${JSON.stringify(event, null, 2)}`);
  console.log(`Context: ${JSON.stringify(context, null, 2)}`);

  await makeMonitor(MonitorService.POLLER);

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'hello world',
    }),
  };
};
