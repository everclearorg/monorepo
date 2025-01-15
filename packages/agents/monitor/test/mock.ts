import { MonitorConfig } from '../src/types';
import { mock } from './globalTestHook';

export const createProcessEnv = (overrides: Partial<MonitorConfig> = {}) => {
  return {
    MONITOR_CONFIG: JSON.stringify(mock.config(overrides)),
  };
};
