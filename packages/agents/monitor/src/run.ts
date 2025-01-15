import { config as dotenvConfig } from 'dotenv';
import { MonitorService, makeMonitor } from './monitor';

dotenvConfig();
export const startMonitor = async () => {
  const service = process.env.MONITOR_SERVICE ?? '';

  switch (service) {
    case MonitorService.SERVER:
      await makeMonitor(MonitorService.SERVER);
      break;
    case MonitorService.POLLER:
      await makeMonitor(MonitorService.POLLER);
      break;
    default:
      throw new Error(`Unsupported service: ${service}`);
  }
};

startMonitor();
