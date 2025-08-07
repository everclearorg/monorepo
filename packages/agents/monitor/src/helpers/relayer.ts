import axios from 'axios';

/**
 * Fetch address from the given relayer URL.
 */
export async function fetchRelayerData(relayerUrl: string): Promise<string | undefined> {
  try {
    const response = await axios.get(`${relayerUrl}/address`);
    return response.data;
  } catch (error) {
    console.error(`Error fetching address from ${relayerUrl}:`, error);
    return undefined;
  }
}
