/* eslint-disable @typescript-eslint/no-explicit-any */
import { TronWeb } from 'tronweb';

export type TronWebInstance = InstanceType<typeof TronWeb>;

export interface TronWebFactory {
  create(url: string): TronWebInstance;
}

export class DefaultTronWebFactory implements TronWebFactory {
  create(url: string): TronWebInstance {
    // Extract API key from URL if present
    const urlObj = new URL(url);
    const apiKey = urlObj.searchParams.get('apiKey');

    // Remove API key from URL to get clean fullHost
    urlObj.searchParams.delete('apiKey');
    const cleanUrl = urlObj.toString();

    const tronWebConfig: any = { fullHost: cleanUrl };
    if (apiKey) {
      tronWebConfig.headers = { 'TRON-PRO-API-KEY': apiKey };
    }

    return new TronWeb(tronWebConfig);
  }
}

/**
 * Get account resources (bandwidth and energy) for a Tron address
 */
export async function getAccountResources(
  address: string,
  tronWeb: TronWebInstance,
): Promise<{
  bandwidth: bigint;
  energy: bigint;
}> {
  const resources = await tronWeb.trx.getAccountResources(address);

  // Bandwidth: freeNetLimit - freeNetUsed + NetLimit - NetUsed
  const freeNet = (resources.freeNetLimit ?? 0) - (resources.freeNetUsed ?? 0);
  const stakedNet = (resources.NetLimit ?? 0) - (resources.NetUsed ?? 0);
  const bandwidth = BigInt(Math.max(0, freeNet + stakedNet));

  // Energy: EnergyLimit - EnergyUsed
  const energy = BigInt(Math.max(0, (resources.EnergyLimit ?? 0) - (resources.EnergyUsed ?? 0)));

  return {
    bandwidth,
    energy,
  };
}

