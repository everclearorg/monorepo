import { axiosGet } from './axios';
import { HyperlaneStatus } from './hyperlane';

export const POLYMER_RELAYER_URL = 'https://relayer.polymer.zone/api/v1';

/**
 * Domain pairs that use Polymer for message delivery.
 * Each pair is [domainA, domainB] — messages in either direction are Polymer-routed.
 */
export const POLYMER_DOMAIN_PAIRS: [string, string][] = [
  ['1', '25327'], // Ethereum <-> Hub
  ['8453', '25327'], // Base <-> Hub
  ['728126428', '25327'], // Tron <-> Hub
];

/**
 * Check if a message between two domains is routed via Polymer.
 */
export const isPolymerRoute = (originDomain: string, destinationDomain: string): boolean => {
  return POLYMER_DOMAIN_PAIRS.some(
    ([a, b]) => (originDomain === a && destinationDomain === b) || (originDomain === b && destinationDomain === a),
  );
};

/**
 * Query the Polymer relayer API for message delivery status.
 *
 * @param messageId - The message ID (hex string with 0x prefix).
 * @returns HyperlaneStatus.delivered if the message was successfully delivered, HyperlaneStatus.pending otherwise.
 */
export const getPolymerMsgDelivered = async (messageId: string): Promise<HyperlaneStatus> => {
  const url = `${POLYMER_RELAYER_URL}/messages/${messageId}`;
  const { data } = await axiosGet<{ success: boolean; data: { status: string } }>(url, undefined, 2);
  return data?.success === true && data?.data?.status === 'success'
    ? HyperlaneStatus.delivered
    : HyperlaneStatus.pending;
};
