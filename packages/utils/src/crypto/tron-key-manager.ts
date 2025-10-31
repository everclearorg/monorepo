import { Logger } from '../logging';
import { createTronWeb, TronKeyPair } from './tron';

export interface TronKeyConfig {
  privateKey?: string;
  mnemonic?: string;
  keyPath?: string; // For HD wallets
  kmsKeyId?: string; // For KMS integration
  hsmSlotId?: string; // For HSM integration
}

export interface TronKeyManagerOptions {
  environment: 'development' | 'staging' | 'production';
  fallbackToTestKey?: boolean;
  logger?: Logger;
}

/**
 * Secure Tron Key Manager following industry best practices
 */
export class TronKeyManager {
  private readonly logger: Logger;
  private readonly options: TronKeyManagerOptions;
  private cachedKeyPair?: TronKeyPair;

  constructor(options: TronKeyManagerOptions) {
    this.options = options;
    this.logger = options.logger || new Logger({ name: 'TronKeyManager' });
  }

  /**
   * Get Tron private key following security best practices
   */
  public async getPrivateKey(): Promise<string> {
    // 1. Try environment variable (recommended for dev/staging)
    const envKey = this.getFromEnvironment();
    if (envKey) {
      this.logger.info('Using private key from environment variable');
      return envKey;
    }

    // 2. Try KMS (recommended for production)
    const kmsKey = await this.getFromKMS();
    if (kmsKey) {
      this.logger.info('Using private key from KMS');
      return kmsKey;
    }

    // 3. Try HSM (enterprise production)
    const hsmKey = await this.getFromHSM();
    if (hsmKey) {
      this.logger.info('Using private key from HSM');
      return hsmKey;
    }

    // 4. Try HD wallet derivation
    const hdKey = await this.getFromHDWallet();
    if (hdKey) {
      this.logger.info('Using derived key from HD wallet');
      return hdKey;
    }

    // 5. Fallback to test key (development only)
    if (this.options.fallbackToTestKey && this.options.environment === 'development') {
      this.logger.warn('SECURITY WARNING: Using test private key - FOR DEVELOPMENT ONLY');
      return this.getTestPrivateKey();
    }

    throw new Error('No Tron private key available. Configure TRON_PRIVATE_KEY environment variable or KMS.');
  }

  /**
   * Get Tron key pair with caching
   */
  public async getKeyPair(): Promise<TronKeyPair> {
    if (this.cachedKeyPair) {
      return this.cachedKeyPair;
    }

    const privateKey = await this.getPrivateKey();
    const tronWeb = createTronWeb(privateKey, 'https://api.trongrid.io');

    // Validate that defaultAddress is properly set
    if (!tronWeb.defaultAddress.hex || !tronWeb.defaultAddress.base58) {
      throw new Error('Failed to derive Tron address from private key');
    }

    this.cachedKeyPair = {
      privateKey,
      publicKey: tronWeb.defaultAddress.hex as string,
      address: {
        hex: tronWeb.defaultAddress.hex as string,
        base58: tronWeb.defaultAddress.base58 as string,
      },
    };

    return this.cachedKeyPair;
  }

  /**
   * Create TronWeb instance with managed key
   */
  public async createTronWeb(fullHost: string = 'https://api.trongrid.io'): Promise<unknown> {
    const privateKey = await this.getPrivateKey();
    return createTronWeb(privateKey, fullHost);
  }

  /**
   * Get private key from environment variables
   */
  private getFromEnvironment(): string | null {
    // Priority order for environment variables
    const envVars = [
      'TRON_PRIVATE_KEY', // Primary
      'TRON_SIGNER_PRIVATE_KEY', // Signer-specific
      'RELAYER_TRON_PRIVATE_KEY', // Relayer-specific
    ];

    for (const envVar of envVars) {
      const key = process.env[envVar];
      if (key) {
        // Validate key format
        if (this.isValidPrivateKey(key)) {
          // Strip 0x prefix if present for TronWeb compatibility
          return key.startsWith('0x') ? key.slice(2) : key;
        } else {
          this.logger.error(`Invalid private key format in ${envVar}`);
        }
      }
    }

    return null;
  }

  /**
   * Get private key from AWS KMS (placeholder for implementation)
   */
  private async getFromKMS(): Promise<string | null> {
    const kmsKeyId = process.env.TRON_KMS_KEY_ID;
    if (!kmsKeyId) {
      return null;
    }

    try {
      // TODO: Implement AWS KMS integration
      // const kms = new AWS.KMS();
      // const result = await kms.decrypt({
      //   CiphertextBlob: Buffer.from(encryptedKey, 'base64'),
      // }).promise();
      // return result.Plaintext.toString();

      this.logger.info('KMS integration not yet implemented');
      return null;
    } catch (error) {
      this.logger.error('Failed to retrieve key from KMS');
      return null;
    }
  }

  /**
   * Get private key from HSM (placeholder for implementation)
   */
  private async getFromHSM(): Promise<string | null> {
    const hsmSlotId = process.env.TRON_HSM_SLOT_ID;
    if (!hsmSlotId) {
      return null;
    }

    try {
      // TODO: Implement HSM integration
      // Example: PKCS#11 integration for hardware security modules
      this.logger.info('HSM integration not yet implemented');
      return null;
    } catch (error) {
      this.logger.error('Failed to retrieve key from HSM');
      return null;
    }
  }

  /**
   * Derive private key from HD wallet mnemonic
   */
  private async getFromHDWallet(): Promise<string | null> {
    const mnemonic = process.env.TRON_MNEMONIC;
    // Tron BIP44 path
    // const keyPath = process.env.TRON_HD_PATH || "m/44'/195'/0'/0/0";

    if (!mnemonic) {
      return null;
    }

    try {
      // TODO: Implement HD wallet derivation
      // const hdkey = HDKey.fromMasterSeed(mnemonicToSeed(mnemonic));
      // const derived = hdkey.derive(keyPath);
      // return derived.privateKey.toString('hex');

      this.logger.info('HD wallet derivation not yet implemented');
      return null;
    } catch (error) {
      this.logger.error('Failed to derive key from HD wallet');
      return null;
    }
  }

  /**
   * Get test private key (development only)
   */
  private getTestPrivateKey(): string {
    const testPrivateKey = process.env.TEST_PRIVATE_KEY;
    if (!testPrivateKey) {
      this.logger.warn('Test private key is not set in the environment variables.');
      throw new Error('Test private key is required but not set.');
    }
    return testPrivateKey;
  }

  /**
   * Validate private key format
   */
  private isValidPrivateKey(key: string): boolean {
    // Tron private key should be 64 hex characters (with or without 0x prefix)
    const cleanKey = key.startsWith('0x') ? key.slice(2) : key;
    return /^[0-9a-fA-F]{64}$/.test(cleanKey);
  }

  /**
   * Clear cached key pair (for key rotation)
   */
  public clearCache(): void {
    this.cachedKeyPair = undefined;
  }

  /**
   * Get address without exposing private key
   */
  public async getAddress(): Promise<string> {
    const keyPair = await this.getKeyPair();
    return keyPair.address.base58;
  }
}
