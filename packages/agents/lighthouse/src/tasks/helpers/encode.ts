export const tidy = (str: string): string => `${str.replace(/\n/g, '').replace(/ +/g, ' ')}`;

export const TickerAmountEncoding = tidy(`tuple(
    bytes32 tickerHash,
    uint32 amount
  )`);
