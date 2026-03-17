import { canonizeId, chainWrapper } from '@chimera-monorepo/utils';
import { AppContext } from '@chimera-monorepo/cartographer-core';
import { parseDepositorEvent, parseToken, parseAsset } from '../webhooks/parsers';

export const processDepositorEvent = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const event = parseDepositorEvent(payload);
  logger.debug('Processing depositor event webhook', undefined, undefined, {
    depositor: event.depositor,
    asset: event.asset,
  });

  // Save depositor
  const depositorId = canonizeId(event.depositor);
  await database.saveDepositors([{ id: depositorId }]);

  // Compute asset hash
  const assetHash = chainWrapper.keccak256(
    chainWrapper.encodeAbiParameters(
      [{ type: 'address' }, { type: 'uint32' }],
      [event.asset as `0x${string}`, event.domain],
    ),
  ) as string;

  // Save balance
  await database.saveBalances([
    {
      id: assetHash,
      asset: canonizeId(event.asset),
      account: canonizeId(event.depositor),
      amount: event.amount,
    },
  ]);
};

export const processToken = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const token = parseToken(payload);
  logger.debug('Processing token webhook', undefined, undefined, { tokenId: token.id });

  await database.saveTokens([token]);

  // If this payload also has asset info, save that too
  if (payload.domain && payload.adopted) {
    const asset = parseAsset(payload);
    await database.saveAssets([asset]);
  }
};
