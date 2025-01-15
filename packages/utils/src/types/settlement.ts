export const TSettlementStrategy = {
  Default: 'DEFAULT',
} as const;
export type TSettlementStrategy = (typeof TSettlementStrategy)[keyof typeof TSettlementStrategy];
