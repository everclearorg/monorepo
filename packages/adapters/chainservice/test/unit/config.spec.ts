import { expect } from '@chimera-monorepo/utils';
import { DEFAULT_CHAIN_CONFIG_VALUE_MINS, validateChainServiceConfig } from '../../src/config';
import { ConfigurationError } from '../../src/shared';
import { TEST_SENDER_CHAIN_ID } from '../utils';

/// config.ts
describe('Config', () => {
  beforeEach(() => {});

  afterEach(() => {});

  describe('#validateChainServiceConfig', () => {
    it('throw if gas price max increase scalar is less', () => {
      const config = {
        [TEST_SENDER_CHAIN_ID.toString()]: {
          providers: [{ url: 'https://-------------' }],
          gasPriceMaxIncreaseScalar: DEFAULT_CHAIN_CONFIG_VALUE_MINS.gasPriceMaxIncreaseScalar - 1,
        },
      };

      expect(() => validateChainServiceConfig(config)).to.throw(ConfigurationError);
    });

    it('throw if gas price replacement bump percent is less', () => {
      const config = {
        [TEST_SENDER_CHAIN_ID.toString()]: {
          providers: [{ url: 'https://-------------' }],
          gasPriceReplacementBumpPercent: DEFAULT_CHAIN_CONFIG_VALUE_MINS.gasPriceReplacementBumpPercent - 1,
        },
      };

      expect(() => validateChainServiceConfig(config)).to.throw(ConfigurationError);
    });

    it('throw if gas limit inflation is less', () => {
      const config = {
        [TEST_SENDER_CHAIN_ID.toString()]: {
          providers: [{ url: 'https://-------------' }],
          gasLimitInflation: DEFAULT_CHAIN_CONFIG_VALUE_MINS.gasLimitInflation - 1,
        },
      };

      expect(() => validateChainServiceConfig(config)).to.throw(ConfigurationError);
    });
  });
});
