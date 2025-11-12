import { EverclearError, axiosPost, axiosGet } from '@chimera-monorepo/utils';
import { Bytes } from 'ethers';
import { AxiosResponse } from 'axios';

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

  public async sign(identifier: string, data: string | Bytes): Promise<string> {
    const endpoint = Web3SignerApi.ENDPOINTS.SIGN;
    const response = await axiosPost(this.formatUrl(endpoint, identifier), {
      data,
    });
    this.sanitizeResponse(response, endpoint);
    return response.data;
  }

  public async getServerStatus(): Promise<string> {
    const endpoint = Web3SignerApi.ENDPOINTS.SERVER_STATUS;
    const response = await axiosGet(this.formatUrl(endpoint));
    this.sanitizeResponse(response, endpoint);
    return response.data[0];
  }

  public async getPublicKey(): Promise<string> {
    const endpoint = Web3SignerApi.ENDPOINTS.PUBLIC_KEY;
    const response = await axiosGet(this.formatUrl(endpoint));
    this.sanitizeResponse(response, endpoint);
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
    response: AxiosResponse<any>,
    endpoint: (typeof Web3SignerApi.ENDPOINTS)[keyof typeof Web3SignerApi.ENDPOINTS],
  ): void {
    if (!response || !response.data || response.data.length === 0) {
      throw new EverclearError(
        'Received bad response from web3signer instance; make sure your key file is configured correctly.',
        {
          response,
          endpoint,
        },
      );
    }
  }
}
