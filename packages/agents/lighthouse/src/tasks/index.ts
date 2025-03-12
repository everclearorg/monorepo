import { getConfig } from '../config';
import { InvalidService } from '../errors';
import { makeLighthouseTask } from '../context';
import { processDepositsAndInvoices } from './invoice';
import { processExpiredIntents } from './clearing';
import { processRewards, updateRewardsMetadata } from './reward';
import { processMessageQueue } from './helpers';
import { QueueType } from '@chimera-monorepo/utils';

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export const makeLighthouse = async () => {
  const config = await getConfig();
  const service = process.env.LIGHTHOUSE_SERVICE ?? config.service;
  switch (service) {
    case 'intent':
      return makeLighthouseTask(() => processMessageQueue(QueueType.Intent), config, service);
    case 'intentAdded':
      return makeLighthouseTask(() => processIntentAdded(config));
    case 'fill':
      return makeLighthouseTask(() => processMessageQueue(QueueType.Fill), config, service);
    case 'settlement':
      return makeLighthouseTask(() => processMessageQueue(QueueType.Settlement), config, service);
    case 'expired':
      return makeLighthouseTask(processExpiredIntents, config, service);
    case 'invoice':
      return makeLighthouseTask(processDepositsAndInvoices, config, service);
    case 'reward':
      return makeLighthouseTask(processRewards, config, service);
    case 'reward_metadata':
      return makeLighthouseTask(updateRewardsMetadata, config, service);
    default:
      throw new InvalidService(service);
  }
};
