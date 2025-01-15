/* eslint-disable @typescript-eslint/no-explicit-any */
import { EverclearError } from '../types/';

export class GelatoEstimatedFeeRequestError extends EverclearError {
  constructor(
    chainId: number,
    public readonly context: any = {},
  ) {
    super(`Error with API request for Gelato fee estimate`, {
      ...context,
      chainId,
    });
  }
}

export class GelatoConversionRateRequestError extends EverclearError {
  constructor(
    chainId: number,
    public readonly context: any = {},
  ) {
    super(`Error with API request for Gelato conversion rate`, {
      ...context,
      chainId,
    });
  }
}
