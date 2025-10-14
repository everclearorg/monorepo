import { EverclearError } from '@chimera-monorepo/utils';
import { MonitorConfig } from '../types/config';

export class MissingAssetConfig extends EverclearError {
  constructor(context: object = {}) {
    super(`Missing asset config`, context, MissingAssetConfig.name);
  }
}

export class MissingTokenPrice extends EverclearError {
  constructor(context: object = {}) {
    super(`Missing token price`, context, MissingTokenPrice.name);
  }
}

export class MissingDeployments extends EverclearError {
  constructor(context: object = {}) {
    super(`Missing deployments for chain`, context, MissingDeployments.name);
  }
}

export class NoGatewayConfigured extends EverclearError {
  constructor(
    public readonly domain: string = '',
    public readonly config: MonitorConfig['chains'],
    context: object = {},
  ) {
    super(`Missing gateway deployment`, { config, domain, ...context });
  }
}

export class NoTokenConfigurationFound extends EverclearError {
  constructor(
    public readonly tickerHash: string = '',
    context: object = {},
  ) {
    super(`Missing token configuration`, { tickerHash, ...context });
  }
}

export class NoDispatchEventOnMessage extends EverclearError {
  constructor(
    public readonly messageId: string = '',
    public readonly transactionHash: string = '',
    context: object = {},
  ) {
    super(`No 'Dispatch' event found on message`, { messageId, transactionHash, ...context });
  }
}

export class NoProvidersConfigured extends EverclearError {
  constructor(context: object = {}) {
    super(`No providers configured`, { ...context });
  }
}

export class UnableToGetSpokeState extends EverclearError {
  constructor(context: object = {}) {
    super(`Unable to get spoke state`, { ...context });
  }
}

// Tron-specific error types
export class TronChainNotConfigured extends EverclearError {
  constructor(context: object = {}) {
    super('Tron chain is not configured', { ...context }, TronChainNotConfigured.name);
  }
}

export class TronSpokeAddressNotConfigured extends EverclearError {
  constructor(context: object = {}) {
    super('No Tron spoke address configured', { ...context }, TronSpokeAddressNotConfigured.name);
  }
}

export class TronNonceReadFailed extends EverclearError {
  constructor(context: object = {}) {
    super('Failed to read Tron last intent nonce', { ...context }, TronNonceReadFailed.name);
  }
}
