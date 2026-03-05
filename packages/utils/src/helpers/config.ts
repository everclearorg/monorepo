import { Deployments as _Deployments } from '@chimera-monorepo/contracts';
import { ABIConfig, EverclearConfig, Environment, TEverclearConfig, ajv, ChainDeployments } from '../types';
import { axiosGet } from './axios';
import { Static, Type } from '@sinclair/typebox';
import { Logger } from '../logging';

export const parseEverclearConfig = (data: object): EverclearConfig => {
  const everclearConfig = data as EverclearConfig;

  const validate = ajv.compile(TEverclearConfig);
  const valid = validate(everclearConfig);
  if (!valid) {
    throw new Error(
      `Invalid everclear config: ` + validate.errors?.map((err: unknown) => JSON.stringify(err, null, 2)).join(','),
    );
  }

  return everclearConfig;
};

export const getEverclearConfig = async (configUrl?: string): Promise<EverclearConfig | undefined> => {
  if (!configUrl) {
    return undefined;
  }
  try {
    const res = await axiosGet(configUrl);
    return parseEverclearConfig(res.data);
  } catch {
    return undefined;
  }
};

const Deployments = _Deployments as Record<Environment, Record<number, ChainDeployments>>;

export const getDefaultABIConfig = (environment: Environment, hubDomain: number): ABIConfig => {
  const [spoke] = Object.keys(Deployments[environment]).filter((x) => +x !== hubDomain);
  const defaultAbiConfig: ABIConfig = {
    hub: {
      everclear: Deployments[environment][hubDomain].everclear.abi,
      gateway: Deployments[environment][hubDomain].gateway.abi,
      gauge: Deployments[environment][hubDomain].gauge!.abi,
      rewardDistributor: Deployments[environment][hubDomain].rewardDistributor!.abi,
      tokenomicsHubGateway: Deployments[environment][hubDomain].tokenomicsHubGateway!.abi,
    },
    spoke: {
      // uses any non-hub chain to get the abis
      everclear: Deployments[environment][+spoke].everclear.abi,
      gateway: Deployments[environment][+spoke].gateway.abi,
    },
  };
  return defaultAbiConfig;
};

export const TAlertConfigSchema = Type.Object({
  network: Type.String(),
  telegram: Type.Optional(
    Type.Object({
      apiKey: Type.Optional(Type.String()),
      chatId: Type.Optional(Type.String()),
    }),
  ),
  betterUptime: Type.Optional(
    Type.Object({
      apiKey: Type.Optional(Type.String()),
      requesterEmail: Type.Optional(Type.String()),
    }),
  ),
  discord: Type.Optional(
    Type.Object({
      url: Type.String(),
    }),
  ),
});
export type AlertConfig = Static<typeof TAlertConfigSchema>;
export type TelegramConfig = Static<typeof TAlertConfigSchema>['telegram'];
export type BetterUptimeConfig = Static<typeof TAlertConfigSchema>['betterUptime'];

export enum Severity {
  Warning = 'warning',
  Critical = 'critical',
  Informational = 'info',
}

export interface Report {
  severity: Severity;
  type: string;
  ids: string[]; // domain, ticker hashes, etc. dependent on the check
  timestamp: number;
  reason: string;
  logger: Logger;
  env: string;
}
