/* eslint-disable @typescript-eslint/no-explicit-any */
import pino, { BaseLogger, Bindings, LoggerOptions, destination } from 'pino';

import { ErrorJson } from '..';

import { createMethodContext, createRequestContext, MethodContext, RequestContext } from '.';

import { chainIds } from '../constants';

export type LogLevel = 'fatal' | 'error' | 'warn' | 'info' | 'debug' | 'trace' | 'silent';

const DEFAULT_REDACTED_PATHS = [
  'config.healthUrls.poller',
  'config.hub.providers',
  'config.hub.subgraphUrls',
  'config.hub.envioSubgraphUrl',
  'config.server.adminToken',
  'config.web3SignerUrl',
  'config.database.url',
  'config.telegram.apiKey',
  'config.betterUptime.apiKey',
  'config.betterUptime.requesterEmail',
  'config.discord.url',
  'config.redis.password',
  'config.redis.url',
  'config.triage.providers.anthropic.apiKey',
  'config.triage.providers.openai.apiKey',
  'config.relayers[*].apiKey',
  'config.relayers[*].url',
  'params.apiKey',
];
for (const chainId of chainIds) {
  DEFAULT_REDACTED_PATHS.push(`config.chains[${chainId}].providers`);
  DEFAULT_REDACTED_PATHS.push(`config.chains[${chainId}].subgraphUrls`);
  DEFAULT_REDACTED_PATHS.push(`chains[${chainId}].providers`);
  DEFAULT_REDACTED_PATHS.push(`chains[${chainId}].subgraphUrls`);
  DEFAULT_REDACTED_PATHS.push(`chains[${chainId}].privateKey`);
}

/**
 * @classdesc Designed to log information in a uniform way to make parsing easier
 */
export class Logger {
  private readonly log: BaseLogger;
  public sanitizedValue: string = '**********';
  constructor(
    private readonly opts: LoggerOptions,
    public readonly forcedLevel?: LogLevel,
    private readonly dest?: number | string,
    private readonly sync: boolean = false,
  ) {
    if (!this.opts.redact) {
      this.opts.redact = this.createDefaultRedactOption();
    }
    this.log = pino(this.opts, destination({ dest, sync }));
  }

  child(bindings: Bindings, forcedLevel?: LogLevel, dest?: number | string, sync: boolean = false) {
    return new Logger({ ...this.opts, ...bindings }, forcedLevel, dest, sync);
  }

  debug(msg: string, requestContext?: RequestContext, methodContext?: MethodContext, ctx?: any): void {
    this.print(
      this.forcedLevel ?? 'debug',
      requestContext,
      methodContext,
      this.forcedLevel ? { ...ctx, intendedLevel: 'debug' } : ctx,
      msg,
    );
  }

  info(msg: string, requestContext?: RequestContext, methodContext?: MethodContext, ctx?: any): void {
    this.print(
      this.forcedLevel ?? 'info',
      requestContext,
      methodContext,
      this.forcedLevel ? { ...ctx, intendedLevel: 'info' } : ctx,
      msg,
    );
  }

  warn(msg: string, requestContext?: RequestContext, methodContext?: MethodContext, ctx?: any): void {
    this.print(
      this.forcedLevel ?? 'warn',
      requestContext,
      methodContext,
      this.forcedLevel ? { ...ctx, intendedLevel: 'warn' } : ctx,
      msg,
    );
  }

  error(
    msg: string,
    requestContext?: RequestContext,
    methodContext?: MethodContext,
    error?: ErrorJson,
    ctx?: any,
  ): void {
    this.print(
      this.forcedLevel ?? 'error',
      requestContext,
      methodContext,
      this.forcedLevel ? { ...ctx, error, intendedLevel: 'error' } : { ...ctx, error },
      msg,
    );
  }

  private print(
    level: LogLevel,
    requestContext: RequestContext = createRequestContext('Logger.print'),
    methodContext: MethodContext = createMethodContext('Logger.print'),
    ctx: any = {},
    msg: string,
  ): void {
    return this.log[level]({ requestContext, methodContext, ...ctx }, msg);
  }

  private createDefaultRedactOption() {
    const isUrl = (value: string) => {
      try {
        new URL(value);
        return true;
        // eslint-disable-next-line
      } catch (_) {}

      return false;
    };

    const sanitizeUrl = (value: string) => {
      const url = new URL(value);
      if (url.origin != 'null') {
        return url.origin;
      }

      return url.protocol + '//' + url.host;
    };

    const normalizeFieldName = (fieldName: string): string => fieldName.toLowerCase().replace(/[^a-z0-9]/g, '');

    const censor = (value: any, path: string[]) => {
      const fieldName = path[path.length - 1];
      const normalizedFieldName = normalizeFieldName(fieldName);

      switch (normalizedFieldName) {
        case 'poller':
        case 'url':
        case 'web3signerurl':
        case 'subgraphurl':
        case 'subgraphurls':
        case 'enviosubgraphurl':
          if (typeof value === 'string' && isUrl(value)) {
            return sanitizeUrl(value);
          }
          return this.sanitizedValue;
        case 'providers': {
          if (!Array.isArray(value)) {
            return this.sanitizedValue;
          }
          const providers = [];
          for (const provider of value) {
            providers.push(isUrl(provider) ? sanitizeUrl(provider) : provider);
          }
          return providers;
        }
        case 'admintoken':
        case 'privatekey':
        case 'apikey':
        case 'requesteremail':
        case 'password':
        case 'authorization':
        case 'authtoken':
        case 'token':
        case 'secret':
          return this.sanitizedValue;
        default:
          if (/(token|secret|password|apikey|auth|privatekey)/.test(normalizedFieldName)) {
            return this.sanitizedValue;
          }
          return value;
      }
    };

    return {
      paths: DEFAULT_REDACTED_PATHS,
      censor,
    };
  }
}
