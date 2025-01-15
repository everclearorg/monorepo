import { Intent, TIntentStatus } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { getContract } from '../mockable';

/**
 * @notice Converts onchain status values to string values.
 * @param status Onchain status enum value
 * @returns Status string value.
 */
export const convertChainToReadableIntentStatus = (status: number): TIntentStatus => {
  return Object.values(TIntentStatus)[status];
};

type IntentContext = {
  solver: string;
  fee: number;
  totalProtocolFee: number;
  fillTimestamp: string;
  amountAfterFees: string;
  pendingRewards: string;
  intentStatus: TIntentStatus;
  intent: Intent;
};
export const getIntentContextFromContract = async (intentId: string): Promise<IntentContext> => {
  const {
    config,
    adapters: { chainreader },
  } = getContext();

  // Get the asset config.
  const hubEverclear = getContract(config.hub.deployments.everclear, config.abis.hub.everclear);
  const encoded = await chainreader.readTx(
    {
      to: hubEverclear.address,
      domain: +config.hub.domain,
      data: hubEverclear.interface.encodeFunctionData('contexts', [intentId]),
    },
    'latest',
  );
  const [context] = hubEverclear.interface.decodeFunctionResult('contexts', encoded);

  return { ...context, intentStatus: convertChainToReadableIntentStatus(context.status) };
};

export const getCurrentEpoch = async (): Promise<number> => {
  const {
    config,
    adapters: { chainreader },
  } = getContext();

  // Get the epoch length.
  const hubEverclear = getContract(config.hub.deployments.everclear, config.abis.hub.everclear);
  const encoded = await chainreader.readTx(
    {
      to: hubEverclear.address,
      domain: +config.hub.domain,
      data: hubEverclear.interface.encodeFunctionData('getCurrentEpoch', []),
    },
    'latest',
  );
  const [epoch] = hubEverclear.interface.decodeFunctionResult('getCurrentEpoch', encoded);
  return epoch;
};
