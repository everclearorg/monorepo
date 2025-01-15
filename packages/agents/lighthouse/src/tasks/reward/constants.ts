export const REWARDS_EPOCH_CHECKPOINT = 'lighthouse_rewards_epoch';

export const MONTH_SECONDS = 30 * 24 * 60 * 60;
export const YEAR_SECONDS = 365 * 24 * 60 * 60;
export const APY_MULTIPLIER = 10 ** 3;

// bps have 4 d.p. (1 bps = 1/10000), dbps have 5 d.p.
const DBPS_DECIMAL = 5;
export const DBPS_MULTIPLIER = 10 ** DBPS_DECIMAL;

// All USD Calculation is scaled by this multiplier for bignum storage.
// This means we are the accuracy is up to 6 d.p. which should be good enough for volume calculation.
const USD_DECIMAL = 6;
export const USD_MULTIPLIER = 10 ** USD_DECIMAL;
