export const getMaxNonce = (items: { nonce: number }[]): number => {
  return items.length == 0 ? 0 : Math.max(...items.map((item) => item?.nonce ?? 0));
};

export const getMaxTimestamp = (items: { timestamp: number }[]): number => {
  return items.length == 0 ? 0 : Math.max(...items.map((item) => item?.timestamp ?? 0));
};

export const getMaxTxNonce = (items: { txNonce: number }[]): number => {
  return items.length == 0 ? 0 : Math.max(...items.map((item) => item?.txNonce ?? 0));
};

export const getMaxEpoch = (items: { epoch: number }[]): number => {
  return items.length == 0 ? 0 : Math.max(...items.map((item) => item?.epoch ?? 0));
};
