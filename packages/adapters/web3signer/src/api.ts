import { EverclearError, axiosPost, axiosGet } from '@chimera-monorepo/utils';
import { type Hex } from '@chimera-monorepo/utils';

// TODO: This class might benefit from some error handling / logging and response sanitization logic.
/**
 * Simple class for wrapping axios calls to the web3signer API.
 */
export class Web3SignerApi {
  private static ENDPOINTS = {
    SIGN: 'api/v1/eth1/sign',
    SERVER_STATUS: 'upcheck',
    PUBLIC_KEY: 'api/v1/eth1/publicKeys',
  };

  constructor(private readonly url: string) {}

  public async sign(identifier: string, data: string | Hex | Uint8Array): Promise<string> {
    const endpoint = Web3SignerApi.ENDPOINTS.SIGN;

    // Convert Uint8Array to hex string if needed
    let dataToSend: string | Hex;
    if (data instanceof Uint8Array) {
      dataToSend = `0x${Array.from(data)
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('')}` as Hex;
    } else {
      dataToSend = data;
    }

    let response = await axiosPost(this.formatUrl(endpoint, identifier), {
      data: dataToSend,
    });
    response = this.sanitizeResponse(response, endpoint);
    return response.data;
  }

  public async getServerStatus(): Promise<string> {
    const endpoint = Web3SignerApi.ENDPOINTS.SERVER_STATUS;
    let response = await axiosGet(this.formatUrl(endpoint));
    response = this.sanitizeResponse(response, endpoint);
    return response.data[0];
  }

  public async getPublicKey(): Promise<string> {
    const endpoint = Web3SignerApi.ENDPOINTS.PUBLIC_KEY;
    let response = await axiosGet(this.formatUrl(endpoint));
    response = this.sanitizeResponse(response, endpoint);
    return response.data[0];
  }

  private formatUrl(
    endpoint: (typeof Web3SignerApi.ENDPOINTS)[keyof typeof Web3SignerApi.ENDPOINTS],
    identifier?: string,
  ): string {
    let url = `${this.url}/${endpoint}`;
    if (identifier) {
      url += `/${identifier}`;
    }
    return url;
  }

  private sanitizeResponse(
    response: any,
    endpoint: (typeof Web3SignerApi.ENDPOINTS)[keyof typeof Web3SignerApi.ENDPOINTS],
  ) {
    if (!response || !response.data || response.data.length === 0) {
      throw new EverclearError(
        'Received bad response from web3signer instance; make sure your key file is configured correctly.',
        {
          response,
          endpoint,
        },
      );
    }
    return response;
  }
}
