import { AppContext } from '../shared';

import { bindIntents } from './intents';
import { bindInvoices } from './invoices';
import { bindDepositors } from './depositors';
import { bindMonitor } from './monitor';

export const bind = async (context: AppContext) => {
  switch (context.config.service) {
    case 'intents':
      await bindIntents(context);
      break;
    case 'invoices':
      await bindInvoices(context);
      break;
    case 'depositors':
      await bindDepositors(context);
      break;
    case 'monitor':
      await bindMonitor(context);
      break;
  }
};
